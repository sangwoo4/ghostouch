//
//  CameraPreviewView.swift
//  Runner
//
//  Created by 이상원 on 8/7/25.
//

import UIKit
import AVFoundation
import Flutter
import MediaPipeTasksVision

// 1. 클래스 타입을 UIView에서 UIViewController로 변경하고 필요한 델리게이트를 채택합니다.
class CameraPreviewView: UIViewController, CameraFeedServiceDelegate, HandLandmarkerServiceLiveStreamDelegate {

    // MARK: - UI Components
    // 샘플 코드의 UI 요소들을 가져옵니다.
    private var previewView: UIView!
    private var overlayView: OverlayView!
    private var gestureLabel: UILabel!

    // MARK: - MediaPipe Services
    // 서비스 및 제스처 인식기를 관리할 프로퍼티를 선언합니다.
    private var cameraFeedService: CameraFeedService?
    private var handLandmarkerService: HandLandmarkerService?
    private var gestureRecognizer: GestureRecognizer?
    
    // 백그라운드에서 MediaPipe 추론을 처리할 DispatchQueue
    private let backgroundQueue = DispatchQueue(label: "com.google.mediapipe.camera.backgroundQueue")

    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
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
        // previewView와 overlayView의 프레임을 현재 뷰의 바운드에 맞게 조정합니다.
        previewView.frame = view.bounds
        overlayView.frame = view.bounds
        cameraFeedService?.updateVideoPreviewLayer(toFrame: previewView.bounds)
    }

    // MARK: - UI Setup
    private func setupUI() {
        // 프리뷰 뷰: 카메라 영상이 보일 뷰
        previewView = UIView(frame: view.bounds)
        previewView.contentMode = .scaleAspectFill
        view.addSubview(previewView)

        // 오버레이 뷰: 랜드마크를 그릴 뷰
        overlayView = OverlayView(frame: view.bounds)
        overlayView.backgroundColor = .clear
        view.addSubview(overlayView)

        // 제스처 결과 라벨
        gestureLabel = UILabel()
        gestureLabel.translatesAutoresizingMaskIntoConstraints = false
        gestureLabel.textColor = .white
        gestureLabel.backgroundColor = UIColor(white: 0, alpha: 0.7)
        gestureLabel.textAlignment = .center
        gestureLabel.font = .systemFont(ofSize: 22, weight: .bold)
        gestureLabel.text = " "
        view.addSubview(gestureLabel)

        // 라벨 제약 조건 설정
        NSLayoutConstraint.activate([
            gestureLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -30),
            gestureLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            gestureLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            gestureLabel.heightAnchor.constraint(equalToConstant: 50)
        ])
    }

    // MARK: - Service Setup
    private func setupServices() {
        // 1. HandLandmarkerService 초기화
        handLandmarkerService = HandLandmarkerService.liveStreamHandLandmarkerService(
            modelPath: DefaultConstants.modelPath,
            numHands: DefaultConstants.numHands,
            minHandDetectionConfidence: DefaultConstants.minHandDetectionConfidence,
            minHandPresenceConfidence: DefaultConstants.minHandPresenceConfidence,
            minTrackingConfidence: DefaultConstants.minTrackingConfidence,
            liveStreamDelegate: self,
            delegate: DefaultConstants.delegate
        )

        // 2. CameraFeedService 초기화
        cameraFeedService = CameraFeedService(previewView: previewView)
        cameraFeedService?.delegate = self

        // 3. GestureRecognizer 초기화 (실제 모델 파일 이름으로 변경 필요)
        // 예: "rps_model", "labels"
        gestureRecognizer = GestureRecognizer(modelPath: "basic_gesture_model", labelPath: "basic_label_map")
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
                // 손이 감지되지 않으면 오버레이와 라벨을 초기화합니다.
                self.overlayView.clear()
                self.gestureLabel.text = " "
                return
            }

            // 1. 랜드마크 그리기
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

            // 2. 제스처 인식
            if let gesture = self.gestureRecognizer?.classifyGesture(handLandmarkerResult: handLandmarkerResult!) {
                self.gestureLabel.text = gesture
            } else {
                self.gestureLabel.text = " "
            }
        }
    }
}

// MARK: - UIDeviceOrientation Extension
// 샘플 코드에 있던 유용한 확장 코드를 그대로 사용합니다.
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
