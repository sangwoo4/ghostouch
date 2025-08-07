import Flutter
import UIKit

//@main
@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
      // 기본 플러그인 등록
      GeneratedPluginRegistrant.register(with: self)

//      // FlutterViewController / messenger 준비
//      guard let controller = window?.rootViewController as? FlutterViewController else {
//        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
//      }
//      let messenger = controller.binaryMessenger

      // OpenSetting 채널 등록
      if let settingReg = registrar(forPlugin: "OpenSetting") {
        OpenSetting.register(with: settingReg)
      }
//      if let cameraReg = registrar(forPlugin: "OpenCamera") {
//        OpenCamera.register(with: cameraReg)
//      }
      if let cameraReg = registrar(forPlugin: "CameraViewPlugin") {
          CameraViewPlugin.register(with: cameraReg)
      }

//      // PlatformViewFactory 등록
//      let factory = CameraPlatformViewFactory(messenger: messenger)
//      registrar(forPlugin: "camera_platform_view")?
//        .register(factory, withId: "camera_view")

      return super.application(application, didFinishLaunchingWithOptions: launchOptions)

  }
}
