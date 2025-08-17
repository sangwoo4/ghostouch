import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ControlAppPage extends StatefulWidget {
  final bool isToggleEnabled; // 메인에서 전달해준 토글 상태

  const ControlAppPage({super.key, required this.isToggleEnabled});

  @override
  State<ControlAppPage> createState() => _ControlAppPageState();
}

class _ControlAppPageState extends State<ControlAppPage> {
  static const controlAppChannel = MethodChannel(
    "com.pentagon.ghostouch/control-app",
  );

  // 메소드 채널 사용 시 하단 name을 가지고 각각 클릭이벤트 함수처리하면 하나의 메소드 채널을 가지고 안드로이드/ios에서 처리 가능할듯?
  final Map<String, List<Map<String, String>>> appCategories = {
    "OTT": [
      {"name": "YouTube", "icon": "assets/youtube.png", "package": "youtube"},
      {"name": "NetFlix", "icon": "assets/netflix.png", "package": "netflix"},
      {
        "name": "Coupang Play",
        "icon": "assets/coupangplay.png",
        "package": "coupang",
      },
      {"name": "Tving", "icon": "assets/tving.png", "package": "tving"},
      {"name": "Disney Plus", "icon": "assets/disney.png", "package": "disney"},
    ],
    "네비게이션": [
      {"name": "T-map", "icon": "assets/tmap.png", "package": "tmap"},
      {
        "name": "Kakao Map",
        "icon": "assets/kakaomap.png",
        "package": "kakaomap",
      },
    ],
  };

  Future<void> _launchApp(String packageName) async {
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

    try {
      await controlAppChannel.invokeMethod('openApp', {"package": packageName});
    } on PlatformException catch (e) {
      debugPrint("앱 실행 오류: ${e.message}");
    }
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
                onTap: () => _launchApp(app["package"]!),
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
                    onPressed: () => Navigator.pop(context),
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
              child: SingleChildScrollView(
                child: Column(
                  children: appCategories.entries
                      .map((entry) => _buildCategory(entry.key, entry.value))
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
