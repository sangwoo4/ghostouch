import Foundation
import MediaPipeTasksVision

// MARK: - 알림 이름
extension Notification.Name {
    static let didRecognizeGesture = Notification.Name("didRecognizeGesture")
    static let didResetAllGestures = Notification.Name("didResetAllGestures")
}

// 제스처 인식 서비스를 앱 전체에서 공유하는 싱글톤
@MainActor
class GestureRecognitionService {

    // MARK: - 싱글톤 인스턴스
    static let shared = GestureRecognitionService()

    // MARK: - 공개 프로퍼티
    let handLandmarkerService: HandLandmarkerService?
    var gestureRecognizer: GestureRecognizer? // 재초기화 허용하려고 var 사용
    
    // MARK: - 학습 관련 프로퍼티
    let landmarkBuffer = LandmarkBuffer(capacity: 100)
    let trainingManager = TrainingManager()
    private(set) var isRecording = false
    private(set) var hasCollectedSuccessfully = false
    private(set) var currentGesture: String?
    private var gestureBeingTrained: String?
    
    private let customModelNameKey = "CustomModelName"

    // MARK: - 초기화
    private init() {
        // 손 랜드마커 서비스 준비
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
            print("오류: HandLandmarkerService 초기화 실패")
            self.handLandmarkerService = nil
            self.gestureRecognizer = nil
            return
        }
        
        self.handLandmarkerService = landmarker
        
        // 저장된 모델이 있으면 그걸로, 없으면 기본 모델로 초기화
        self.initializeGestureRecognizer()
        
        // 학습 매니저 델리게이트 설정
        self.trainingManager.delegate = self
        
        // 모든 제스처 초기화 알림 받으면 리셋 처리
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleGestureReset),
            name: .didResetAllGestures,
            object: nil
        )
    }
    
    // 알림 수신 시 제스처 인식 상태 초기화
    @objc private func handleGestureReset() {
        print("'didResetAllGestures' 알림 받음. 제스처 인식기 상태 초기화")
        
        TrainingStore.shared.lastModelCode = "base_v1"

        guard let gestureRecognizer = self.gestureRecognizer else {
            print("경고: GestureRecognizer 인스턴스를 못 찾아서 초기화 못 함")
            return
        }

        if let labelURL = LabelMapManager.shared.documentsFileURL {
            if gestureRecognizer.updateLabelMap(labelURL: labelURL) {
                print("레이블 맵 업데이트 성공")
            } else {
                print("레이블 맵 업데이트 실패")
            }
        } else {
            print("오류: Documents 디렉터리에서 레이블 맵 URL을 못 가져와서 업데이트 못 함")
        }

        if let basicModelURL = Bundle.main.url(forResource: "basic_gesture_model", withExtension: "tflite") {
            if gestureRecognizer.updateModel(modelURL: basicModelURL) {
                print("기본 모델로 업데이트 성공")
            } else {
                print("기본 모델로 업데이트 실패")
            }
        } else {
            print("오류: 번들에서 basic_gesture_model.tflite를 못 찾아서 모델 초기화 못 함")
        }
    }
    
    // 제스처 인식기 초기화 (영구 저장된 모델 우선)
    private func initializeGestureRecognizer() {
        var finalModelURL: URL?
        
        // Documents에 있는 레이블 맵이 최신이라 이걸로 고정
        guard let finalLabelURL = LabelMapManager.shared.documentsFileURL else {
            print("오류: 레이블 맵 URL을 못 가져와서 초기화 실패")
            self.gestureRecognizer = nil
            return
        }

        // 저장된 커스텀 모델이 있는지 확인
        if let lastModelCode = TrainingStore.shared.lastModelCode,
           let lastModelURLString = TrainingStore.shared.lastModelURLString,
           let _ = URL(string: lastModelURLString) {
            
            let localModelURL = TrainingStore.shared.modelFileURL(modelCode: lastModelCode)

            if FileManager.default.fileExists(atPath: localModelURL.path) {
                print("저장된 커스텀 모델 찾음: \(lastModelCode)")
                finalModelURL = localModelURL
            } else {
                print("경고: 모델 정보(\(lastModelCode))는 있는데 파일이 없음. 기본 모델 사용")
                TrainingStore.shared.lastModelCode = nil
                TrainingStore.shared.lastModelURLString = nil
            }
        }

        // 커스텀 모델 우선, 없으면 기본 모델 사용
        if let modelURL = finalModelURL {
            print("커스텀 모델과 레이블로 초기화 시도")
            self.gestureRecognizer = GestureRecognizer(modelURL: modelURL, labelURL: finalLabelURL)
        } else {
            print("기본 모델과 Documents 레이블로 초기화 시도")
            if let bundleModelURL = Bundle.main.url(forResource: "basic_gesture_model", withExtension: "tflite") {
                self.gestureRecognizer = GestureRecognizer(modelURL: bundleModelURL, labelURL: finalLabelURL)
            } else {
                print("오류: 기본 번들 모델을 못 찾아서 초기화 실패")
                self.gestureRecognizer = nil
            }
        }
        
        if self.gestureRecognizer == nil {
            print("오류: GestureRecognizer 초기화에 실패했음")
        }
    }
    
    // MARK: - 학습 제어 메서드

    func stopRecording() {
        print("데이터 수집 중지하고 버퍼랑 UI 초기화")
        self.isRecording = false
        self.currentGesture = nil
        self.landmarkBuffer.reset()
        
        ProgressBarChannel.channel?.invokeMethod("updateProgress", arguments: 0)
    }
    
    func startCollecting(gestureName: String) {
        // 학습 진행 중이면 새 요청 무시
        guard self.gestureBeingTrained == nil else {
            print("학습이 이미 진행 중이어서 새 데이터 수집 요청은 무시")
            return
        }
        
        print("\"\(gestureName)\" 제스처 데이터 수집 시작 (요청 받음)")
        self.currentGesture = gestureName
        self.isRecording = true
        self.hasCollectedSuccessfully = false
        self.landmarkBuffer.reset()
        
        ProgressBarChannel.channel?.invokeMethod("updateProgress", arguments: 0)
    }
    
    func resetCollectionStateIfNeeded() {
        if self.hasCollectedSuccessfully {
            print("손이 화면에서 사라짐. 다시 수집 가능")
            self.hasCollectedSuccessfully = false
        }
    }

    // MARK: - 처리 메서드
    
    func recognizeAndCollect(result: HandLandmarkerResult?) -> String? {
        guard let result = result,
              let (recognizedGesture, features) = gestureRecognizer?.classifyGesture(handLandmarkerResult: result),
              let featureVector = features else {
            resetCollectionStateIfNeeded()
            return nil
        }
        
        if isRecording {
            landmarkBuffer.append(featureVector)
            print("[\(landmarkBuffer.items.count)/100] 데이터 추가 중")
            ProgressBarChannel.channel?.invokeMethod("updateProgress", arguments: landmarkBuffer.items.count)
            
            if landmarkBuffer.items.count >= landmarkBuffer.capacity {
                ProgressBarChannel.channel?.invokeMethod("collectionComplete", arguments: nil)
                let batch = landmarkBuffer.items
                landmarkBuffer.reset()

                print("100개 데이터 수집 완료. 서버 학습 시작")
                isRecording = false
                hasCollectedSuccessfully = true
                
                if let gesture = self.currentGesture {
                    gestureBeingTrained = gesture
                    trainingManager.uploadAndTrain(gesture: gesture, frames: batch)
                } else {
                    print("오류: 제스처 이름이 없어서 학습을 시작 못 함")
                }
                currentGesture = nil
            }
        }
        
        return recognizedGesture
    }
}

