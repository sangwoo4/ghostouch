//
//  OpenSetting.swift
//  Runner
//
//  Created by 이상원 on 7/25/25.
//

import Foundation
import UIKit
import Flutter
import AVFoundation

// MARK:  플러터와 연동되는 클래스
class OpenSetting : NSObject {
    // 앱 전체에서 제스처 서비스 활성화 상태를 공유하기 위한 정적 변수
    static var isGestureServiceEnabled = false

    static func register(with registar: FlutterPluginRegistrar) {
        // 플러터와 통신할 채널 이름 설정
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
    // 플러터로부터의 메서드 호출을 처리
    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        
        switch call.method {
            
        case "checkCameraPermission":
            print("Swift: checkCameraPermission 호출됨")
            let status = AVCaptureDevice.authorizationStatus(for: .video)
            
            if status == .notDetermined {
                print("Swift: 권한 상태 .notDetermined -> 권한 요청")
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    DispatchQueue.main.async {
                        result(granted)
                    }
                }
            } else {
                print("Swift: 권한 상태 확인 -> \(status == .authorized)")
                result(status == .authorized)
            }

        case "openSettings":
            // 'openSettings'가 호출될 때만 설정 화면 open.
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
            print("Swift: startGestureService 호출됨 -> 상태: ON")
            OpenSetting.isGestureServiceEnabled = true
            result(true)

        case "stopGestureService":
            print("Swift: stopGestureService 호출됨 -> 상태: OFF")
            OpenSetting.isGestureServiceEnabled = false
            result(true)
            
        case "getAvailableGestures":
            if let labelMap = LabelMapManager.shared.readLabelMap() {
                let gesturesMap = labelMap.mapValues { _ in true }
                result(gesturesMap)
            } else {
                result(FlutterError(code: "UNAVAILABLE", message: "Failed to get available gestures.", details: nil))
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
