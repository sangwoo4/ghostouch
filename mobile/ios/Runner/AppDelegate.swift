import Flutter
import UIKit

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
      GeneratedPluginRegistrant.register(with: self)

      // OpenSetting 채널 등록
      if let settingReg = registrar(forPlugin: "OpenSetting") {
        OpenSetting.register(with: settingReg)
      }
      
      // CameraPlatformViewFactory 등록
      if let registrar = self.registrar(forPlugin: "camera-view-plugin") {
          let cameraFactory = CameraPlatformViewFactory(messenger: registrar.messenger())
          registrar.register(cameraFactory, withId: "camera_view")
      }
      
      // TestPage Platform 등록
      if let testReg = registrar(forPlugin: "test-page-view-plugin") {
          TestPagePlatformViewFactory.register(with: testReg)
      }

      // ProgressBarChannel 등록
      if let progressReg = registrar(forPlugin: "progress-bar-channel-plugin") {
          ProgressBarChannel.register(with: progressReg)
      }

      return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
