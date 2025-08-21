import Foundation
import Flutter
import UIKit

// 제스처-액션 매핑을 영구 저장하는 도우미
class GestureActionPersistence {
    static let shared = GestureActionPersistence()
    private let userDefaults = UserDefaults.standard
    private let gestureActionsKey = "gesture_actions_mapping" // 모든 제스처를 저장할 단일 키

    // 기본 제스처 목록
    private let defaultGestures = ["rock", "paper", "scissors"]

    // MARK: - Public 함수
    func getAction(forGesture gesture: String) -> String? {
        let actions = getActions()
        return actions[gesture.lowercased()]
    }

    func setAction(forGesture gesture: String, action: String) {
        var actions = getActions()
        actions[gesture.lowercased()] = action
        saveActions(actions)
    }

    func clearAllCustomGestureActions() {
        var actions = getActions()
        
        let keysToRemove = actions.keys.filter { !defaultGestures.contains($0) }
        
        for key in keysToRemove {
            actions.removeValue(forKey: key)
        }
        
        saveActions(actions)
        print("커스텀 제스처에 대한 모든 기능 설정이 초기화되었습니다.")
    }

    // MARK: - Private Helper 함수
    private func getActions() -> [String: String] {
        return userDefaults.dictionary(forKey: gestureActionsKey) as? [String: String] ?? [:]
    }

    private func saveActions(_ actions: [String: String]) {
        userDefaults.set(actions, forKey: gestureActionsKey)
    }
}


class GestureListChannelHandler: NSObject, FlutterPlugin {
    
    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "com.pentagon.ghostouch/mapping",
            binaryMessenger: registrar.messenger()
        )
        let instance = GestureListChannelHandler()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    // 플러터에서 온 메서드 호출 처리
    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        
        case "getGestureAction":
            if let args = call.arguments as? [String: Any],
               let gesture = args["gesture"] as? String {
                let action = GestureActionPersistence.shared.getAction(forGesture: gesture)
                result(action)
            } else {
                result(FlutterError(
                    code: "INVALID_ARGUMENTS",
                    message: "'gesture' 인자가 없음",
                    details: nil
                ))
            }

        case "setGestureAction":
            if let args = call.arguments as? [String: Any],
               let gesture = args["gesture"] as? String,
               let action = args["action"] as? String {
                GestureActionPersistence.shared.setAction(forGesture: gesture, action: action)
                result(nil) // 성공 알림
            } else {
                result(FlutterError(
                    code: "INVALID_ARGUMENTS",
                    message: "'gesture' 또는 'action' 인자가 없음",
                    details: nil
                ))
            }

        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
