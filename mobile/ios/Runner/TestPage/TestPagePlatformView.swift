//
//  TestPagePlatformView.swift
//  Runner
//
//  Created by 이상원 on 8/9/25.
//

import Foundation
import UIKit
import Flutter

final class TestPagePlatformView: NSObject, FlutterPlatformView {
    private let nativeView: TestPage
    
    init(
        frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?,
        messenger: FlutterBinaryMessenger
    ) {
        let isCameraEnabled = OpenSetting.isGestureServiceEnabled
        self.nativeView = TestPage(frame: frame, isCameraEnabled: isCameraEnabled)
        super.init()
    }
    
    func view() -> UIView {
        nativeView
    }
}

final class TestPagePlatformViewFactory: NSObject, FlutterPlatformViewFactory {
    private let messenger: FlutterBinaryMessenger
    
    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }
    
    static func register(with registrar: FlutterPluginRegistrar) {
        registrar.register(
            TestPagePlatformViewFactory(messenger: registrar.messenger()),
            withId: "com.example.ghostouch/test_page_view")
    }
    
    func createArgsCodec() -> any FlutterMessageCodec & NSObjectProtocol {
        FlutterStandardMessageCodec.sharedInstance()
    }
    
    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) ->  FlutterPlatformView {
        TestPagePlatformView(frame: frame, viewIdentifier: viewId, arguments: args, messenger: messenger)
    }
}
