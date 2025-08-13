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
      // CameraPlatformViewFactory를 직접 등록
      // "camera_view" -> Flutter 코드에서 PlatformView를 식별하는 데 사용되는 고유 ID
      if let registrar = self.registrar(forPlugin: "camera-view-plugin") {
          let cameraFactory = CameraPlatformViewFactory(messenger: registrar.messenger())
          registrar.register(cameraFactory, withId: "camera_view")
      }
      
      //TestPage Platform 등록
      if let testReg = registrar(forPlugin: "test-page-view-plugin") {
          TestPagePlatformViewFactory.register(with: testReg)
      }


//      // PlatformViewFactory 등록
//      let factory = CameraPlatformViewFactory(messenger: messenger)
//      registrar(forPlugin: "camera_platform_view")?
//        .register(factory, withId: "camera_view")

      return super.application(application, didFinishLaunchingWithOptions: launchOptions)

  }
}
