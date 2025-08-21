//
//import UIKit
//import MediaPipeTasksVision
//import FlexLayout
//import PinLayout
//
//class CameraForLandmark: UIView {
//
//    private let root = UIView()
//    private var overlayView: OverlayView!
//
//    // MARK: - Initializers
//    override init(frame: CGRect) {
//        super.init(frame: frame)
//        setupUI()
//    }
//
//    required init?(coder: NSCoder) {
//        fatalError("init(coder:) has not been implemented")
//    }
//
//    // MARK: - Layout
//    override func layoutSubviews() {
//        super.layoutSubviews()
//        root.pin.all()
//        root.flex.layout()
//    }
//
//    // MARK: - Public Method
//    // TestPage로부터 랜드마크 데이터를 받아 그리는 메서드
//    public func drawLandmarks(result: HandLandmarkerResult, imageSize: CGSize) {
//        let handOverlays = OverlayView.handOverlays(
//            fromMultipleHandLandmarks: result.landmarks,
//            inferredOnImageOfSize: imageSize,
//            ovelayViewSize: self.overlayView.bounds.size,
//            imageContentMode: .scaleAspectFill,
//            andOrientation: .up
//        )
//        self.overlayView.draw(
//            handOverlays: handOverlays,
//            inBoundsOfContentImageOfSize: imageSize,
//            imageContentMode: .scaleAspectFill
//        )
//    }
//    
//    public func clearView() {
//        self.overlayView.clear()
//    }
//
//    // MARK: - UI Setup
//    private func setupUI() {
//        self.backgroundColor = .clear
//
//        overlayView = OverlayView()
//        overlayView.backgroundColor = .clear
//        // 랜드마크 색상 : 파란색
//        overlayView.lineColor = .blue
//        overlayView.pointColor = .blue
//        overlayView.pointFillColor = .blue
//        
//        addSubview(root)
//        root.flex.define { flex in
//            flex.addItem(overlayView).position(.absolute).all(0)
//        }
//    }
//}
