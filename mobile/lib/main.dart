import 'package:flutter/services.dart'; // 크로스 채널용 import
import 'package:flutter/material.dart';
import 'pages/GestureRegisterPage.dart';
import 'pages/GestureSettingsPage.dart';
import 'pages/TestPage.dart'; // ✅ 테스트 페이지 import

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

class _MainPageState extends State<MainPage> with WidgetsBindingObserver {
  bool isGestureEnabled = false;
  bool _isToggleBusy = false; // 처리 중 상태를 나타내는 변수

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkInitialPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkInitialPermission();
    }
  }

  Future<void> _checkInitialPermission() async {
    bool hasPermission = false;
    try {
      hasPermission = await toggleChannel.invokeMethod('checkCameraPermission');
      print('카메라 권한 상태: $hasPermission');
    } on PlatformException catch (e) {
      print("카메라 권한 확인 실패: '${e.message}'.");
    }

    setState(() {
      isGestureEnabled = hasPermission;
    });

    // 권한이 있으면 서비스 시작, 없으면 중지 (상태 동기화)
    if (hasPermission) {
      await functionToggle(true);
    } else {
      await functionToggle(false);
    }
  }

  String _selectedTimeoutLabel = '설정 안 함';
  static const Map<String, int> backgroundTimeoutOptions = {
    '설정 안 함': 0,
    '1시간': 60,
    '2시간': 120,
    '4시간': 240,
  };

  // ✅ MethodChannel 선언
  static const toggleChannel = MethodChannel('com.pentagon.ghostouch/toggle');
  static const foregroundChannel = MethodChannel(
    'com.pentagon.ghostouch/foreground',
  );
  static const backgroundChannel = MethodChannel(
    'com.pentagon.ghostouch/background',
  );

  // ✅ 추가: 다이얼로그 표시 함수
  Future<bool?> _showToggleDialog() {
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
                              await toggleChannel.invokeMethod('openSettings');
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

  Future<void> functionToggle(bool enabled) async {
    print('✅ functionToggle 호출됨. 전달 값: $enabled');

    try {
      if (enabled) {
        await toggleChannel.invokeMethod('startGestureService');
        print('📡 네이티브에 서비스 시작 명령 전송');
      } else {
        await toggleChannel.invokeMethod('stopGestureService');
        print('📡 네이티브에 서비스 중지 명령 전송');
      }
    } on PlatformException catch (e) {
      print("❌ 네이티브 함수 호출 실패: '${e.message}'");
    }
  }

  Future<void> _showBackgroundSelector() async {
    final durations = {'30분': 30, '1시간': 60, '2시간': 120, '4시간': 240};

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            const Text(
              '자동 꺼짐 시간 설정',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const Divider(),
            ...durations.entries.map((entry) {
              return ListTile(
                title: Text(entry.key),
                onTap: () async {
                  Navigator.of(context).pop();
                  try {
                    await backgroundChannel.invokeMethod(
                      'setBackgroundTimeout',
                      {'minutes': entry.value},
                    );
                    print('⏱️ 백그라운드 시간 설정 완료: ${entry.value}분');
                  } on PlatformException catch (e) {
                    print("❌ backgroundChannel 호출 실패: ${e.message}");
                  }
                },
              );
            }),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // 헤더 부분
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 30),
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
                          fontSize: 9,
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

          // ✅ 테스트 페이지 카드 (맨 아래)
          _buildMenuCard(
            icon: Icons.bug_report,
            title: '테스트 페이지',
            subtitle: '기능을 실험할 수 있는 화면입니다.',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TestPage()),
              );
            },
          ),
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
            onChanged: _isToggleBusy
                ? null
                : (value) async {
                    setState(() {
                      _isToggleBusy = true;
                    });

                    try {
                      // 사용자가 스위치를 켤 때
                      if (value) {
                        bool hasPermission = false;
                        try {
                          hasPermission = await toggleChannel.invokeMethod(
                            'checkCameraPermission',
                          );
                        } on PlatformException catch (e) {
                          print("❌ 권한 확인 실패: ${e.message}");
                        }

                        if (hasPermission) {
                          // 권한이 있으면 서비스 시작
                          await functionToggle(true);
                          setState(() {
                            isGestureEnabled = true;
                          });
                        } else {
                          // 권한이 없으면 설정 안내 다이얼로그 표시
                          await _showToggleDialog();
                        }
                      } else {
                        // 사용자가 스위치를 끌 때
                        await functionToggle(false);
                        setState(() {
                          isGestureEnabled = false;
                        });
                      }
                    } finally {
                      setState(() {
                        _isToggleBusy = false;
                      });
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
            children: [
              Text(_selectedTimeoutLabel, style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 4),
              PopupMenuButton<String>(
                icon: const Icon(Icons.settings, color: Colors.grey),
                onSelected: (String value) async {
                  setState(() {
                    _selectedTimeoutLabel = value;
                  });

                  try {
                    await backgroundChannel.invokeMethod(
                      'setBackgroundTimeout',
                      {'minutes': backgroundTimeoutOptions[value]},
                    );
                    print(
                      '✅ 백그라운드 꺼짐 시간 설정: $value (${backgroundTimeoutOptions[value]}분)',
                    );
                  } on PlatformException catch (e) {
                    print("❌ backgroundChannel 호출 실패: ${e.message}");
                  }
                },
                itemBuilder: (BuildContext context) {
                  return backgroundTimeoutOptions.keys.map((String choice) {
                    return PopupMenuItem<String>(
                      value: choice,
                      child: Text(choice),
                    );
                  }).toList();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
