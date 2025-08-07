//
//  CameraPlatformView.swift
//  Runner
//
//  Created by 이상원 on 8/7/25.
//

import Flutter
import UIKit

// 2) FlutterPlatformView 역할
class CameraPlatformView: NSObject, FlutterPlatformView {
  private let _view: CameraPreviewView

  init(frame: CGRect, viewIdentifier: Int64, arguments: Any?, messenger: FlutterBinaryMessenger) {
    _view = CameraPreviewView(frame: frame)
    super.init()
  }

  func view() -> UIView {
    return _view
  }
}

// 3) Factory
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
