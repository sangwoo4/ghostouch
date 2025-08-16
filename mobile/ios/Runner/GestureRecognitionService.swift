import Foundation
import MediaPipeTasksVision

// 제스처 인식 관련 서비스를 앱 전체에서 공유하는 싱글톤 클래스
@MainActor
class GestureRecognitionService {

    // MARK: - Singleton Instance
    static let shared = GestureRecognitionService()

    // MARK: - Public Properties
    let handLandmarkerService: HandLandmarkerService?
    var gestureRecognizer: GestureRecognizer? // 재초기화를 허용하기 위해 var로 변경
    
    // MARK: - Training Properties
    let landmarkBuffer = LandmarkBuffer(capacity: 100)
    let trainingManager = TrainingManager()
    private(set) var isRecording = false
    private(set) var hasCollectedSuccessfully = false
    private(set) var currentGesture: String?
    private var gestureBeingTrained: String?
    
    private let customModelNameKey = "CustomModelName"

    // MARK: - Initializer
    private init() {
        // HandLandmarkerService 초기화
        let landmarker = HandLandmarkerService.liveStreamHandLandmarkerService(
            modelPath: DefaultConstants.modelPath,
            numHands: DefaultConstants.numHands,
            minHandDetectionConfidence: DefaultConstants.minHandDetectionConfidence,
            minHandPresenceConfidence: DefaultConstants.minHandPresenceConfidence,
            minTrackingConfidence: DefaultConstants.minTrackingConfidence,
            liveStreamDelegate: nil,
            delegate: DefaultConstants.delegate
        )
        
        guard let landmarker = landmarker else {
            print("ERROR: Failed to initialize HandLandmarkerService")
            self.handLandmarkerService = nil
            self.gestureRecognizer = nil
            return
        }
        
        self.handLandmarkerService = landmarker
        
        // --- 임시 수정: 항상 번들의 기본 모델을 사용하도록 강제 ---
        // 1. 영구 저장 로직 호출 주석 처리
        // self.initializeGestureRecognizer()
        
        // 2. 기본 모델 직접 지정하여 초기화
        self.gestureRecognizer = GestureRecognizer(modelPath: "basic_gesture_model", labelPath: "basic_label_map")
        // --- 임시 수정 끝 ---
        
        // TrainingManager의 delegate를 self로 설정
        self.trainingManager.delegate = self
        
        // onBatchReady 클로저를 사용하지 않으므로 관련 코드 삭제
    }
    
    // --- 임시 수정: 영구 저장 로직 함수 전체 주석 처리 ---
    /*
    private func initializeGestureRecognizer() {
        let userDefaults = UserDefaults.standard
        var finalModelURL: URL?
        
        // Documents 디렉토리의 레이블 맵이 항상 최신 버전임
        guard let finalLabelURL = LabelMapManager.shared.documentsFileURL else {
            print("🚨 [초기화 실패] Documents 디렉토리의 레이블 맵 URL을 가져올 수 없음.")
            self.gestureRecognizer = nil
            return
        }

        // UserDefaults에 저장된 커스텀 모델이 있는지 확인
        if let customModelName = userDefaults.string(forKey: customModelNameKey) {
            if let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                let customModelURL = documentsDirectory.appendingPathComponent(customModelName)
                if FileManager.default.fileExists(atPath: customModelURL.path) {
                    print("✅ 저장된 커스텀 모델 찾음: \(customModelName)")
                    finalModelURL = customModelURL
                } else {
                    print("⚠️ UserDefaults에 모델 이름(\(customModelName))이 있지만 파일 없음. 기본 모델 사용.")
                    userDefaults.removeObject(forKey: customModelNameKey)
                }
            }
        }

        // 커스텀 모델 또는 기본 모델로 GestureRecognizer 초기화
        if let modelURL = finalModelURL {
            print("커스텀 모델과 레이블로 초기화 시도.")
            self.gestureRecognizer = GestureRecognizer(modelURL: modelURL, labelURL: finalLabelURL)
        } else {
            print("기본 번들 모델과 Documents 레이블로 초기화 시도.")
            // 번들 기본 모델과 Documents의 (업데이트 가능성 있는) 레이블 맵으로 초기화
            if let bundleModelURL = Bundle.main.url(forResource: "basic_gesture_model", withExtension: "tflite") {
                 self.gestureRecognizer = GestureRecognizer(modelURL: bundleModelURL, labelURL: finalLabelURL)
            } else {
                print("🚨 [초기화 실패] 기본 번들 모델을 찾을 수 없음.")
                self.gestureRecognizer = nil
            }
        }
        
        if self.gestureRecognizer == nil {
            print("🚨 [초기화 실패] GestureRecognizer를 초기화할 수 없었음.")
        }
    }
    */
    
    // MARK: - Public Methods for Training Control
    
    func startRecording(for gesture: String) {
        print("▶️ \"\(gesture)\" 제스처 데이터 수집 시작.")
        self.currentGesture = gesture
        self.isRecording = true
        self.hasCollectedSuccessfully = false // 새로 수집 시작하므로 완료 상태 리셋
        self.landmarkBuffer.reset()
    }

    func stopRecording() {
        print("⏹️ 데이터 수집 중지 및 버퍼/UI 초기화.")
        self.isRecording = false
        self.currentGesture = nil
        self.landmarkBuffer.reset()
        
        // Dart쪽 UI의 Progress Bar를 0으로 리셋
        ProgressBarChannel.channel?.invokeMethod("updateProgress", arguments: 0)
    }
    
