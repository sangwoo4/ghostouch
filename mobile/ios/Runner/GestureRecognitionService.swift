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
        
        // Initialize GestureRecognizer with persisted model or basic model
        self.initializeGestureRecognizer()
        
        // TrainingManager의 delegate를 self로 설정
        self.trainingManager.delegate = self
    }
    
    //  영구 저장 로직 함수
    private func initializeGestureRecognizer() {
        var finalModelURL: URL?
        
        // Documents 디렉토리의 레이블 맵이 항상 최신 버전임
        guard let finalLabelURL = LabelMapManager.shared.documentsFileURL else {
            print("🚨 [초기화 실패] Documents 디렉토리의 레이블 맵 URL을 가져올 수 없음.")
            self.gestureRecognizer = nil
            return
        }

        // TrainingStore에 저장된 커스텀 모델이 있는지 확인
        if let lastModelCode = TrainingStore.shared.lastModelCode,
           let lastModelURLString = TrainingStore.shared.lastModelURLString,
           let storedModelURL = URL(string: lastModelURLString) {
            
            let localModelURL = TrainingStore.shared.modelFileURL(modelCode: lastModelCode)

            if FileManager.default.fileExists(atPath: localModelURL.path) {
                print("✅ 저장된 커스텀 모델 찾음: \(lastModelCode)")
                finalModelURL = localModelURL
            } else {
                print("⚠️ TrainingStore에 모델 정보(\(lastModelCode))가 있지만 파일 없음. 기본 모델 사용.")
                TrainingStore.shared.lastModelCode = nil
                TrainingStore.shared.lastModelURLString = nil
            }
        }

        // 커스텀 모델 또는 기본 모델로 GestureRecognizer 초기화
        if let modelURL = finalModelURL {
            print("커스텀 모델과 레이블로 초기화 시도.")
            self.gestureRecognizer = GestureRecognizer(modelURL: modelURL, labelURL: finalLabelURL)
        } else {
            print("기본 번들 모델과 Documents 레이블로 초기화 시도.")
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
    
    // MARK: - Public Methods for Training Control

    func stopRecording() {
        print("⏹️ 데이터 수집 중지 및 버퍼/UI 초기화.")
        self.isRecording = false
        self.currentGesture = nil
        self.landmarkBuffer.reset()
        
        ProgressBarChannel.channel?.invokeMethod("updateProgress", arguments: 0)
    }
    
    func startCollecting(gestureName: String) {
        // 학습이 이미 진행 중일 때는 다시촬영 요청을 무시
        guard self.gestureBeingTrained == nil else {
            print("⚠️ 학습이 이미 진행 중입니다. 새로운 데이터 수집 요청을 무시합니다.")
            return
        }
        
        print("▶️ \"\(gestureName)\" 제스처 데이터 수집 시작 (요청 받음).")
        self.currentGesture = gestureName
        self.isRecording = true
        self.hasCollectedSuccessfully = false
        self.landmarkBuffer.reset()
        
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
            resetCollectionStateIfNeeded()
            return nil
        }
        
        if isRecording {
            landmarkBuffer.append(featureVector)
            print("...[\(landmarkBuffer.items.count)/100] 데이터 추가 중...")
            ProgressBarChannel.channel?.invokeMethod("updateProgress", arguments: landmarkBuffer.items.count)
            
            if landmarkBuffer.items.count >= landmarkBuffer.capacity {
                let batch = landmarkBuffer.items
                landmarkBuffer.reset()

                print("✅ 100개 데이터 수집 완료. 서버 학습 시작.")
                isRecording = false
                hasCollectedSuccessfully = true
                
                if let gesture = self.currentGesture {
                    gestureBeingTrained = gesture
                    trainingManager.uploadAndTrain(gesture: gesture, frames: batch)
                } else {
                    print("🚨 [오류] 제스처 이름이 없어 학습을 시작할 수 없음.")
                }
                currentGesture = nil
            }
        }
        
        return recognizedGesture
    }
}

// MARK: - TrainingManagerDelegate Conformance

extension GestureRecognitionService: TrainingManagerDelegate {
    
    func trainingDidStart(taskId: String) {
        print("👍 [서버 응답] 학습 시작됨. Task ID: \(taskId)")
    }

    func trainingDidProgress(taskId: String, progress: StatusResponse.ProgressPayload?) {
        print("⏳ [서버 응답] 학습 진행 중... 상태: \(progress?.current_step ?? "")")
        let step = progress?.current_step ?? "모델 학습 중..."
        let payload: [String: Any] = ["progress": ["current_step": step]]
        ProgressBarChannel.channel?.invokeMethod("modelDownloading", arguments: payload)
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
        
        ProgressBarChannel.channel?.invokeMethod("modelDownloadComplete", arguments: nil)
    }

    func trainingDidFail(taskId: String, errorInfo: String?) {
        print("🚨 [서버 응답] 학습 실패. 원인: \(errorInfo ?? "알 수 없는 오류")")
        
        self.gestureBeingTrained = nil
        self.hasCollectedSuccessfully = false
        
        let message = errorInfo ?? "알 수 없는 오류"
        ProgressBarChannel.channel?.invokeMethod("uploadFailed", arguments: message)
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
