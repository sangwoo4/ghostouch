import Flutter
import Foundation

class ProgressBarChannel: NSObject, FlutterPlugin {
    static let channelName = "com.pentagon.gesture/task-id"
    static var channel: FlutterMethodChannel?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger())
        
        let instance = ProgressBarChannel()
        registrar.addMethodCallDelegate(instance, channel: channel)
        
        Self.channel = channel
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if call.method == "getTaskId" {
            // GestureRecognitionService에서 현재 task ID를 가져와 Dart로 전달
            Task { @MainActor in
                let taskId = GestureRecognitionService.shared.trainingManager.currentTaskId
                result(taskId)
            }
        }
        else {
            result(FlutterMethodNotImplemented)
        }
    }
}
