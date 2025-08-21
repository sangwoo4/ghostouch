import Foundation
import Flutter
import UIKit

// 제스처 목록 채널
class GestureListRegisterChannel: NSObject, FlutterPlugin {
    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "com.pentagon.ghostouch/list-gesture",
            binaryMessenger: registrar.messenger()
        )
        let instance = GestureListRegisterChannel()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "list-gesture":
            if let labelMap = LabelMapManager.shared.readLabelMap() {

                // 값 기준 정렬 후 키 배열 반환
                let gesturesList = labelMap.sorted { $0.value < $1.value }.map { $0.key }

                result(gesturesList)
            } else {
                result(FlutterError(
                    code: "UNAVAILABLE",
                    message: "제스처 목록 조회 실패",
                    details: nil
                ))
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
