import Foundation
import Flutter
import UIKit
import PinLayout
import FlexLayout
import MediaPipeTasksVision
import WebKit
import AVFoundation

class TestPage : UIView {
    // MARK: - UI Components
    private let root = UIView()
    private let top = UIView()

    private var bottomCamera: BottomCamera?
    private let landmarkCamera = CameraForLandmark()
    private let gestureLabel = UILabel()
    private let gestureActionLabel = UILabel()
    private var disabledLabel: UILabel!

    
    private var webView: WKWebView!
    
    // MARK: - Properties
    private let isCameraEnabled: Bool
    private let deviceControlService = DeviceControlService()
    private var actionableGestures: [String] = []

    
    // MARK: - Buttons
    private var openYoutubeBtn: UIButton = {
        let btn = UIButton(type: .system)
        var config = UIButton.Configuration.filled()
        config.title = "YouTube"
        config.baseForegroundColor = .white
        config.baseBackgroundColor = .systemRed
        config.cornerStyle = .large
        btn.configuration = config
        return btn
    }()
    private var openInstagramBtn: UIButton = {
        let btn = UIButton(type: .system)
        var config = UIButton.Configuration.filled()
        config.title = "Instagram"
        config.baseForegroundColor = .white
        config.baseBackgroundColor = .systemPurple
        config.cornerStyle = .large
        btn.configuration = config
        return btn
    }()
    private var openNaverBtn: UIButton = {
        let btn = UIButton(type: .system)
        var config = UIButton.Configuration.filled()
        config.title = "Naver"
        config.baseForegroundColor = .white
        config.baseBackgroundColor = .systemGreen
        config.cornerStyle = .large
        btn.configuration = config
        return btn
    }()
    private var backButton: UIButton = {
        let btn = UIButton(type: .system)
        var config = UIButton.Configuration.filled()
        config.title = "Back"
        config.baseForegroundColor = .white
        config.baseBackgroundColor = .darkGray
        config.cornerStyle = .medium
        btn.configuration = config
        return btn
    }()
    