    func resetCollectionStateIfNeeded() {
        if self.hasCollectedSuccessfully {
            print("⚪️ 손이 화면에서 사라짐. 다시 수집 가능.")
            self.hasCollectedSuccessfully = false
        }
    }
    
    // MARK: - Public Method for Processing
    
    func recognizeAndCollect(result: HandLandmarkerResult?) -> String? {
        guard let result = result, let (recognizedGesture, features) = gestureRecognizer?.classifyGesture(handLandmarkerResult: result), let featureVector = features else {
            return nil
        }
        
        let gestureName = recognizedGesture?.components(separatedBy: " (").first
        
        // 버퍼가 꽉 찼을 때의 처리를 위한 로컬 함수
        func handleFullBuffer() {
            if self.landmarkBuffer.items.count >= self.landmarkBuffer.capacity {
                let batch = self.landmarkBuffer.items
                self.landmarkBuffer.reset() // 버퍼를 먼저 리셋

                print("✅ 100개 데이터 수집 완료. 서버 학습 시작.")
                self.isRecording = false
                self.hasCollectedSuccessfully = true
                
                if let gesture = self.currentGesture {
                    self.gestureBeingTrained = "peace" // MARK: 이부분 수정 -> gesture로
                    self.trainingManager.uploadAndTrain(gesture: "peace", frames: batch) // MARK: 이부분 수정 -> gesture로
                } else {
                    print("🚨 [오류] 제스처 이름이 없어 학습을 시작할 수 없음.")
                }
                self.currentGesture = nil
            }
        }
        
        if !self.isRecording && !self.hasCollectedSuccessfully && gestureName != "none" && gestureName != nil {
            self.isRecording = true
            self.currentGesture = gestureName
            self.landmarkBuffer.reset()
            
            self.landmarkBuffer.append(featureVector)
            print("✅ [수집 시작] 타겟: '\(gestureName!)'. 현재 [\(self.landmarkBuffer.items.count)/100]")
            ProgressBarChannel.channel?.invokeMethod("updateProgress", arguments: self.landmarkBuffer.items.count)
            
            handleFullBuffer() // 100개 찼는지 확인

        }
        else if self.isRecording {
            self.landmarkBuffer.append(featureVector)
            print("...[\(self.landmarkBuffer.items.count)/100] 데이터 추가 중...")
            ProgressBarChannel.channel?.invokeMethod("updateProgress", arguments: self.landmarkBuffer.items.count)
            
            handleFullBuffer() // 100개 찼는지 확인
        }
        
        return recognizedGesture
    }
}

// MARK: - TrainingManagerDelegate Conformance

extension GestureRecognitionService: TrainingManagerDelegate {
    
    func trainingDidStart(taskId: String) {
        print("👍 [서버 응답] 학습 시작됨. Task ID: \(taskId)")
    }

    func trainingDidProgress(taskId: String, step: String?) {
        print("⏳ [서버 응답] 학습 진행 중... 상태: \(step ?? "")")
    }

    func trainingDidSucceed(taskId: String, tfliteURL: String?, modelCode: String?) {
        print("🎉 [서버 응답] 학습 성공! 모델 코드: \(modelCode ?? "N/A")")
        
        guard let gestureName = self.gestureBeingTrained else {
            print("🚨 [오류] 학습 성공했으나 어떤 제스처인지 알 수 없음.")
            return
        }

        LabelMapManager.shared.addGesture(name: gestureName)
        self.gestureBeingTrained = nil
        self.hasCollectedSuccessfully = false
        
        // Dart쪽 UI의 Progress Bar를 0으로 리셋
        ProgressBarChannel.channel?.invokeMethod("updateProgress", arguments: 0)
    }

    func trainingDidFail(taskId: String, errorInfo: String?) {
        print("🚨 [서버 응답] 학습 실패. 원인: \(errorInfo ?? "알 수 없는 오류")")
        
        // 5초 딜레이 후 상태를 리셋하여 무한 루프 방지
        Task {
            try? await Task.sleep(nanoseconds: 5 * 1_000_000_000) // 5초
            
            self.gestureBeingTrained = nil
            self.hasCollectedSuccessfully = false
            
            // Dart쪽 UI의 Progress Bar를 0으로 리셋
            ProgressBarChannel.channel?.invokeMethod("updateProgress", arguments: 0)
        }
    }

    func modelReady(savedURL: URL) {
        print("💾 [모델 저장] 새 모델이 기기에 저장됨: \(savedURL.path)")
        
        let modelName = savedURL.lastPathComponent
        UserDefaults.standard.set(modelName, forKey: customModelNameKey)
        print("✅ 새 모델 이름 '\(modelName)'을 UserDefaults에 저장함.")
        
        let modelUpdateSuccess = gestureRecognizer?.updateModel(modelURL: savedURL)
        if modelUpdateSuccess != true {
            print("🚨 제스처 인식기 모델 업데이트 실패.")
            return
        }

        if let labelURL = LabelMapManager.shared.documentsFileURL {
            let labelUpdateSuccess = gestureRecognizer?.updateLabelMap(labelURL: labelURL)
            if labelUpdateSuccess != true {
                print("🚨 제스처 인식기 레이블 맵 업데이트 실패.")
                return
            }
        } else {
            print("🚨 업데이트할 레이블 맵 파일의 URL을 가져오지 못함.")
            return
        }
    }
}
