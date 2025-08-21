
import Foundation
import MediaPipeTasksVision

// 제스처 인식 관련 서비스들을 앱 전체에서 공유하기 위한 싱글톤 클래스
class GestureRecognitionService {

    // MARK: - Singleton Instance
    static let shared = GestureRecognitionService()

    // MARK: - Public Properties
    // 서비스 초기화가 실패할 수 있으므로 프로퍼티를 옵셔널로 선언합니다.
    let handLandmarkerService: HandLandmarkerService?
    let gestureRecognizer: GestureRecognizer?

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
        
        // guard let을 사용하여 안전하게 할당하고, 실패 시 로그를 남깁니다.
        guard let landmarker = landmarker else {
            print("ERROR: Failed to initialize HandLandmarkerService")
            self.handLandmarkerService = nil
            self.gestureRecognizer = nil
            return
        }
        
        self.handLandmarkerService = landmarker
        //self.gestureRecognizer = GestureRecognizer(modelPath: "basic_gesture_model", labelPath: "basic_label_map")
        self.gestureRecognizer = GestureRecognizer(modelPath: "1754987611_a47a36ac_model", labelPath: "basic_label_map")
    }
}
