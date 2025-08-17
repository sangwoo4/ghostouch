//
//  ResetGestureChannel.swift
//  Runner
//
//  Created by 이상원 on 8/16/25.
//

import Flutter
import UIKit

public class ResetGestureChannel: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = ResetGestureChannel()
    let channel = FlutterMethodChannel(name: "com.pentagon.ghostouch/reset-gesture", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    if call.method == "reset" {
      TrainingStore.shared.clearDownloadedFiles()
      LabelMapManager.shared.clearLabelMap()
      result(nil)
    } else {
      result(FlutterMethodNotImplemented)
    }
  }
}
