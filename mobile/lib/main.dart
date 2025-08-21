import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ghostouch/pages/ControlAppPage.dart';
import 'package:ghostouch/pages/GestureRegisterPage.dart';
import 'package:ghostouch/pages/GestureSettingsPage.dart';
import 'package:ghostouch/widgets/dialogs.dart';
import 'package:ghostouch/services/native_channel_service.dart';
import 'package:ghostouch/widgets/header.dart';
import 'package:ghostouch/widgets/cardMenu.dart';

void main() {
  runApp(const GhostouchApp());
}

class GhostouchApp extends StatelessWidget {
  const GhostouchApp({super.key});

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
  bool _isToggleBusy = false;
  String _selectedTimeoutLabel = '설정 안 함';

  static const Map<String, int> backgroundTimeoutOptions = {
    '설정 안 함': 0,
    '1시간': 60,
    '2시간': 120,
    '4시간': 240,
  };

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
      hasPermission = await NativeChannelService.toggleChannel.invokeMethod(
        'checkCameraPermission',
        32,
      );
    } on PlatformException catch (e) {
      print("카메라 권한 확인 실패: '${e.message}'");
    }

    setState(() {
      isGestureEnabled = hasPermission;
    });

    if (hasPermission) {
      await functionToggle(true);
    } else {
      await functionToggle(false);
    }
  }

  Future<void> functionToggle(bool enabled) async {
    try {
      if (enabled) {
        await NativeChannelService.toggleChannel.invokeMethod(
          'startGestureService',
        );
      } else {
        await NativeChannelService.toggleChannel.invokeMethod(
          'stopGestureService',
        );
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
          // 상단 헤더
          HeaderWidget(
            title: 'Ghostouch',
            description: '고스트 터치를 활용해 핸드폰을 터치 없이 제어할 수 있습니다',
            isMain: true,
          ),
          const SizedBox(height: 30),

          // ✅ 토글 카드
          ToggleCard(
            isGestureEnabled: isGestureEnabled,
            isToggleBusy: _isToggleBusy,
            onToggle: (value) async {
              setState(() {
                _isToggleBusy = true;
              });

              try {
                if (value) {
                  bool hasPermission = false;
                  try {
                    hasPermission = await NativeChannelService.toggleChannel
                        .invokeMethod('checkCameraPermission');
                  } on PlatformException catch (e) {
                    print("❌ 권한 확인 실패: ${e.message}");
                  }

                  if (hasPermission) {
                    await functionToggle(true);
                    setState(() => isGestureEnabled = true);
                  } else {
                    await CustomDialogs.showToggleDialog(
                      context,
                      NativeChannelService.toggleChannel,
                    );
                  }
                } else {
                  await functionToggle(false);
                  setState(() => isGestureEnabled = false);
                }
              } finally {
                setState(() => _isToggleBusy = false);
              }
            },
          ),

          // ✅ 제스처 기능 설정
          MenuCard(
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

          // ✅ 사용자 제스처 등록
          MenuCard(
            icon: Icons.person,
            title: '사용자 제스처 등록',
            subtitle: '새로운 제스처를 등록할 수 있습니다.',
            onTap: () {
              if (!isGestureEnabled) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('⚠️ 사용 안 함 상태에서는 기능을 사용할 수 없습니다.'),
                    behavior: SnackBarBehavior.floating,
                    margin: const EdgeInsets.only(top: 50, left: 20, right: 20),
                    backgroundColor: Colors.blue,
                    duration: const Duration(seconds: 2),
                  ),
                );
                return;
              }
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const GestureRegisterPage(),
                ),
              );
            },
          ),

          // ✅ 백그라운드 자동 꺼짐
          BackgroundCard(
            selectedTimeoutLabel: _selectedTimeoutLabel,
            timeoutOptions: backgroundTimeoutOptions,
            onSelected: (String value) async {
              setState(() => _selectedTimeoutLabel = value);

              try {
                await NativeChannelService.backgroundChannel.invokeMethod(
                  'setBackgroundTimeout',
                  {'minutes': backgroundTimeoutOptions[value]},
                );
              } on PlatformException catch (e) {
                print("❌ backgroundChannel 호출 실패: ${e.message}");
              }
            },
          ),

          // ✅ 외부 앱 제어
          MenuCard(
            icon: Icons.app_settings_alt,
            title: '외부 앱 제어',
            subtitle: 'OTT, T-map 등 다양한 앱을 제어할 수 있습니다.',
            onTap: () {
              if (!isGestureEnabled) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('⚠️ 사용 안 함 상태에서는 기능을 사용할 수 없습니다.'),
                    behavior: SnackBarBehavior.floating,
                    margin: const EdgeInsets.only(top: 50, left: 20, right: 20),
                    backgroundColor: Colors.blue,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      ControlAppPage(isToggleEnabled: isGestureEnabled),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
