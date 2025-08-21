import Flutter
import UIKit

// FlutterPlatformView가 CameraPreviewView(UIViewController)를 관리하도록 함
class CameraPlatformView: NSObject, FlutterPlatformView {
  private let _cameraController: CameraPreviewView

  init(frame: CGRect, viewIdentifier: Int64, arguments: Any?, messenger: FlutterBinaryMessenger) {
    // 카메라 프리뷰 컨트롤러 생성함
    let isCameraEnabled = GestureServiceState.shared.isGestureServiceEnabled
    _cameraController = CameraPreviewView(isCameraEnabled: isCameraEnabled)
    super.init()
  }

  // Flutter에 표시할 뷰 반환함
  func view() -> UIView {
    return _cameraController.view
  }

  // 소멸 시 데이터 수집 중단하고 초기화함
  deinit {
    print("CameraPlatformView 소멸됨. 데이터 수집 중단하고 초기화")
    Task { @MainActor in
      GestureRecognitionService.shared.stopRecording()
    }
  }
}

// Factory 클래스는 변경 필요 없음
class CameraPlatformViewFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger
  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    return CameraPlatformView(frame: frame, viewIdentifier: viewId, arguments: args, messenger: messenger)
  }
}
