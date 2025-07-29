import 'package:flutter/services.dart'; // 크로스 채널 import
import 'package:flutter/material.dart';
import 'package:ghostouch/pages/GestureRegisterPage.dart';

import 'pages/GestureSettingsPage.dart';

void main() {
  runApp(const AirCommandApp());
}

class AirCommandApp extends StatelessWidget {
  const AirCommandApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ghostouch',
      home: const MainPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  bool isGestureEnabled = false;

  // ✅ MethodChannel 선언
  static const platform = MethodChannel('com.pentagon.ghostouch/toggle');

  // ✅ functionToggle 함수 정의
  Future<void> functionToggle(bool enabled) async {
    print('✅ functionToggle 호출됨. 전달 값: $enabled'); // 로그로 채널 호출 확인

    try {
      await platform.invokeMethod('functionToggle', {'enabled': enabled});
      print('📡 네이티브에게 functionToggle 전송 완료: $enabled');

      if (enabled) {
        print('🔧 openSettings 호출 시도');
        await platform.invokeMethod('openSettings'); // 👈 설정 열기 추가
        print('✅ openSettings 호출 완료');
      }
    } on PlatformException catch (e) {
      print("❌ 네이티브 함수 호출 실패: '${e.message}'");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // 헤더 부분
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
            decoration: const BoxDecoration(
              color: Color(0xFF0E1539),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    CircleAvatar(
                      backgroundColor: Colors.white,
                      child: Text(
                        'Pentagon',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Icon(Icons.touch_app, size: 60, color: Colors.white),
                    CircleAvatar(
                      backgroundColor: Colors.white,
                      child: Icon(Icons.menu_book, size: 30),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'Ghostouch',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  '고스트 터치를 활용해 핸드폰을 터치 없이 제어할 수 있습니다',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(height: 30),

          // Toggle Switch
          _buildToggleCard(),

          // 기능 설정 카드들
          _buildMenuCard(
            icon: Icons.gesture,
            title: '제스처 기능 설정',
            subtitle: '새로운 제스처를 원하시면 하단 제스처 등록을 먼저 설정하세요.',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const GestureSettingsPage(),
                ),
              );
            },
          ),

          _buildMenuCard(
            icon: Icons.person,
            title: '사용자 제스처 등록',
            subtitle: '새로운 제스처를 등록할 수 있습니다.',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const GestureRegisterPage(),
                ),
              );
            },
          ),

          _buildBackgroundCard(),
        ],
      ),
    );
  }

  Widget _buildToggleCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ListTile(
          leading: const Icon(Icons.touch_app, color: Colors.orange),
          title: Text(isGestureEnabled ? '사용함' : '사용 안 함'),
          trailing: Switch(
            value: isGestureEnabled,
            onChanged: (val) {
              setState(() {
                isGestureEnabled = val;
              });
              functionToggle(val); // ✅ 네이티브 함수 호출
            },
          ),
        ),
      ),
    );
  }

  Widget _buildMenuCard({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ListTile(
          leading: Icon(icon, color: Colors.black),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(subtitle, style: const TextStyle(color: Colors.brown)),
          onTap: onTap, // ✅ 여기 수정됨
        ),
      ),
    );
  }

  Widget _buildBackgroundCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ListTile(
          leading: const Icon(Icons.access_time, color: Colors.black),
          title: const Text('백그라운드 자동 꺼짐'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text('4시간'),
              SizedBox(width: 8),
              Icon(Icons.settings, color: Colors.grey),
            ],
          ),
          onTap: () {
            // TODO: 설정 화면 이동
          },
        ),
      ),
    );
  }
}
