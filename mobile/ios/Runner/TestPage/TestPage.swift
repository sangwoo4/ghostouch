import Foundation
import Flutter
import UIKit
import PinLayout
import FlexLayout
import MediaPipeTasksVision
import WebKit

class TestPage : UIView {
    // MARK: - UI Components
    private let root = UIView()
    private let top = UIView()
    private let bottomCamera = BottomCamera()
    private let landmarkCamera = CameraForLandmark()
    private let gestureLabel = UILabel()
    private let gestureActionLabel = UILabel()
    
    private var webView: WKWebView!
    
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
    private let requiredHoldDuration: TimeInterval = 3.0

    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setup() {
        bottomCamera.delegate = self
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
            
            // bottom 40% container - 올바른 중첩 구조로 수정
            flex.addItem().height(40%).alignItems(.center).define { bottomFlex in
                // 카메라 뷰들을 담을 가로 컨테이너
                bottomFlex.addItem().direction(.row).justifyContent(.center).alignItems(.center).define { rowFlex in
                    rowFlex.addItem(bottomCamera).width(100).height(150).marginRight(10)
                    rowFlex.addItem(landmarkCamera).width(100).height(150).marginLeft(10)
                }
                // 라벨들을 카메라 컨테이너 아래에 추가
                bottomFlex.addItem(gestureLabel).width(90%).marginTop(10)
                bottomFlex.addItem(gestureActionLabel).width(90%).marginTop(5)
            }
        }
        
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
    
    // MARK: - Gesture Timer Logic
    private func handleGestureChange(to newGesture: String) {
        if newGesture != currentHeldGesture {
            resetGestureAction()
            currentHeldGesture = newGesture
            
            if newGesture == "paper" || newGesture == "rock" || newGesture == "scissors" {
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
        switch gesture {
        case "paper":
            openYouTube()
        case "rock":
            openNaver()
        case "scissors":
            openInsta()
        default:
            break
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
        if self.window != nil {
            bottomCamera.startSession()
        } else {
            bottomCamera.stopSession()
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
            self.gestureLabel.text = "\(parsedGesture)"
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
