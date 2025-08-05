import 'package:flutter/services.dart'; // 크로스 채널용 import
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

  // ✅ 추가: 다이얼로그 표시 함수
  Future<bool?> _showCustomDialog() {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: SizedBox(
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 16),
                const Icon(Icons.settings, size: 40, color: Colors.orange),
                const SizedBox(height: 12),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    '1단계: 🚀 "이동하기" 버튼을 눌러주세요\n'
                    '2단계: 📋 목록에서 \'Ghostouch\' 선택\n'
                    '3단계: 🔛 스위치를 \'사용 중\'으로 켜고 확인',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: Color(0xFF333333),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.of(context).pop(false);
                          },
                          child: const Text(
                            '취소',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            Navigator.of(context).pop(true);
                            try {
                              await platform.invokeMethod('openSettings');
                            } on PlatformException catch (e) {
                              print("❌ openSettings 호출 실패: ${e.message}");
                            }
                          },
                          child: const Text(
                            '이동하기',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  // ✅ functionToggle 함수 정의
  Future<void> functionToggle(bool enabled) async {
    print('✅ functionToggle 호출됨. 전달 값: $enabled');

    try {
      await platform.invokeMethod('functionToggle', {'enabled': enabled});
      print('📡 네이티브에게 functionToggle 전송 완료: $enabled');
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
            onChanged: (val) async {
              if (val) {
                // 사용자가 이동하기를 누르면 true, 아니면 false 반환
                final result = await _showCustomDialog();
                if (result == true) {
                  setState(() {
                    isGestureEnabled = true;
                  });
                  functionToggle(true);
                } else {
                  // 사용자가 취소하거나 아무 동작도 안 하면 false
                  setState(() {
                    isGestureEnabled = false;
                  });
                }
              } else {
                setState(() {
                  isGestureEnabled = false;
                });
                functionToggle(false); // OFF는 즉시 반영
              }
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
          onTap: onTap,
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
