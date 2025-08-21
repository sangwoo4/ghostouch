import Flutter
import UIKit

// Notification name for toggling the flashlight
extension Notification.Name {
    static let toggleFlashlight = Notification.Name("toggleFlashlightNotification")
}


@main

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
//      if let testReg = registrar(forPlugin: "test-page-view-plugin") {
//          TestPagePlatformViewFactory.register(with: testReg)
//      }

      // WebView Platform 등록
      if let webviewReg = registrar(forPlugin: "webview-view-plugin") {
          WebViewPlatformViewFactory.register(with: webviewReg)
      }

      // ControlAppPage Camera Platform 등록
      if let controlCameraReg = registrar(forPlugin: "control-camera-view-plugin") {
          ControlCameraPlatformViewFactory.register(with: controlCameraReg)
      }

      // ProgressBarChannel 등록
      if let progressReg = registrar(forPlugin: "progress-bar-channel-plugin") {
          ProgressBarChannel.register(with: progressReg)
      }

      // reset-gesture 채널 등록
      if let resetReg = registrar(forPlugin: "ResetGestureChannel") {
          ResetGestureChannel.register(with: resetReg)
      }

      // GestureListChannel 등록
      if let mappingReg = registrar(forPlugin: "GestureListChannelHandler") {
          GestureListChannelHandler.register(with: mappingReg)
      }

      // GestureListRegisterChannel 등록
      if let gestureListReg = registrar(forPlugin: "GestureListRegisterChannel") {
          GestureListRegisterChannel.register(with: gestureListReg)
      }

      // CameraChannelHandler 등록
      if let cameraHandlerReg = registrar(forPlugin: "CameraChannelHandler") {
          CameraChannelHandler.register(with: cameraHandlerReg)
      }

      // TaskIdChannel 등록
      if let taskIdReg = registrar(forPlugin: "TaskIdChannel") {
          TaskIdChannel.register(with: taskIdReg)
      }

      return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
