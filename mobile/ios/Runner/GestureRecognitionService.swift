
import Foundation
import MediaPipeTasksVision

// 제스처 인식 관련 서비스들을 앱 전체에서 공유하기 위한 싱글톤 클래스
@MainActor
class GestureRecognitionService {

    // MARK: - Singleton Instance
    static let shared = GestureRecognitionService()

    // MARK: - Public Properties
    let handLandmarkerService: HandLandmarkerService?
    let gestureRecognizer: GestureRecognizer?
    
    // MARK: - Training Properties
    let landmarkBuffer = LandmarkBuffer(capacity: 100)
    let trainingManager = TrainingManager()
    private(set) var isRecording = false
    private(set) var currentGesture: String?

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
        self.gestureRecognizer = GestureRecognizer(modelPath: "1754987611_a47a36ac_model", labelPath: "basic_label_map")
        
        // TrainingManager의 delegate를 self로 설정
        self.trainingManager.delegate = self
        
        // onBatchReady 클로저 설정
        landmarkBuffer.onBatchReady = { [weak self] batch in
            guard let self = self, let gesture = self.currentGesture else { return }
            
            print("✅ 100개 데이터 수집 완료! \"\(gesture)\" 제스처 학습을 시작합니다.")
            self.trainingManager.uploadAndTrain(gesture: gesture, frames: batch)
            
            // 수집 완료 후 녹화 상태 자동 중지
            self.stopRecording()
        }
    }
    
    // MARK: - Public Methods for Training Control
    
    func startRecording(for gesture: String) {
        print("▶️ \"\(gesture)\" 제스처 데이터 수집을 시작합니다.")
        self.currentGesture = gesture
        self.isRecording = true
        self.landmarkBuffer.reset()
    }

    func stopRecording() {
        if self.isRecording {
            print("⏹️ 데이터 수집을 중지합니다.")
            self.isRecording = false
            self.currentGesture = nil
        }
    }
    
    // MARK: - Public Method for Processing
    
    func recognizeAndCollect(result: HandLandmarkerResult) -> String? {
        guard let (label, features) = gestureRecognizer?.classifyGesture(handLandmarkerResult: result) else {
            return nil
        }
        
        if isRecording, let featureVector = features {
            landmarkBuffer.append(featureVector)
        }
        
        return label
    }
}

// MARK: - TrainingManagerDelegate Conformance

extension GestureRecognitionService: TrainingManagerDelegate {
    func trainingDidStart(taskId: String) {
        print("델리게이트: 학습 시작 - Task ID: \(taskId)")
        // TODO: NotificationCenter 등을 사용하여 UI에 알림
    }

    func trainingDidProgress(taskId: String, step: String?) {
        print("델리게이트: 학습 진행 - \(step ?? "...")")
        // TODO: NotificationCenter 등을 사용하여 UI에 알림
    }

    func trainingDidSucceed(taskId: String, tfliteURL: String?, modelCode: String?) {
        print("델리게이트: 학습 성공! URL: \(tfliteURL ?? "N/A"), Code: \(modelCode ?? "N/A")")
        // TODO: NotificationCenter 등을 사용하여 UI에 알림
    }

    func trainingDidFail(taskId: String, errorInfo: String?) {
        print("델리게이트: 학습 실패: \(errorInfo ?? "Unknown error")")
        // TODO: NotificationCenter 등을 사용하여 UI에 알림
    }

    func modelReady(savedURL: URL) {
        print("델리게이트: 새 모델이 기기에 저장되었습니다: \(savedURL.path)")
        // TODO: NotificationCenter 등을 사용하여 UI에 알림
    }
}
