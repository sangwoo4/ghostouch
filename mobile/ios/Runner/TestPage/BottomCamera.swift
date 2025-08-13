import UIKit
import AVFoundation
import MediaPipeTasksVision
import FlexLayout
import PinLayout


protocol BottomCameraDelegate: AnyObject {
    func bottomCamera(_ camera: BottomCamera, didRecognizeGesture gesture: String)
    func bottomCamera(_ camera: BottomCamera, didFinishDetection result: HandLandmarkerResult, imageSize: CGSize)
    func bottomCameraDidNotDetectHand(_ camera: BottomCamera)
}

class BottomCamera: UIView, CameraFeedServiceDelegate, HandLandmarkerServiceLiveStreamDelegate {

    weak var delegate: BottomCameraDelegate?

    private let root = UIView()
    
    private var previewView: UIView!
    private var overlayView: OverlayView!

    private var cameraFeedService: CameraFeedService?
    // 서비스 프로퍼티는 그대로 유지
    private var handLandmarkerService: HandLandmarkerService?
    private var gestureRecognizer: GestureRecognizer?
    
    private let backgroundQueue = DispatchQueue(label: "com.google.mediapipe.camera.backgroundQueue")

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupServices()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func startSession() {
        cameraFeedService?.startLiveCameraSession { _ in }
    }
    
    public func stopSession() {
        cameraFeedService?.stopSession()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        root.pin.all()
        root.flex.layout()
        cameraFeedService?.updateVideoPreviewLayer(toFrame: self.bounds)
    }

    private func setupUI() {
        self.backgroundColor = .black

        previewView = UIView()
        previewView.backgroundColor = .clear

        overlayView = OverlayView()
        overlayView.backgroundColor = .clear
        
        addSubview(root)
        root.flex.define { flex in
            flex.addItem(previewView).position(.absolute).all(0)
            flex.addItem(overlayView).position(.absolute).all(0)
        }
    }

    // setupServices 메서드를 수정하여 공유 인스턴스를 사용하도록 변경
    private func setupServices() {
        cameraFeedService = CameraFeedService(previewView: previewView)
        cameraFeedService?.delegate = self

        // 더 이상 직접 생성하지 않음
        // handLandmarkerService = HandLandmarkerService.liveStreamHandLandmarkerService(...)
        // gestureRecognizer = GestureRecognizer(...)
        
        // 공유 인스턴스를 가져옴
        self.handLandmarkerService = GestureRecognitionService.shared.handLandmarkerService
        self.gestureRecognizer = GestureRecognitionService.shared.gestureRecognizer
        
        // liveStreamDelegate를 self로 설정하여, 랜드마크 감지 결과를 이 클래스(BottomCamera)에서 받을 수 있도록 함
        self.handLandmarkerService?.liveStreamDelegate = self
    }

    // MARK: - CameraFeedServiceDelegate
    func didOutput(sampleBuffer: CMSampleBuffer, orientation: UIImage.Orientation) {
        let currentTimeMs = Date().timeIntervalSince1970 * 1000
        backgroundQueue.async { [weak self] in
            self?.handLandmarkerService?.detectAsync(
                sampleBuffer: sampleBuffer,
                orientation: orientation,
                timeStamps: Int(currentTimeMs)
            )
        }
    }
    
    func didEncounterSessionRuntimeError() { print("BottomCamera: Session runtime error occurred.") }
    func sessionWasInterrupted(canResumeManually resumeManually: Bool) { print("BottomCamera: Session was interrupted.") }
    func sessionInterruptionEnded() { print("BottomCamera: Session interruption ended.") }

    // MARK: - HandLandmarkerServiceLiveStreamDelegate
    func handLandmarkerService(
        _ handLandmarkerService: HandLandmarkerService,
        didFinishDetection result: ResultBundle?,
        error: Error?
    ) {
        DispatchQueue.main.async {
            if let error = error {
                print("Hand landmarker service error: \(error.localizedDescription)")
                self.delegate?.bottomCamera(self, didRecognizeGesture: "Error")
                return
            }

            guard let result = result, let handLandmarkerResult = result.handLandmarkerResults.first, let landmarks = handLandmarkerResult?.landmarks, !landmarks.isEmpty else {
                self.delegate?.bottomCamera(self, didRecognizeGesture: " ")
                self.delegate?.bottomCameraDidNotDetectHand(self)
                return
            }

            // 자신의 overlayView에 그리는 코드는 주석 처리된 상태 유지
            let imageSize = self.cameraFeedService?.videoResolution ?? .zero

            if let gesture = self.gestureRecognizer?.classifyGesture(handLandmarkerResult: handLandmarkerResult!) { //기존 handLandmarkerResult: handLandmarkerResult!
                self.delegate?.bottomCamera(self, didRecognizeGesture: gesture)
            } else {
                self.delegate?.bottomCamera(self, didRecognizeGesture: " ")
            }
            
            if let result = handLandmarkerResult {
                self.delegate?.bottomCamera(self, didFinishDetection: result, imageSize: imageSize)
            }
        }
    }
}
