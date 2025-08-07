//
//  CameraPreviewView.swift
//  Runner
//
//  Created by 이상원 on 8/7/25.
//

import UIKit
import AVFoundation
import Flutter

/// Flutter 쪽 'camera_view' 타입의 PlatformViewFactory를 등록하는 클래스
@objc class CameraViewPlugin: NSObject, FlutterPlugin {
  /// OpenSetting.swift 처럼, registrar만 받아서 factory를 등록
  public static func register(with registrar: FlutterPluginRegistrar) {
    let factory = CameraPlatformViewFactory(messenger: registrar.messenger())
    registrar.register(factory, withId: "camera_view")
  }

  // FlutterPlugin 프로토콜 요구사항이지만 handle 은 쓰지 않으므로 그냥 NotImplemented
  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    result(FlutterMethodNotImplemented)
  }
}

// 1) UIView 역할: 세션 + 프리뷰 레이어
class CameraPreviewView: UIView {
    private let session = AVCaptureSession()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupSession()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setupSession() {
        session.sessionPreset = .high
        guard
          let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
          let input = try? AVCaptureDeviceInput(device: device)
        else { return }
        session.addInput(input)

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = bounds
        layer.addSublayer(previewLayer)

        session.startRunning()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.sublayers?.first?.frame = bounds
    }
}
