//
//  CameraPlatformView.swift
//  Runner
//
//  Created by 이상원 on 8/7/25.
//

import Flutter
import UIKit

// FlutterPlatformView가 CameraPreviewView(UIViewController)를 관리하도록 수정합니다.
class CameraPlatformView: NSObject, FlutterPlatformView {
  //  private let _view: CameraPreviewView
  private let _cameraController: CameraPreviewView

  init(frame: CGRect, viewIdentifier: Int64, arguments: Any?, messenger: FlutterBinaryMessenger) {
    // CameraPreviewView 컨트롤러 인스턴스를 생성합니다.
    let isCameraEnabled = OpenSetting.isGestureServiceEnabled
    _cameraController = CameraPreviewView(isCameraEnabled: isCameraEnabled)
    super.init()
  }

  // Flutter에 보여줄 View로 컨트롤러의 view를 반환합니다.
  func view() -> UIView {
      //return _view
      return _cameraController.view
  }

  // CameraPlatformView가 소멸될 때 호출되어 데이터 수집을 확실히 중단하고 초기화합니다.
  deinit {
      print("CameraPlatformView 소멸. 데이터 수집을 중단하고 초기화합니다.")
      Task { @MainActor in
          GestureRecognitionService.shared.stopRecording()
      }
      
  }
}

// Factory 클래스는 변경할 필요가 없습니다.
class CameraPlatformViewFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger
  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    return CameraPlatformView(frame: frame, viewIdentifier: viewId, arguments: args, messenger: messenger)
  }
}
