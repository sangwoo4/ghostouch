//
//  OpenSetting.swift
//  Runner
//
//  Created by 이상원 on 7/25/25.
//

import Foundation
import UIKit
import Flutter

// MARK:  플러터와 연동되는 클래스
class OpenSetting : NSObject {
    static func register(with registar: FlutterPluginRegistrar) {
        //플러터와 통신할 채널이름 설정
        let channel = FlutterMethodChannel(
            name: "com.pentagon.ghostouch/toggle",
            binaryMessenger: registar.messenger())
        
        // 클래스 인스턴스 생성
        let instance = OpenSetting()
        registar.addMethodCallDelegate(instance, channel: channel)
    }
}

//MARK: 메서드 호출 확장
extension OpenSetting: FlutterPlugin {
    // 플러터에서 토글 누르면 이 함수 실행
    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        
        // 플러터에서 호출된 메서드 이름 확인
        if call.method == "functionToggle" {
            if let args = call.arguments as? [String: Any],
               let enabled = args["enabled"] as? Bool {
                
                print("Swift에서 functionToggle 호출됨. enabled: \(enabled)")
                
                if enabled { // 받은게 true일때
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        if UIApplication.shared.canOpenURL(url) {
                            UIApplication.shared.open(url, options: [:], completionHandler: nil)
                            result(true) //플러터에 성공알림
                        }
                        else { //설정 못열때
                            result(FlutterError(
                                code: "UNAVAILABLE",
                                message: "Cannot open settings URL",
                                details: nil))
                        }
                    }
                    else {  // URL 생성 실패
                        result(FlutterError(
                            code: "INVALID_URL",
                            message: "Invalid settings URL",
                            details: nil))
                    }
                }
                else {
                    // 받은게 false일 때(필요하다면 추가)
                    result(true)
                }
            } else {
                result(FlutterError(
                    code: "INVALID_ARGUMENT",
                    message: "enabled 인자가 누락되었거나 유효하지 않습니다.",
                    details: nil))
            }
        }
        else {
            result(FlutterMethodNotImplemented)
        }
    }
    
}