// MARK: - TrainingManagerDelegate 구현

extension GestureRecognitionService: TrainingManagerDelegate {
    
    func trainingDidStart(taskId: String) {
        print("서버 응답: 학습 시작. Task ID: \(taskId)")
        ProgressBarChannel.channel?.invokeMethod("taskIdReady", arguments: ["taskId": taskId])
    }

    func trainingDidProgress(taskId: String, progress: StatusResponse.ProgressPayload?) {
        print("서버 응답: 학습 진행 중.. 상태: \(progress?.current_step ?? "")")
        let step = progress?.current_step ?? "모델 학습 중..."
        let payload: [String: Any] = ["progress": ["current_step": step]]
        ProgressBarChannel.channel?.invokeMethod("modelDownloading", arguments: payload)
    }

    func trainingDidSucceed(taskId: String, tfliteURL: String?, modelCode: String?) {
        print("서버 응답: 학습 성공. 모델 코드: \(modelCode ?? "N/A")")
        
        guard let gestureName = self.gestureBeingTrained else {
            print("오류: 학습은 성공 but 어떤 제스처인지 알 수 없음")
            return
        }

        LabelMapManager.shared.addGesture(name: gestureName)
        self.gestureBeingTrained = nil
        self.hasCollectedSuccessfully = false
        
        ProgressBarChannel.channel?.invokeMethod("modelDownloadComplete", arguments: nil)
    }

    func trainingDidFail(taskId: String, errorInfo: String?) {
        print("서버 응답: 학습 실패. 원인: \(errorInfo ?? "알 수 없는 오류")")
        
        self.gestureBeingTrained = nil
        self.hasCollectedSuccessfully = false
        
        let message = errorInfo ?? "알 수 없는 오류"
        ProgressBarChannel.channel?.invokeMethod("uploadFailed", arguments: message)
    }

    func modelReady(savedURL: URL) {
        print("모델 저장: 새 모델을 기기에 저장. 경로: \(savedURL.path)")
        
        let modelName = savedURL.lastPathComponent
        UserDefaults.standard.set(modelName, forKey: customModelNameKey)
        print("새 모델 이름 '\(modelName)' 저장했어 (UserDefaults)")
        
        let modelUpdateSuccess = gestureRecognizer?.updateModel(modelURL: savedURL)
        if modelUpdateSuccess != true {
            print("오류: 제스처 인식기 모델 업데이트 실패")
            return
        }

        if let labelURL = LabelMapManager.shared.documentsFileURL {
            let labelUpdateSuccess = gestureRecognizer?.updateLabelMap(labelURL: labelURL)
            if labelUpdateSuccess != true {
                print("오류: 레이블 맵 업데이트 실패")
                return
            }
        } else {
            print("오류: 업데이트할 레이블 맵 파일 URL을 못 가져옴")
            return
        }
    }
}
