//
//  GestureListRegisterChannel.swift
//  Runner
//
//  Created by 이상원 on 8/17/25.
//

import Foundation
import Flutter
import UIKit

class GestureListRegisterChannel: NSObject, FlutterPlugin {
    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "com.pentagon.ghostouch/list-gesture", binaryMessenger: registrar.messenger())
        let instance = GestureListRegisterChannel()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "list-gesture":
            if let labelMap = LabelMapManager.shared.readLabelMap() {
                // Convert [String: Int] to [String: Any] for Flutter
                // Dart expects a List<dynamic> for gestures, so we return the keys as an array.
                let gesturesList = Array(labelMap.keys)
                result(gesturesList)
            } else {
                result(FlutterError(code: "UNAVAILABLE", message: "Failed to get available gestures.", details: nil))
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
