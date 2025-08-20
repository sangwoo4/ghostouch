import Foundation
import Flutter
import UIKit
import AVFoundation
import MediaPipeTasksVision

// 1. The View that contains the camera preview
@MainActor
class ControlCameraView: UIView, CameraFeedServiceDelegate, HandLandmarkerServiceLiveStreamDelegate {

    // MARK: - Services and Properties
    private var cameraFeedService: CameraFeedService?
    private var handLandmarkerService: HandLandmarkerService?
    private let gestureRecognitionService = GestureRecognitionService.shared
    private let deviceControlService = DeviceControlService()

    // MARK: - UI
    private var previewView: UIView!
    private var overlayView: OverlayView!

    // MARK: - Gesture Action Properties
    private var gestureHoldTimer: Timer?
    private var currentHeldGesture: String?
    private var gestureStartTime: Date?
    private let requiredHoldDuration: TimeInterval = 1.0
    private var actionableGestures: [String] = []

    // MARK: - Initializers
    init(frame: CGRect, isCameraEnabled: Bool) {
        super.init(frame: frame)
        if isCameraEnabled {
            setupUI()
            setupServices()
            updateActionableGestures()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - View Lifecycle
    override func didMoveToWindow() {
        super.didMoveToWindow()
        if self.window != nil {
            cameraFeedService?.startLiveCameraSession { _ in }
        } else {
            cameraFeedService?.stopSession()
            resetGestureAction()
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        previewView.frame = self.bounds
        overlayView.frame = self.bounds
        cameraFeedService?.updateVideoPreviewLayer(toFrame: self.bounds)
    }

    // MARK: - Setup
    private func setupUI() {
        previewView = UIView(frame: self.bounds)
        previewView.backgroundColor = .clear
        previewView.isHidden = true
        addSubview(previewView)

        overlayView = OverlayView(frame: self.bounds)
        overlayView.backgroundColor = .clear
        addSubview(overlayView)
    }

    private func setupServices() {
        cameraFeedService = CameraFeedService(previewView: previewView)
        cameraFeedService?.delegate = self

        handLandmarkerService = gestureRecognitionService.handLandmarkerService
        handLandmarkerService?.liveStreamDelegate = self
    }

    // MARK: - Gesture Logic (from TestPage.swift)
    private func updateActionableGestures() {
        guard let allGestures = LabelMapManager.shared.readLabelMap()?.keys else {
            self.actionableGestures = []
            return
        }
        self.actionableGestures = allGestures.filter { gestureName in
            guard let action = GestureActionPersistence.shared.getAction(forGesture: gestureName) else {
                return false
            }
            return action != "none"
        }
        print("ControlApp actionable gestures: \(self.actionableGestures)")
    }

    private func handleGestureChange(to newGesture: String) {
        let parsedGesture = parseGestureName(from: newGesture)
        
        if parsedGesture != currentHeldGesture {
            resetGestureAction()
            currentHeldGesture = parsedGesture
            
            if self.actionableGestures.contains(parsedGesture) {
                gestureStartTime = Date()
                gestureHoldTimer = Timer.scheduledTimer(timeInterval: 0.05, target: self, selector: #selector(updateHoldTimer), userInfo: nil, repeats: true)
            }
        }
    }

    @objc private func updateHoldTimer() {
        guard let startTime = gestureStartTime, let gesture = currentHeldGesture else {
            resetGestureAction()
            return
        }
        
        let elapsedTime = Date().timeIntervalSince(startTime)
        
        if elapsedTime >= requiredHoldDuration {
            performGestureAction(for: gesture)
            resetGestureAction()
        }
    }

    private func performGestureAction(for gesture: String) {
        print("Action triggered for gesture: \(gesture)")
        if let actionName = GestureActionPersistence.shared.getAction(forGesture: gesture), actionName != "none" {
            deviceControlService.handleAction(actionName)
        }
    }

    private func resetGestureAction() {
        gestureHoldTimer?.invalidate()
        gestureHoldTimer = nil
        gestureStartTime = nil
        currentHeldGesture = nil
    }

    private func parseGestureName(from rawGesture: String) -> String {
        return rawGesture.components(separatedBy: " ").first ?? rawGesture
    }

    // MARK: - CameraFeedServiceDelegate
    func didOutput(sampleBuffer: CMSampleBuffer, orientation: UIImage.Orientation) {
        autoreleasepool {
            let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            let milliseconds = CMTimeGetSeconds(timestamp) * 1000
            handLandmarkerService?.detectAsync(
                sampleBuffer: sampleBuffer,
                orientation: orientation,
                timeStamps: Int(milliseconds)
            )
        }
    }
    
    func didEncounterSessionRuntimeError() { print("ControlCameraView: Session runtime error.") }
    func sessionWasInterrupted(canResumeManually resumeManually: Bool) { print("ControlCameraView: Session interrupted.") }
    func sessionInterruptionEnded() { print("ControlCameraView: Session interruption ended.") }

    // MARK: - HandLandmarkerServiceLiveStreamDelegate
    func handLandmarkerService(
        _ handLandmarkerService: HandLandmarkerService,
        didFinishDetection result: ResultBundle?,
        error: Error?
    ) {
        DispatchQueue.main.async {
            if let error = error {
                print("Landmark detection error: \(error.localizedDescription)")
                self.handleGestureChange(to: "none")
                return
            }

            guard let handLandmarkerResult = result?.handLandmarkerResults.first,
                  let unwrappedResult = handLandmarkerResult else {
                self.overlayView.clear()
                self.handleGestureChange(to: "none")
                self.gestureRecognitionService.resetCollectionStateIfNeeded()
                return
            }
            
            let imageSize = self.cameraFeedService?.videoResolution ?? .zero
            let handOverlays = OverlayView.handOverlays(
                fromMultipleHandLandmarks: unwrappedResult.landmarks,
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

            let recognizedGesture = self.gestureRecognitionService.recognizeAndCollect(result: unwrappedResult)
            self.handleGestureChange(to: recognizedGesture ?? "none")
        }
    }
}


// 2. The PlatformView that wraps the ControlCameraView
@MainActor
class ControlCameraPlatformView: NSObject, FlutterPlatformView {
    private let nativeView: ControlCameraView

    init(frame: CGRect, viewIdentifier: Int64, arguments: Any?, messenger: FlutterBinaryMessenger) {
        let isCameraEnabled = OpenSetting.isGestureServiceEnabled
        self.nativeView = ControlCameraView(frame: frame, isCameraEnabled: isCameraEnabled)
        super.init()
    }

    func view() -> UIView {
        return nativeView
    }
}

// 3. The Factory that creates the PlatformView
@MainActor
class ControlCameraPlatformViewFactory: NSObject, FlutterPlatformViewFactory {
    private let messenger: FlutterBinaryMessenger
    
    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }
    
    static func register(with registrar: FlutterPluginRegistrar) {
        registrar.register(
            ControlCameraPlatformViewFactory(messenger: registrar.messenger()),
            withId: "com.pentagon.ghostouch/control_camera_view")
    }
    
    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }
    
    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
        return ControlCameraPlatformView(frame: frame, viewIdentifier: viewId, arguments: args, messenger: messenger)
    }
}
