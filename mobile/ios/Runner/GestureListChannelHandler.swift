//
//  GestureListChannel.swift
//  Runner
//
//  Created by 이상원 on 8/17/25.
//

import Foundation
import Flutter
import UIKit

// 제스처-액션 매핑 영구 저장 도우미
class GestureActionPersistence {
    static let shared = GestureActionPersistence()
    private let userDefaults = UserDefaults.standard
    private let gestureActionKeyPrefix = "gesture_action_"

    func getAction(forGesture gesture: String) -> String? {
        return userDefaults.string(forKey: gestureActionKeyPrefix + gesture)
    }

    func setAction(forGesture gesture: String, action: String) {
        userDefaults.set(action, forKey: gestureActionKeyPrefix + gesture)
    }
}


class GestureListChannelHandler: NSObject, FlutterPlugin {
    
    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "com.pentagon.ghostouch/mapping", binaryMessenger: registrar.messenger())
        let instance = GestureListChannelHandler() // 인스턴스 생성
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    // 플러터로부터의 메서드 호출을 처리
    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        
        case "getGestureAction":
            if let args = call.arguments as? [String: Any],
               let gesture = args["gesture"] as? String {
                let action = GestureActionPersistence.shared.getAction(forGesture: gesture)
                result(action)
            } else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing 'gesture' argument.", details: nil))
            }
        case "setGestureAction":
            if let args = call.arguments as? [String: Any],
               let gesture = args["gesture"] as? String,
               let action = args["action"] as? String {
                GestureActionPersistence.shared.setAction(forGesture: gesture, action: action)
                result(nil) // 성공을 알림
            } else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing 'gesture' or 'action' argument.", details: nil))
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
