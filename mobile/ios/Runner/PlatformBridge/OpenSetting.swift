
import Foundation
import UIKit
import Flutter
import AVFoundation

// MARK: 플러터 연동
class OpenSetting: NSObject {
    static func register(with registar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "com.pentagon.ghostouch/toggle",
            binaryMessenger: registar.messenger()
        )
        let instance = OpenSetting()
        registar.addMethodCallDelegate(instance, channel: channel)
    }
}

// MARK: 메서드 처리
extension OpenSetting: FlutterPlugin {
    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "checkCameraPermission":
            print("카메라 권한 확인")
            let status = AVCaptureDevice.authorizationStatus(for: .video)

            if status == .notDetermined {
                print("권한 요청")
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    DispatchQueue.main.async { result(granted) }
                }
            } else {
                print("권한 상태: \(status == .authorized)")
                result(status == .authorized)
            }

        case "openSettings":
            print("설정 열기")
            if let url = URL(string: UIApplication.openSettingsURLString) {
                if UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                    result(true)
                } else {
                    result(FlutterError(code: "UNAVAILABLE", message: "설정 화면 열기 실패", details: nil))
                }
            } else {
                result(FlutterError(code: "INVALID_URL", message: "설정 URL 오류", details: nil))
            }

        case "startGestureService":
            print("제스처 서비스 시작")
            GestureServiceState.shared.startService()
            result(true)

        case "stopGestureService":
            print("제스처 서비스 중지")
            GestureServiceState.shared.stopService()
            result(true)
            
        case "getAvailableGestures":
            if let labelMap = LabelMapManager.shared.readLabelMap() {
                let gesturesMap = labelMap.mapValues { _ in true }
                result(gesturesMap)
            } else {
                result(FlutterError(code: "UNAVAILABLE", message: "제스처 조회 실패", details: nil))
            }

        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
