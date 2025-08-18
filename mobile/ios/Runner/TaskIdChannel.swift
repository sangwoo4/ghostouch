//
//  TaskIdChannel.swift
//  Runner
//
//  Created by 이상원 on 8/17/25.
//

import Foundation
import Flutter
import UIKit

class TaskIdChannel: NSObject, FlutterPlugin {
    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "com.pentagon.gesture/task-id", binaryMessenger: registrar.messenger())
        let instance = TaskIdChannel()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getTaskId":
            result(TrainingStore.shared.lastTaskId)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
