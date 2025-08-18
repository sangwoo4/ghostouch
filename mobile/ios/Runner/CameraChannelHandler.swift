//
//  CameraChannelHandler.swift
//  Runner
//
//  Created by 이상원 on 8/17/25.
//

import Foundation
import Flutter
import UIKit

class CameraChannelHandler: NSObject, FlutterPlugin {
    private let binaryMessenger: FlutterBinaryMessenger // Store the binary messenger

    init(binaryMessenger: FlutterBinaryMessenger) {
        self.binaryMessenger = binaryMessenger
        super.init()
    }

    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "com.pentagon.ghostouch/camera", binaryMessenger: registrar.messenger())
        let instance = CameraChannelHandler(binaryMessenger: registrar.messenger()) // Pass messenger to initializer
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "openSettings":
            // Redirect to OpenSetting.swift's openSettings logic
            // Use the stored binaryMessenger
            let toggleChannel = FlutterMethodChannel(name: "com.pentagon.ghostouch/toggle", binaryMessenger: self.binaryMessenger)
            toggleChannel.invokeMethod("openSettings", arguments: nil) { res in
                result(res) // Pass the result back to Dart
            }
        case "startCamera":
            // Placeholder for starting camera.
            // Actual camera start logic needs to be implemented here or called from here.
            // For now, just return true to indicate success.
            print("Swift: startCamera 호출됨 (구현 필요)")
            result(true)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
