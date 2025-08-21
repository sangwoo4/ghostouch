
import Foundation
import Flutter
import UIKit

class CameraChannelHandler: NSObject, FlutterPlugin {
    private let binaryMessenger: FlutterBinaryMessenger // 바이너리 메신저 보관

    init(binaryMessenger: FlutterBinaryMessenger) {
        self.binaryMessenger = binaryMessenger
        super.init()
    }

    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "com.pentagon.ghostouch/camera",
            binaryMessenger: registrar.messenger()
        )
        let instance = CameraChannelHandler(binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "openSettings":
            // OpenSetting.swift 로직 호출
            let toggleChannel = FlutterMethodChannel(
                name: "com.pentagon.ghostouch/toggle",
                binaryMessenger: self.binaryMessenger
            )
            toggleChannel.invokeMethod("openSettings", arguments: nil) { res in
                result(res)
            }

        case "startCamera":
            // 카메라 시작 로직 필요
            print("Swift: startCamera 호출됨 (구현 필요)")
            result(true)

        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
