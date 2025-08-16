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

@MainActor
class BottomCamera: UIView, CameraFeedServiceDelegate, HandLandmarkerServiceLiveStreamDelegate {

    weak var delegate: BottomCameraDelegate?

    private let root = UIView()
    
    private var previewView: UIView!
    private var overlayView: OverlayView!

    private var cameraFeedService: CameraFeedService?
    private var handLandmarkerService: HandLandmarkerService?
    
    // GestureRecognitionService 싱글톤 인스턴스를 사용합니다.
    private let service = GestureRecognitionService.shared

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

    private func setupServices() {
        cameraFeedService = CameraFeedService(previewView: previewView)
        cameraFeedService?.delegate = self

        self.handLandmarkerService = service.handLandmarkerService
        self.handLandmarkerService?.liveStreamDelegate = self
    }

    // MARK: - CameraFeedServiceDelegate
    func didOutput(sampleBuffer: CMSampleBuffer, orientation: UIImage.Orientation) {
        autoreleasepool {
            handLandmarkerService?.detectAsync(
                sampleBuffer: sampleBuffer,
                orientation: orientation,
                timeStamps: Int(Date().timeIntervalSince1970 * 1000)
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
                print("🚨 [오류] 랜드마크 감지 실패: \(error.localizedDescription)")
                self.delegate?.bottomCamera(self, didRecognizeGesture: "Error")
                return
            }

            // Safely get the first valid HandLandmarkerResult
            guard let handLandmarkerResult = result?.handLandmarkerResults.first, let unwrappedHandLandmarkerResult = handLandmarkerResult else {
                // 중앙 서비스의 리셋 메서드 호출
                self.service.resetCollectionStateIfNeeded()
                
                self.delegate?.bottomCamera(self, didRecognizeGesture: " ")
                self.delegate?.bottomCameraDidNotDetectHand(self)
                return
            }
            
            // 중앙 서비스의 인식/수집 메서드 호출
            let recognizedGesture = self.service.recognizeAndCollect(result: unwrappedHandLandmarkerResult)
            
            // 델리게이트로 UI 업데이트
            let imageSize = self.cameraFeedService?.videoResolution ?? .zero
            self.delegate?.bottomCamera(self, didRecognizeGesture: recognizedGesture ?? " ")
            self.delegate?.bottomCamera(self, didFinishDetection: unwrappedHandLandmarkerResult, imageSize: imageSize)
        }
    }
}
