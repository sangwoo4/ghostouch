//
//  OpenSetting.swift
//  Runner
//
//  Created by 이상원 on 7/25/25.
//

import Foundation
import UIKit
import Flutter
import AVFoundation // 카메라 권한 확인을 위해

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
        
        switch call.method {
            
        case "checkCameraPermission":
            // 진짜 카메라 권한 상태를 확인해서 반환
            print("Swift: checkCameraPermission 호출됨 -> 실제 권한 확인")
            let status = AVCaptureDevice.authorizationStatus(for: .video)
            result(status == .authorized)

        case "openSettings":
            // 'openSettings'가 호출될 때만 설정 화면을 open
            print("Swift: openSettings 호출됨 -> 앱 설정 열기")
            if let url = URL(string: UIApplication.openSettingsURLString) {
                if UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                    result(true)
                } else {
                    result(FlutterError(code: "UNAVAILABLE", message: "설정 화면을 열 수 없습니다.", details: nil))
                }
            } else {
                result(FlutterError(code: "INVALID_URL", message: "잘못된 설정 URL입니다.", details: nil))
            }

        case "startGestureService":
            // 더 이상 설정 화면을 열지 않음
            print("Swift: startGestureService 호출됨")
            // 실제 서비스 시작 코드가 필요하면 추가
            result(true)

        case "stopGestureService":
            print("Swift: stopGestureService 호출됨")
            result(true)
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
