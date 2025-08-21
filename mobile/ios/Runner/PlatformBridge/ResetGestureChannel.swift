
import Flutter
import UIKit

// 제스처/모델 초기화 채널
public class ResetGestureChannel: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = ResetGestureChannel()
    let channel = FlutterMethodChannel(
      name: "com.pentagon.ghostouch/reset-gesture",
      binaryMessenger: registrar.messenger()
    )
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    if call.method == "reset" {
      // 1. 모델 파일 및 관련 데이터 삭제
      TrainingStore.shared.clearDownloadedFiles()
      LabelMapManager.shared.clearLabelMap()
      
      // 2. 저장된 커스텀 제스처 기능 설정 삭제 (수정된 부분)
      GestureActionPersistence.shared.clearAllCustomGestureActions()
      
      result(nil)
    } else {
      result(FlutterMethodNotImplemented)
    }
  }
}
