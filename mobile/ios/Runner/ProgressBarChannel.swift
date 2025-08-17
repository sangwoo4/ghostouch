import Flutter
import Foundation

class ProgressBarChannel: NSObject, FlutterPlugin {
    static let channelName = "com.pentagon.ghostouch/hand_detection"
    static var channel: FlutterMethodChannel?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger())
        
        let instance = ProgressBarChannel()
        registrar.addMethodCallDelegate(instance, channel: channel)
        
        Self.channel = channel
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getTaskId":
            // GestureRecognitionService에서 현재 task ID를 가져와 Dart로 전달
            Task { @MainActor in
                let taskId = GestureRecognitionService.shared.trainingManager.currentTaskId
                result(taskId)
            }
            
        case "startCollecting":
            if let args = call.arguments as? [String: Any], let gestureName = args["gestureName"] as? String {
                Task { @MainActor in
                    GestureRecognitionService.shared.startCollecting(gestureName: gestureName)
                    result(true)
                }
            } else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "gestureName이 필요합니다.", details: nil))
            }

        case "uploadData":
            Task { @MainActor in
                GestureRecognitionService.shared.uploadCollectedData()
                result(true)
            }
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
