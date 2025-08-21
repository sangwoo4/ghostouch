import Foundation
import Flutter
import UIKit
import WebKit

class WebView: UIView, WKNavigationDelegate {
    private var webView: WKWebView!
    private var initialUrl: String?

    init(frame: CGRect, initialUrl: String?) {
        super.init(frame: frame)
        self.initialUrl = initialUrl
        setupWebView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupWebView() {
        let webConfiguration = WKWebViewConfiguration()
        webView = WKWebView(frame: .zero, configuration: webConfiguration)
        webView.navigationDelegate = self
        webView.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(webView)
        
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: self.topAnchor),
            webView.bottomAnchor.constraint(equalTo: self.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: self.trailingAnchor)
        ])

        if let urlString = initialUrl, let url = URL(string: urlString) {
            webView.load(URLRequest(url: url))
        }
    }
    
    func loadUrl(_ urlString: String) {
        if let url = URL(string: urlString) {
            webView.load(URLRequest(url: url))
        }
    }
    
    func goBack() {
        if webView.canGoBack {
            webView.goBack()
        }
    }
    
    func goForward() {
        if webView.canGoForward {
            webView.goForward()
        }
    }
    
    func reload() {
        webView.reload()
    }

    deinit {
        webView.navigationDelegate = nil
        webView.stopLoading()
    }
}

final class WebViewPlatformView: NSObject, FlutterPlatformView {
    private let webView: WebView
    private let channel: FlutterMethodChannel

    init(
        frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?,
        binaryMessenger messenger: FlutterBinaryMessenger
    ) {
        let initialUrl = (args as? [String: Any])?["url"] as? String
        self.webView = WebView(frame: frame, initialUrl: initialUrl)
        self.channel = FlutterMethodChannel(
            name: "com.ghostouch.webview/webview_view_\(viewId)",
            binaryMessenger: messenger
        )
        super.init()
        
        self.channel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
            guard let self = self else { return }
            switch call.method {
            case "loadUrl":
                if let url = call.arguments as? String {
                    self.webView.loadUrl(url)
                    result(nil)
                } else {
                    result(FlutterError(code: "INVALID_ARGUMENT", message: "URL 인자가 없음", details: nil))
                }
            case "goBack":
                self.webView.goBack()
                result(nil)
            case "goForward":
                self.webView.goForward()
                result(nil)
            case "reload":
                self.webView.reload()
                result(nil)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }
    
    func view() -> UIView {
        return webView
    }
}

final class WebViewPlatformViewFactory: NSObject, FlutterPlatformViewFactory {
    private let messenger: FlutterBinaryMessenger
    
    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }
    
    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }
    
    func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        return WebViewPlatformView(
            frame: frame,
            viewIdentifier: viewId,
            arguments: args,
            binaryMessenger: messenger
        )
    }
    
    static func register(with registrar: FlutterPluginRegistrar) {
        registrar.register(
            WebViewPlatformViewFactory(messenger: registrar.messenger()),
            withId: "com.ghostouch.webview/webview_view"
        )
    }
}
