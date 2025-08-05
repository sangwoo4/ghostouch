import Flutter
import UIKit

//@main
@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    //GeneratedPluginRegistrant.register(with: self)
    
    if let registrar = self.registrar(forPlugin: "OpenSetting") {
        OpenSetting.register(with: registrar)
    }
    if let registrar = self.registrar(forPlugin: "OpenCamera") {
        OpenCamera.register(with: registrar)
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
