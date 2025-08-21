import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ghostouch/main.dart';
import 'package:ghostouch/services/native_channel_service.dart';
import 'package:ghostouch/services/api_service.dart';
import 'package:lottie/lottie.dart';
import 'package:ghostouch/widgets/header.dart';

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
  bool _isDownloading = false;
  bool _isCompleted = false;
  bool _isRetaked = true;
  bool _showSuccess = false; // 로딩 완료
  String? taskId;
  String? serverUrl;
  String instructionText = ' ';

  @override
  void initState() {
    super.initState();
    _getTaskIdFromNative();
    // _getServerUrl();
    _initServerUrl();
    NativeChannelService.handDetectionChannel.setMethodCallHandler(
      _handleMethodCall,
    );
  }

  Future<void> _getTaskIdFromNative() async {
    try {
      final String result = await NativeChannelService.taskIdChannel
          .invokeMethod('getTaskId');
      setState(() {
        taskId = result;
      });
    } on PlatformException catch (e) {
      debugPrint("Failed to get task_id: ${e.message}");
    }
  }

  /// 서버 URL 초기화
  Future<void> _initServerUrl() async {
    final url = await ApiService.getServerUrl();
    setState(() {
      serverUrl = url;
    });
    debugPrint("Server URL: $serverUrl");
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
          _isRetaked = true;
        });
        break;

      // ios용 제스처 수집 시작
      case 'updateProgress':
        final int progress = call.arguments as int;
        setState(() {
          instructionText = '📸 손을 카메라에 잘 보여주세요 🙌';
          _progressPercent = progress / 100.0;
          _isRetaked = true;
        });
        break;

      // 상태바 업데이트 완료 함수
      case 'collectionComplete':
        setState(() {
          _isCollecting = false;
          _isRetaked = false;
          _isDownloading = true; // 로딩 애니메이션 ON
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
          _isRetaked = false; // 다시 촬영 플래그 OFF
          _isDownloading = true; // 로딩 애니메이션 ON
        });
        break;

      // 모델 학습 및 다운로드 완료 함수
      case 'modelDownloadComplete':
        setState(() {
          instructionText = '모델 학습 완료!';
          _isCollecting = false; // 카메라 OFF
          _isRetaked = false; // 다시 촬영 플래그 OFF
          _isCompleted = true; // 저장하기 버튼 활성화
          _isDownloading = false; // 로딩 애니메이션 OFF
          _showSuccess = true; //  로딩 성공 오버레이 켜기
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
        // 서버 URL이 준비되었으면 폴링 시작
        _startPolling();
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
      _isRetaked = false;
      _progressPercent = 0.0;
    });

    try {
      debugPrint(
        "About to call handDetectionChannel.invokeMethod with gesture: ${widget.gestureName}",
      );
      await NativeChannelService.handDetectionChannel.invokeMethod(
        'startCollecting',
        {'gestureName': widget.gestureName},
      );
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
      await NativeChannelService.handDetectionChannel.invokeMethod(
        'stopCollecting',
      );
      debugPrint("Native call: Stopped collecting.");
    } on PlatformException catch (e) {
      debugPrint("Failed to call stopCollecting: '${e.message}'.");
    }
  }

  // 제스처 수집 완료 후 서버 상태 확인 + 모델 다운로드 처리
  Future<void> _startPolling() async {
    if (taskId == null || serverUrl == null) return;

    await ApiService.handleGestureCompletion(
      taskId: taskId!,
      serverUrl: serverUrl!,
      onProgress: (step) {
        setState(() {
          instructionText = step;
        });
      },
      onSuccess: () {
        setState(() {
          _isCompleted = true;
          _isCollecting = false;
          _isRetaked = false;
          instructionText = '제스처 저장 완료!';
          _isDownloading = false; // 로딩은 끄고
          _showSuccess = true; // 성공 오버레이 켜기
        });
      },
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
          children: [
            HeaderWidget(
              title: '사용자 제스처 등록',
              description:
                  '프레임 안에 제스처를 취한 후, 등록 버튼을 누르세요.\n지시사항에 따라 등록을 완료하세요.',
              isMain: false, // 메인 헤더 스타일
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
            const SizedBox(height: 10),

            Expanded(
              child: Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // 카메라 영역 (로딩/성공일 때는 아예 안 보이게)
                    if (!_isDownloading && !_showSuccess)
                      ClipOval(
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
                                        creationParamsCodec:
                                            StandardMessageCodec(),
                                      ))
                              : const SizedBox(),
                        ),
                      ),

                    // 로딩 애니메이션
                    if (_isDownloading && !_isCompleted)
                      Lottie.asset(
                        'assets/anim/Loading 40 _ Paperplane.json',
                        width: 400,
                        height: 400,
                      ),

                    // 성공 애니메이션
                    if (_showSuccess)
                      IgnorePointer(
                        ignoring: true,
                        child: ClipOval(
                          child: SizedBox(
                            width: 250,
                            height: 250,
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 220),
                              opacity: _showSuccess ? 1 : 0,
                              child: Lottie.asset(
                                'assets/anim/Success Send.json',
                                repeat: false,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 하단 버튼
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
              child: !_isStarted
                  ? SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          debugPrint("제스처 촬영 시작 버튼이 눌렸습니다!");
                          _startOrRetakeRecording();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isCompleted
                              ? const Color.fromARGB(255, 0, 0, 0)
                              : const Color.fromARGB(255, 156, 168, 240),
                          padding: const EdgeInsets.symmetric(vertical: 18),
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
                            onPressed: _isRetaked
                                ? () {
                                    debugPrint("다시촬영 버튼이 눌렸습니다!");
                                    _startOrRetakeRecording();
                                  }
                                : null,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 18),
                            ),
                            child: const Text('다시촬영'),
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isCompleted
                                ? () {
                                    debugPrint(
                                      "저장하기 버튼이 눌렸습니다! 제스처: ${widget.gestureName}",
                                    );
                                    Navigator.pushAndRemoveUntil(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const MainPage(),
                                      ),
                                      (route) => false, // 모든 이전 라우트 제거
                                    );
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isCompleted
                                  ? const Color.fromARGB(255, 156, 168, 240)
                                  : const Color.fromARGB(255, 0, 0, 0),
                              padding: const EdgeInsets.symmetric(vertical: 18),
                            ),
                            child: const Text('저장하기'),
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }
}
