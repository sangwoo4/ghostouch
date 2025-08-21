import Foundation

// 제스처 서비스 상태 저장/관리
class GestureServiceState {
    static let shared = GestureServiceState()
    private init() {}
    
    private(set) var isGestureServiceEnabled = false
    
    func startService() {
        isGestureServiceEnabled = true
        print("제스처 서비스 상태: ON")
    }

    func stopService() {
        isGestureServiceEnabled = false
        print("제스처 서비스 상태: OFF")
    }
}
