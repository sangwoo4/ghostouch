import UIKit
import AVFoundation
import Flutter
import MediaPipeTasksVision
import PinLayout // PinLayout import
import FlexLayout // FlexLayout import

// 1. 클래스 타입을 UIViewController로 유지하고 필요한 델리게이트를 채택합니다.
class CameraPreviewView: UIViewController, CameraFeedServiceDelegate, HandLandmarkerServiceLiveStreamDelegate {

    // MARK: - UI Components
    private let root = UIView() // FlexLayout의 root 뷰
    private var previewView: UIView!
    private var overlayView: OverlayView!
    private var gestureLabel: UILabel!

    // MARK: - MediaPipe Services
    private var cameraFeedService: CameraFeedService?
    private var handLandmarkerService: HandLandmarkerService?
    private var gestureRecognizer: GestureRecognizer?
    
    private let backgroundQueue = DispatchQueue(label: "com.google.mediapipe.camera.backgroundQueue")

    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(root) // root 뷰를 뷰 컨트롤러의 뷰에 추가
        setupUI()
        setupServices()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        cameraFeedService?.startLiveCameraSession { [weak self] cameraConfiguration in
            DispatchQueue.main.async {
                switch cameraConfiguration {
                case .failed:
                    print("Error: Failed to start camera session.")
                case .permissionDenied:
                    print("Error: Camera permissions are required.")
                default:
                    break
                }
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        cameraFeedService?.stopSession()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // root 뷰를 safeArea에 맞춰 배치
        root.pin.all().margin(view.safeAreaInsets) // root 뷰를 superview의 safeAreaInsets에 맞춰 마진 적용
        root.flex.layout()
        // previewView의 bounds에 맞춰 previewLayer를 업데이트
        cameraFeedService?.updateVideoPreviewLayer(toFrame: previewView.bounds)
    }

    // MARK: - UI Setup
    private func setupUI() {
        // FlexLayout을 사용하여 UI 요소들을 배치합니다.
        root.flex.define { flex in
            // 프리뷰 뷰: 카메라 영상이 보일 뷰
            previewView = UIView()
            previewView.contentMode = .scaleAspectFill
            flex.addItem(previewView).position(.absolute).all(0) // root 뷰 전체를 채움

            // 오버레이 뷰: 랜드마크를 그릴 뷰
            overlayView = OverlayView()
            overlayView.backgroundColor = .clear
            flex.addItem(overlayView).position(.absolute).all(0) // root 뷰 전체를 채움

            // 제스처 결과 라벨
            gestureLabel = UILabel()
            gestureLabel.textColor = .white
            gestureLabel.backgroundColor = UIColor(white: 0, alpha: 0.7)
            gestureLabel.textAlignment = .center
            gestureLabel.font = .systemFont(ofSize: 22, weight: .bold)
            gestureLabel.text = " "
            // 라벨을 하단에 배치
            flex.addItem(gestureLabel).position(.absolute).bottom(30).width(100%).height(50)
        }
    }

    // MARK: - Service Setup
    private func setupServices() {

        cameraFeedService = CameraFeedService(previewView: previewView)
        cameraFeedService?.delegate = self

        // GestureRecognitionService의 공유 인스턴스를 사용하도록 수정
        self.handLandmarkerService = GestureRecognitionService.shared.handLandmarkerService
        self.gestureRecognizer = GestureRecognitionService.shared.gestureRecognizer
        
        // liveStreamDelegate를 self로 설정하여, 랜드마크 감지 결과를 이 클래스에서 받을 수 있도록 함
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

    func didEncounterSessionRuntimeError() {
        print("Session runtime error occurred.")
    }

    func sessionWasInterrupted(canResumeManually resumeManually: Bool) {
        print("Session was interrupted.")
    }

    func sessionInterruptionEnded() {
        print("Session interruption ended.")
    }

    // MARK: - HandLandmarkerServiceLiveStreamDelegate
    func handLandmarkerService(
        _ handLandmarkerService: HandLandmarkerService,
        didFinishDetection result: ResultBundle?,
        error: Error?
    ) {
        DispatchQueue.main.async {
            if let error = error {
                print("Hand landmarker service error: \(error.localizedDescription)")
                self.gestureLabel.text = "Error"
                self.overlayView.clear()
                return
            }

            guard let result = result, let handLandmarkerResult = result.handLandmarkerResults.first, let landmarks = handLandmarkerResult?.landmarks, !landmarks.isEmpty else {
                self.overlayView.clear()
                self.gestureLabel.text = " "
                return
            }

            let imageSize = self.cameraFeedService?.videoResolution ?? .zero
            let handOverlays = OverlayView.handOverlays(
                fromMultipleHandLandmarks: landmarks,
                inferredOnImageOfSize: imageSize,
                ovelayViewSize: self.overlayView.bounds.size,
                imageContentMode: .scaleAspectFill,
                andOrientation: UIDevice.current.orientation.toImageOrientation
            )
            self.overlayView.draw(
                handOverlays: handOverlays,
                inBoundsOfContentImageOfSize: imageSize,
                imageContentMode: .scaleAspectFill
            )

            if let handLandmarkerResult = handLandmarkerResult {
                let gesture = GestureRecognitionService.shared.recognizeAndCollect(result: handLandmarkerResult)
                self.gestureLabel.text = gesture ?? " "

            } else {
                self.gestureLabel.text = " "
            }
        }
    }
}

// MARK: - UIDeviceOrientation Extension
extension UIDeviceOrientation {
    var toImageOrientation: UIImage.Orientation {
        switch self {
        case .portrait:
            return .up
        case .portraitUpsideDown:
            return .down
        case .landscapeLeft:
            return .right
        case .landscapeRight:
            return .left
        default:
            return .up
        }
    }
}
