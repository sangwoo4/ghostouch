
import UIKit
import AVFoundation
import Flutter
import MediaPipeTasksVision
import PinLayout
import FlexLayout

// UIViewController로 유지 + 카메라/랜드마커 델리게이트 구현
class CameraPreviewView: UIViewController, CameraFeedServiceDelegate, HandLandmarkerServiceLiveStreamDelegate {

    // MARK: - UI
    private let root = UIView()
    private var previewView: UIView!
    private var overlayView: OverlayView!
    private var disabledLabel: UILabel!

    // MARK: - 속성
    private let isCameraEnabled: Bool

    // MARK: - MediaPipe
    private var cameraFeedService: CameraFeedService?
    private var handLandmarkerService: HandLandmarkerService?
    private var gestureRecognizer: GestureRecognizer?
    
    private let backgroundQueue = DispatchQueue(label: "com.google.mediapipe.camera.backgroundQueue")

    // MARK: - 초기화
    init(isCameraEnabled: Bool) {
        self.isCameraEnabled = isCameraEnabled
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - 라이프사이클
    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(root)
        setupUI()
        
        if isCameraEnabled {
            setupServices()
        }
        
        // 앱 백그라운드 진입 감지
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guard isCameraEnabled else { return }
        cameraFeedService?.startLiveCameraSession { _ in }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        guard isCameraEnabled else { return }
        cameraFeedService?.stopSession()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        root.pin.all().margin(view.safeAreaInsets)
        root.flex.layout()
        if isCameraEnabled {
            cameraFeedService?.updateVideoPreviewLayer(toFrame: previewView.bounds)
        }
    }

    // MARK: - UI 구성
    private func setupUI() {
        root.flex.define { flex in
            if isCameraEnabled {
                previewView = UIView()
                previewView.contentMode = .scaleAspectFill
                flex.addItem(previewView).position(.absolute).all(0)

                overlayView = OverlayView()
                overlayView.backgroundColor = .clear
                flex.addItem(overlayView).position(.absolute).all(0)

            } else {
                disabledLabel = UILabel()
                disabledLabel.text = "카메라 꺼짐"
                disabledLabel.textColor = .white
                disabledLabel.textAlignment = .center
                disabledLabel.font = .systemFont(ofSize: 18)
                flex.addItem(disabledLabel).grow(1).alignSelf(.center).justifyContent(.center)
            }
        }
    }

    // MARK: - 서비스 구성
    private func setupServices() {
        cameraFeedService = CameraFeedService(previewView: previewView)
        cameraFeedService?.delegate = self

        handLandmarkerService = GestureRecognitionService.shared.handLandmarkerService
        gestureRecognizer = GestureRecognitionService.shared.gestureRecognizer
        handLandmarkerService?.liveStreamDelegate = self
    }
    
    // MARK: - 알림 처리
    @objc private func handleAppDidEnterBackground() {
        print("앱 백그라운드 전환, 데이터 수집 중단")
        GestureRecognitionService.shared.stopRecording()
    }

    // MARK: - CameraFeedServiceDelegate
    func didOutput(sampleBuffer: CMSampleBuffer, orientation: UIImage.Orientation) {
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let milliseconds = CMTimeGetSeconds(timestamp) * 1000
        backgroundQueue.async { [weak self] in
            autoreleasepool {
                self?.handLandmarkerService?.detectAsync(
                    sampleBuffer: sampleBuffer,
                    orientation: orientation,
                    timeStamps: Int(milliseconds)
                )
            }
        }
    }

    func didEncounterSessionRuntimeError() {
        print("세션 런타임 에러")
    }

    func sessionWasInterrupted(canResumeManually resumeManually: Bool) {
        print("세션 일시중지")
    }

    func sessionInterruptionEnded() {
        print("세션 일시중지 끝")
    }

    // MARK: - HandLandmarkerServiceLiveStreamDelegate
    func handLandmarkerService(
        _ handLandmarkerService: HandLandmarkerService,
        didFinishDetection result: ResultBundle?,
        error: Error?
    ) {
        DispatchQueue.main.async {
            if let error = error {
                print("랜드마크 감지 에러: \(error.localizedDescription)")
                self.overlayView.clear()
                return
            }

            guard let result = result,
                  let handLandmarkerResult = result.handLandmarkerResults.first,
                  let landmarks = handLandmarkerResult?.landmarks,
                  !landmarks.isEmpty else {
                self.overlayView.clear()
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

            if let handLandmarkerResult {
                _ = GestureRecognitionService.shared.recognizeAndCollect(result: handLandmarkerResult)
            } else {

            }
        }
    }
}

// MARK: - UIDeviceOrientation → UIImage.Orientation 변환
extension UIDeviceOrientation {
    var toImageOrientation: UIImage.Orientation {
        switch self {
        case .portrait: return .up
        case .portraitUpsideDown: return .down
        case .landscapeLeft: return .right
        case .landscapeRight: return .left
        default: return .up
        }
    }
}
