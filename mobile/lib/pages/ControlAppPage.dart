import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ghostouch/services/native_channel_service.dart';
import 'package:ghostouch/data/app_categories.dart';

class ControlAppPage extends StatefulWidget {
  final bool isToggleEnabled; // 메인에서 전달해준 토글 상태

  const ControlAppPage({super.key, required this.isToggleEnabled});

  @override
  State<ControlAppPage> createState() => _ControlAppPageState();
}

class _ControlAppPageState extends State<ControlAppPage> {
  bool _showWebView = false;
  String _currentUrl = "";
  MethodChannel? _webViewChannel;

  final Map<String, String> ottUrls = {
    "youtube": "https://m.youtube.com",
    "netflix": "https://www.netflix.com/kr/",
    "tving": "https://m.tving.com/",
    "disney": "https://www.disneyplus.com/ko-kr",
    // "coupang": "https://www.coupangplay.com/", // m.coupangplayㄴㄴ
  };

  // iOS 전용: 전면 카메라 실행
  Future<void> _openFrontCamera() async {
    try {
      await NativeChannelService.iosCameraChannel.invokeMethod(
        'openFrontCamera',
      );
    } on PlatformException catch (e) {
      debugPrint("iOS 카메라 오류: ${e.message}");
    }
  }

  Future<void> _launchApp(String categoryName, String packageName) async {
    if (!widget.isToggleEnabled) {
      // 🚫 사용 안 함 상태 → 알림창만 띄우고 메소드 채널 호출 안함
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ 사용 안 함 상태에서는 기능을 사용할 수 없습니다.'),
          duration: Duration(seconds: 2),
        ),
      );
      return; // 메소드 채널 호출 차단
    }

    if (Platform.isIOS) {
      if (categoryName == "OTT") {
        setState(() {
          _currentUrl = ottUrls[packageName] ?? "";
          _showWebView = true;
        });
      } else {
        try {
          await NativeChannelService.controlAppChannel.invokeMethod('openApp', {
            "package": packageName,
          });
          await _openFrontCamera();
        } on PlatformException catch (e) {
          debugPrint("iOS 앱 실행 오류: ${e.message}");
        }
      }
    } else if (Platform.isAndroid) {
      try {
        await NativeChannelService.controlAppChannel.invokeMethod('openApp', {
          "package": packageName,
        });
      } on PlatformException catch (e) {
        debugPrint("Android 앱 실행 오류: ${e.message}");
      }
    }
  }

  void _hideWebView() {
    setState(() {
      _showWebView = false;
      _currentUrl = "";
    });
  }

  Widget _buildCategory(String categoryName, List<Map<String, String>> apps) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 카테고리 타이틀
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFD9E8F5),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              categoryName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 15),
          // 앱 리스트
          GridView.count(
            crossAxisCount: 4, // 한 줄에 4개씩
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.0,
            children: apps.map((app) {
              return GestureDetector(
                onTap: () => _launchApp(categoryName, app["package"]!),
                child: Column(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black26),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(5.0),
                        child: Image.asset(app["icon"]!, fit: BoxFit.contain),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      app["name"]!,
                      style: const TextStyle(fontSize: 10),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 상단 헤더
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 30),
              decoration: const BoxDecoration(
                color: Color(0xFF0E1539),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(30),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () {
                      if (_showWebView) {
                        _hideWebView();
                      } else {
                        Navigator.pop(context);
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '외부 앱 제어',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '앱을 클릭 후 제스처로 앱을 제어해보세요.',
                    style: TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: _showWebView
                  ? Column(
                      children: [
                        Expanded(
                          flex: 3, // WebView takes 3/4 of the available space
                          child: Platform.isIOS
                              ? UiKitView(
                                  viewType:
                                      'com.ghostouch.webview/webview_view',
                                  layoutDirection: TextDirection.ltr,
                                  creationParams: <String, dynamic>{
                                    'url': _currentUrl,
                                  },
                                  creationParamsCodec:
                                      const StandardMessageCodec(),
                                  onPlatformViewCreated: (int id) {
                                    _webViewChannel = MethodChannel(
                                      'com.ghostouch.webview/webview_view_$id',
                                    );
                                  },
                                )
                              : const Text(
                                  'WebView not supported on Android yet',
                                ), // Placeholder for Android
                        ),
                        if (Platform.isIOS && widget.isToggleEnabled)
                          Expanded(
                            flex:
                                1, // Camera view takes 1/4 of the available space
                            child: Center(
                              child: SizedBox(
                                width: 90,
                                height: 120,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: const UiKitView(
                                    viewType:
                                        'com.pentagon.ghostouch/control_camera_view',
                                    layoutDirection: TextDirection.ltr,
                                    creationParamsCodec: StandardMessageCodec(),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    )
                  : SingleChildScrollView(
                      child: Column(
                        children: appCategories.entries
                            .map(
                              (entry) => _buildCategory(entry.key, entry.value),
                            )
                            .toList(),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
