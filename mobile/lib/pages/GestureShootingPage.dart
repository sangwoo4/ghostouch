import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class GestureShootingPage extends StatefulWidget {
  // GestureRegisterPage로부터 제스처 이름을 전달받기 위해 final로 선언
  final String gestureName;

  const GestureShootingPage({Key? key, required this.gestureName}) : super(key: key);

  @override
  _GestureShootingPageState createState() => _GestureShootingPageState();
}

class _GestureShootingPageState extends State<GestureShootingPage> {
  static const platform = MethodChannel('com.pentagon.ghostouch/hand_detection');

  // UI 상태 관리를 위한 변수들
  bool _isCollecting = false;
  bool _isCompleted = false;
  double _progressPercent = 0.0;

  @override
  void initState() {
    super.initState();
    // 네이티브에서 오는 호출을 수신할 핸들러 설정
    platform.setMethodCallHandler(_handleMethodCall);
  }

  @override
  void dispose() {
    // 화면이 사라질 때, 만약 수집 중이었다면 중단 신호를 보냄
    if (_isCollecting) {
      _stopCollecting();
    }
    super.dispose();
  }

  // 네이티브로부터 오는 메소드 호출을 처리
  Future<void> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'updateProgress':
        final int progress = call.arguments as int;
        setState(() {
          _progressPercent = progress / 100.0;
        });
        break;
      case 'collectionComplete':
        setState(() {
          _isCollecting = false;
          _isCompleted = true;
          _progressPercent = 1.0;
        });
        break;
      default:
        print('Unknown method ${call.method}');
    }
  }

  // "다시촬영" 또는 "수집 시작" 버튼을 눌렀을 때 호출
  Future<void> _startOrRetakeRecording() async {
    setState(() {
      _isCollecting = true;
      _isCompleted = false;
      _progressPercent = 0.0;
    });
    try {
      await platform.invokeMethod('startCollecting', {'gestureName': widget.gestureName});
      print("Native call: Started collecting for ${widget.gestureName}");
    } on PlatformException catch (e) {
      print("Failed to call startCollecting: '${e.message}'.");
      setState(() {
        _isCollecting = false;
      });
    }
  }

  // "저장하기" 버튼을 눌렀을 때 호출
  Future<void> _saveGesture() async {
    // 1. 네이티브에 수집 중단 신호 전송 및 서버 업로드 시작
    await _stopCollecting();

    // 2. 훈련 시작 안내
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("서버에 데이터를 업로드하고 모델 훈련을 시작합니다..."),
        duration: Duration(seconds: 3),
      ),
    );

    // 3. 이전 화면으로 돌아가기
    Navigator.of(context).pop();
    Navigator.of(context).pop();
    
    // 4. 메인 화면에서 훈련 완료 알림을 받을 수 있도록 안내
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("훈련이 완료되면 새로운 제스처를 인식할 수 있습니다."),
        duration: Duration(seconds: 5),
      ),
    );
  }

  // 네이티브에 수집 중단을 알리는 내부 함수
  Future<void> _stopCollecting() async {
    try {
      await platform.invokeMethod('stopCollecting');
      print("Native call: Stopped collecting.");
    } on PlatformException catch (e) {
      print("Failed to call stopCollecting: '${e.message}'.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // 상단 헤더 (기존 UI 유지)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
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
                  Text(
                    '${widget.gestureName} 제스처 등록',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '프레임 안에 제스처를 취한 후, 등록 버튼을 누르세요.\n지시사항에 따라 등록을 완료하세요.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '프레임 안에 제스처를 취한 후, 등록 버튼을 누르세요.\n지시사항에 따라 등록을 완료하세요.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // 안내 텍스트 (기존 UI 유지)
            const Text(
              '📸 손을 카메라에 잘 보여주세요 🙌',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),

            // 진행률 표시 (상태와 연동)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  LinearProgressIndicator(
                    value: _progressPercent,
                    backgroundColor: Colors.grey.shade300,
                    color: Colors.indigo,
                    minHeight: 4,
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.center,
                    child: Text('${(_progressPercent * 100).toInt()}%'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 카메라 뷰 (기존 UI 유지)
            Expanded(
              child: Center(
                child: ClipOval(
                  child: Container(
                    width: 350,
                    height: 350,
                    color: Colors.black12,
                    child: const AndroidView(
                      viewType: 'hand_detection_view',
                      layoutDirection: TextDirection.ltr,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 30),

            // 하단 버튼 (상태와 연동)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _startOrRetakeRecording,
                      child: const Text('다시촬영'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isCompleted ? _saveGesture : null, // 수집 완료 시 활성화
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isCompleted ? Colors.indigo : Colors.grey.shade300,
                      ),
                      child: const Text('저장하기'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }
}