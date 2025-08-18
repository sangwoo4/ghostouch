import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class GestureShootingPage extends StatefulWidget {
  final String gestureName;

  const GestureShootingPage({super.key, required this.gestureName});

  @override
  State<GestureShootingPage> createState() => _GestureShootingPageState();
}

class _GestureShootingPageState extends State<GestureShootingPage> {
  double _progressPercent = 0.0;
  bool _isStarted = false;
  bool _isCollecting = false;
  bool _isCompleted = false;
  String? taskId;
  String? serverUrl;
  String instructionText = '📸 손을 카메라에 잘 보여주세요 🙌';

  static const toggleChannel = MethodChannel('com.pentagon.ghostouch/toggle');
  static const taskIdChannel = MethodChannel('com.pentagon.gesture/task-id');
  static const handDetectionChannel = MethodChannel(
    'com.pentagon.ghostouch/hand_detection',
  );

  @override
  void initState() {
    super.initState();
    _getTaskIdFromNative();
    _getServerUrl();
    handDetectionChannel.setMethodCallHandler(_handleMethodCall);
  }

  Future<void> _getTaskIdFromNative() async {
    try {
      final String result = await taskIdChannel.invokeMethod('getTaskId');
      setState(() {
        taskId = result;
      });
    } on PlatformException catch (e) {
      debugPrint("Failed to get task_id: ${e.message}");
    }
  }

  Future<void> _getServerUrl() async {
    try {
      final String result = await toggleChannel.invokeMethod('getServerUrl');
      setState(() {
        serverUrl = result;
      });
      debugPrint("Server URL: $serverUrl");
    } on PlatformException catch (e) {
      debugPrint("Failed to get server URL: ${e.message}");
      // 폴백 URL 설정
      setState(() {
        serverUrl = "http://localhost:8000";
      });
    }
  }