    // MARK: - Gesture Action Properties
    private var gestureHoldTimer: Timer?
    private var currentHeldGesture: String?
    private var gestureStartTime: Date?
    private let requiredHoldDuration: TimeInterval = 1.5

    
    init(frame: CGRect, isCameraEnabled: Bool) {
        self.isCameraEnabled = isCameraEnabled
        super.init(frame: frame)
        setup()
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setup() {
        if isCameraEnabled {
            bottomCamera = BottomCamera()
            bottomCamera?.delegate = self
        }
        
        webView = WKWebView()
        
        gestureLabel.text = " "
        gestureLabel.textAlignment = .center
        gestureLabel.textColor = .black
        
        gestureActionLabel.text = "none"
        gestureActionLabel.textAlignment = .center
        gestureActionLabel.textColor = .systemRed
        gestureActionLabel.font = .systemFont(ofSize: 20, weight: .bold)
        
        addSubview(root)
        
        root.flex.direction(.column).define { (flex) in
            // top 60%
            flex.addItem(top).height(60%).define{ item in
                item.addItem(webView).position(.absolute).all(0)
                let buttonContainer = item.addItem().width(100%).alignItems(.center)
                buttonContainer.addItem(openYoutubeBtn).width(120).height(50).marginTop(50)
                buttonContainer.addItem(openInstagramBtn).width(120).height(50).marginTop(20)
                buttonContainer.addItem(openNaverBtn).width(120).height(50).marginTop(20)
                item.addItem(backButton).position(.absolute).top(20).left(20).width(70).height(40)
            }
            
            // bottom 40% container
            flex.addItem().height(40%).alignItems(.center).define { bottomFlex in
                if let cameraView = bottomCamera {

                    // 카메라 뷰들을 담을 가로 컨테이너

                    bottomFlex.addItem().direction(.row).justifyContent(.center).alignItems(.center).define { rowFlex in
                        rowFlex.addItem(cameraView).width(100).height(150).marginRight(10)
                        rowFlex.addItem(landmarkCamera).width(100).height(150).marginLeft(10)
                    }
                } else {
                    disabledLabel = UILabel()
                    disabledLabel.text = "카메라 비활성화"
                    disabledLabel.textColor = .black
                    disabledLabel.textAlignment = .center
                    disabledLabel.font = .systemFont(ofSize: 18)

                    bottomFlex.addItem(disabledLabel).height(150)

                }
                bottomFlex.addItem(gestureLabel).width(90%).marginTop(10)
                bottomFlex.addItem(gestureActionLabel).width(90%).marginTop(5)
            }
        }
        
        updateActionableGestures()
        goBackToInitialView()
        
        openYoutubeBtn.addTarget(self, action: #selector(openYouTube), for: .touchUpInside)
        openInstagramBtn.addTarget(self, action: #selector(openInsta), for: .touchUpInside)
        openNaverBtn.addTarget(self, action: #selector(openNaver), for: .touchUpInside)
        backButton.addTarget(self, action: #selector(goBackToInitialView), for: .touchUpInside)
    }
    
    // MARK: - Button Actions & View State Management
    @objc private func openYouTube() {
        guard let url = URL(string: "https://m.youtube.com") else { return }
        webView.load(URLRequest(url: url))
        showWebView()
    }
    
    @objc private func openInsta() {
        guard let url = URL(string: "https://www.instagram.com") else { return }
        webView.load(URLRequest(url: url))
        showWebView()
    }
    
    @objc private func openNaver() {
        guard let url = URL(string: "https://m.naver.com") else { return }
        webView.load(URLRequest(url: url))
        showWebView()
    }
    
    private func showWebView() {
        openYoutubeBtn.isHidden = true
        openInstagramBtn.isHidden = true
        openNaverBtn.isHidden = true
        backButton.isHidden = false
    }
    
    @objc private func goBackToInitialView() {
        webView.stopLoading()
        webView.loadHTMLString("", baseURL: nil)
        openYoutubeBtn.isHidden = false
        openInstagramBtn.isHidden = false
        openNaverBtn.isHidden = false
        backButton.isHidden = true
        resetGestureAction()
    }
    
    // MARK: - Gesture Logic
    private func updateActionableGestures() {
        // 등록된 제스처 가져오기
        guard let allGestures = LabelMapManager.shared.readLabelMap()?.keys else {
            self.actionableGestures = []
            return
        }

        //
        self.actionableGestures = allGestures.filter { gestureName in
            guard let action = GestureActionPersistence.shared.getAction(forGesture: gestureName) else {
                return false
            }
            return action != "none"
        }
        print("Updated actionable gestures: \(self.actionableGestures)")
    }

    private func handleGestureChange(to newGesture: String) {
        if newGesture != currentHeldGesture {
            resetGestureAction()
            currentHeldGesture = newGesture
            
            if self.actionableGestures.contains(newGesture) {
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
        gestureActionLabel.text = "\(gesture): \(String(format: "%.2f", elapsedTime))s"
        
        if elapsedTime >= requiredHoldDuration {
            performGestureAction(for: gesture)
            resetGestureAction()
        }
    }
    
    private func performGestureAction(for gesture: String) {
        print("\(gesture) action 발생")
        
        // UserDefaults에서 제스처에 매핑된 액션을 가져옵니다.
        if let actionName = GestureActionPersistence.shared.getAction(forGesture: gesture), actionName != "none" {
            // DeviceControlService의 handleAction을 호출합니다.
            deviceControlService.handleAction(actionName)
        } else {
            // 웹사이트 이동과 같은 TestPage의 자체 액션을 처리합니다.
            switch gesture {
            case "scissors":
                openInsta()
            default:
                break
            }
        }
    }

    private func resetGestureAction() {
        gestureHoldTimer?.invalidate()
        gestureHoldTimer = nil
        gestureStartTime = nil
        currentHeldGesture = nil
        gestureActionLabel.text = "none"
    }
    
    private func parseGestureName(from rawGesture: String) -> String {
        return rawGesture.components(separatedBy: " ").first ?? rawGesture
    }
    
    // MARK: - View Lifecycle
    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard isCameraEnabled else { return }
        if self.window != nil {
            updateActionableGestures()
            bottomCamera?.startSession()
        } else {
            bottomCamera?.stopSession()
            goBackToInitialView()
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        root.pin.all().margin(self.safeAreaInsets)
        root.flex.layout(mode: .fitContainer)
    }
}

// MARK: - BottomCameraDelegate
extension TestPage: BottomCameraDelegate {
    func bottomCamera(_ camera: BottomCamera, didRecognizeGesture gesture: String) {
        DispatchQueue.main.async {
            let parsedGesture = self.parseGestureName(from: gesture)
            self.gestureLabel.text = gesture
            self.handleGestureChange(to: parsedGesture)
        }
    }
    
    func bottomCamera(_ camera: BottomCamera, didFinishDetection result: HandLandmarkerResult, imageSize: CGSize) {
        DispatchQueue.main.async {
            self.landmarkCamera.drawLandmarks(result: result, imageSize: imageSize)
        }
    }
    
    func bottomCameraDidNotDetectHand(_ camera: BottomCamera) {
        DispatchQueue.main.async {
            self.gestureLabel.text = "none"
            self.landmarkCamera.clearView()
            self.handleGestureChange(to: "none")
        }
    }
}
