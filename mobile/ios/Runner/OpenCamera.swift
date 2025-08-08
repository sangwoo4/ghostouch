
import UIKit
import AVFoundation
import Flutter

class OpenCamera: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        // 채널 생성 + 위임 등록
        let channel = FlutterMethodChannel(name: "com.pentagon.ghostouch/camera", binaryMessenger: registrar.messenger())
        let instance = OpenCamera()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if call.method == "startCamera" {
            startCamera()
            result(nil)
        } else {
            result(FlutterMethodNotImplemented)
        }
    }

    private func startCamera() {
        // 카메라 사용 가능 여부 검사
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            let imagePickerController = UIImagePickerController()
            imagePickerController.sourceType = .camera
            imagePickerController.cameraDevice = .front // 전면 카메라

            var topViewController: UIViewController?
            if #available(iOS 13.0, *) {
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootViewController = windowScene.windows.first?.rootViewController {
                    topViewController = rootViewController
                }
            } else {
                topViewController = UIApplication.shared.keyWindow?.rootViewController
            }

            // 가장 위에 표시 중인 뷰컨 탐색
            if var topVC = topViewController {
                while let presentedViewController = topVC.presentedViewController {
                    topVC = presentedViewController
                }
                topVC.present(imagePickerController, animated: true, completion: nil)
            }
        }
    }
}