  @override
  void dispose() {
    if (_isCollecting) {
      _stopCollecting();
    }
    super.dispose();
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      // android용 제스처 수집 시작
      case 'collectionStarted':
        setState(() {
          instructionText = '📸 손을 카메라에 잘 보여주세요 🙌';
          _progressPercent = 0.0;
        });
        break;

      // ios용 제스처 수집 시작
      case 'updateProgress':
        final int progress = call.arguments as int;
        setState(() {
          instructionText = '📸 손을 카메라에 잘 보여주세요 🙌';
          _progressPercent = progress / 100.0;
        });
        break;

      // 상태바 업데이트 완료 함수
      case 'collectionComplete':
        setState(() {
          _isCollecting = false;
          _progressPercent = 1.0; // 상태바 100%
          instructionText = '서버에 업로드 중...';
        });
        break;

      // 모델 학습중 함수
      case 'modelDownloading':
        final Map<String, dynamic> args = Map<String, dynamic>.from(
          call.arguments,
        );
        final Map<String, dynamic>? progress = args['progress'];
        setState(() {
          instructionText = progress?['current_step'] ?? '모델 학습 중...';
          _isCollecting = false; // 카메라 OFF
        });
        break;

      // 모델 학습 및 다운로드 완료 함수
      case 'modelDownloadComplete':
        setState(() {
          instructionText = '모델 학습 완료!';
          _isCollecting = false; // 카메라 OFF
          _isCompleted = true; // 저장하기 버튼 활성화
        });
        break;

      // Task ID가 준비되었을 때 폴링 시작
      case 'taskIdReady':
        final Map<String, dynamic> args = Map<String, dynamic>.from(
          call.arguments,
        );
        final String receivedTaskId = args['taskId'] ?? '';
        debugPrint('Task ID received: $receivedTaskId');
        setState(() {
          taskId = receivedTaskId;
          instructionText = '모델 학습 중...';
        });
        // 이제 올바른 task_id로 폴링 시작
        _handleGestureCompletion();
        break;

      default:
        debugPrint('Unknown method ${call.method}');
    }
  }

  Future<void> _startOrRetakeRecording() async {
    debugPrint(
      "_startOrRetakeRecording called for gesture: ${widget.gestureName}",
    );

    setState(() {
      _isStarted = true;
      _isCollecting = true;
      _isCompleted = false;
      _progressPercent = 0.0;
    });

    try {
      debugPrint(
        "About to call handDetectionChannel.invokeMethod with gesture: ${widget.gestureName}",
      );
      await handDetectionChannel.invokeMethod('startCollecting', {
        'gestureName': widget.gestureName,
      });
      debugPrint("Native call: Started collecting for ${widget.gestureName}");
    } on PlatformException catch (e) {
      debugPrint("Failed to call startCollecting: '${e.message}'.");
      setState(() {
        _isCollecting = false;
      });
    } catch (e) {
      debugPrint("Unexpected error calling startCollecting: $e");
      setState(() {
        _isCollecting = false;
      });
    }
  }

  Future<void> _stopCollecting() async {
    try {
      await handDetectionChannel.invokeMethod('stopCollecting');
      debugPrint("Native call: Stopped collecting.");
    } on PlatformException catch (e) {
      debugPrint("Failed to call stopCollecting: '${e.message}'.");
    }
  }

  // 제스처 수집 완료 후 서버 상태 확인 + 모델 다운로드 처리
  Future<void> _handleGestureCompletion() async {
    if (taskId == null || serverUrl == null) return;

    // 서버 상태 확인 (폴링)
    bool completed = false;
    while (!completed) {
      try {
        final response = await http.get(Uri.parse("$serverUrl/status/$taskId"));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final currentStep = data["progress"]?["current_step"] ?? "";
          final status = data["status"] ?? "";

          debugPrint("Server response: ${response.body}");
          debugPrint("Fetched step: $currentStep, status: $status");

          setState(() {
            instructionText = currentStep.isNotEmpty
                ? currentStep
                : '📸 손을 카메라에 잘 보여주세요 🙌';
          });

          if (status.toString().toLowerCase() == "success") {
            // 4. 모델 다운로드 완료 → 저장 버튼 활성화
            setState(() {
              _isCompleted = true;
              _isCollecting = false;
            });
            completed = true;
          } else {
            await Future.delayed(const Duration(seconds: 2));
          }
        } else {
          debugPrint("Failed to load status: ${response.statusCode}");
          await Future.delayed(const Duration(seconds: 2));
        }
      } catch (e) {
        debugPrint("Error fetching status: $e");
        await Future.delayed(const Duration(seconds: 2));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // 상단 헤더
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
                  const Text(
                    '사용자 제스처 등록',
                    style: TextStyle(
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

            // 안내 텍스트
            Text(
              instructionText,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),

            // 진행률 표시
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

            // 카메라 뷰 (원형)
            Expanded(
              child: Center(
                child: ClipOval(
                  child: Container(
                    width: 350,
                    height: 350,
                    color: Colors.black12,
                    child: _isCollecting
                        ? (Platform.isAndroid
                              ? const AndroidView(
                                  viewType: 'hand_detection_view',
                                  layoutDirection: TextDirection.ltr,
                                )
                              : const UiKitView(
                                  viewType: 'camera_view',
                                  creationParamsCodec: StandardMessageCodec(),
                                ))
                        : const SizedBox(), // _isCollecting = false면 카메라 OFF
                  ),
                ),
              ),
            ),

            const SizedBox(height: 30),

            // 하단 버튼
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: !_isStarted
                  ? SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          debugPrint("제스처 촬영 시작 버튼이 눌렸습니다!");
                          _startOrRetakeRecording();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text(
                          '제스처 촬영 시작',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              debugPrint("다시촬영 버튼이 눌렸습니다!");
                              _startOrRetakeRecording();
                            },
                            child: const Text('다시촬영'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isCompleted
                                ? () {
                                    debugPrint(
                                      "저장하기 버튼이 눌렸습니다! 제스처: ${widget.gestureName}",
                                    );
                                    Navigator.pushReplacementNamed(
                                      context,
                                      '/',
                                    );
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isCompleted
                                  ? Colors.indigo
                                  : Colors.grey.shade300,
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
