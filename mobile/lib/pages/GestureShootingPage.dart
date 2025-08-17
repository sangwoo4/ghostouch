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
  // --- Gemini가 수정한 부분 시작 ---
  // UI 상태 관리를 위해 새로운 변수들을 추가했어.
  double _progressPercent = 0.0;
  bool _isStarted = false;
  bool _isCollecting = false;
  bool _isReadyToSave = false; // 100% 수집 완료되면 true가 돼서 저장하기 버튼이 활성화될 거야.
  bool _isUploading = false; // 저장하기 버튼 누르면 로딩 아이콘 보여주려고 만들었어.
  bool _isCompleted = false;
  String? taskId;
  String? serverUrl;
  // 초기 안내 문구도 살짝 바꿨어.
  String instructionText = ' ';
  // --- Gemini가 수정한 부분 끝 ---

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

  // --- Gemini가 수정한 부분 시작 ---
  // Swift에서 오는 신호들을 처리하는 부분이야.
  Future<void> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'updateProgress':
        final int progress = call.arguments as int;
        setState(() {
          _progressPercent = progress / 100.0;
        });
        break;

      // 100% 수집 완료 신호를 받으면, 저장할 준비가 됐다고 알려줘.
      case 'collectionComplete':
        setState(() {
          instructionText = '✅ 수집이 완료되었습니다. 저장 버튼을 눌러주세요.';
          _isCollecting = false;
          _isReadyToSave = true; // 이제 "저장하기" 버튼이 활성화될 거야.
          _progressPercent = 1.0;
        });
        break;

      // Swift에서 업로드 실패 신호를 보내면 여기서 처리해.
      case 'uploadFailed':
        final String errorMessage = call.arguments as String;
        setState(() {
          instructionText = '🚨 $errorMessage'; // 에러 메시지를 화면에 보여주고
          _isUploading = false; // 로딩 상태를 풀어서
          _isReadyToSave = true;  // 다시 저장 시도를 할 수 있게 해줘.
        });
        break;

      case 'modelDownloading':
        final Map<String, dynamic> args = Map<String, dynamic>.from(
          call.arguments,
        );
        final Map<String, dynamic>? progress = args['progress'];
        setState(() {
          instructionText = progress?['current_step'] ?? '모델 학습 중...';
        });
        break;

      // 최종 학습까지 완료되면, 완료 상태로 변경!
      case 'modelDownloadComplete':
        setState(() {
          instructionText = '🎉 모델 학습 완료! 이제 새 제스처를 사용할 수 있습니다.';
          _isUploading = false;
          _isCompleted = true;
        });
        break;

      default:
        debugPrint('Unknown method ${call.method}');
    }
  }

  // "촬영 시작" 또는 "다시촬영" 누르면 모든 상태를 깨끗하게 초기화해.
  Future<void> _startOrRetakeRecording() async {
    setState(() {
      _isStarted = true;
      _isCollecting = true;
      _isReadyToSave = false;
      _isUploading = false;
      _isCompleted = false;
      _progressPercent = 0.0;
      instructionText = '📸 손을 카메라에 잘 보여주세요 🙌';
    });

    try {
      await handDetectionChannel.invokeMethod('startCollecting', {
        'gestureName': widget.gestureName,
      });
      debugPrint("Native call: Started collecting for ${widget.gestureName}");
    } on PlatformException catch (e) {
      debugPrint("Failed to call startCollecting: '${e.message}'.");
      setState(() {
        _isCollecting = false;
      });
    }
  }

  // "저장하기" 버튼 누르면 호출될 새 함수야. Swift에 데이터 전송하라고 신호를 보내.
  Future<void> _uploadData() async {
    setState(() {
      _isReadyToSave = false;
      _isUploading = true;
      instructionText = '☁️ 서버로 데이터를 전송하고 학습을 시작합니다...';
    });
    try {
      await handDetectionChannel.invokeMethod('uploadData');
      debugPrint("Native call: uploadData successful.");
    } on PlatformException catch (e) {
      debugPrint("Failed to call uploadData: '${e.message}'.");
      setState(() {
        _isUploading = false;
        _isReadyToSave = true;
        instructionText = '오류: 전송에 실패했습니다. 다시 시도해주세요.';
      });
    }
  }
  // --- Gemini가 수정한 부분 끝 ---

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
    // if (taskId == null || serverUrl == null) return;
    //
    // // 1. 카메라 종료
    // await _stopCollecting();
    //
    // // 2. 서버 업로드/훈련 시작 안내
    // ScaffoldMessenger.of(context).showSnackBar(
    //   const SnackBar(
    //     content: Text("서버에 데이터를 업로드하고 모델 훈련을 시작합니다..."),
    //     duration: Duration(seconds: 3),
    //   ),
    // );
    // ScaffoldMessenger.of(context).showSnackBar(
    //   const SnackBar(
    //     content: Text("훈련이 완료되면 새로운 제스처를 인식할 수 있습니다."),
    //     duration: Duration(seconds: 5),
    //   ),
    // );
    //
    // // 3. 서버 상태 확인 (폴링)
    // bool completed = false;
    // while (!completed) {
    //   try {
    //     final response = await http.get(
    //       Uri.parse("$serverUrl/status/$taskId"),
    //     );
    //
    //     if (response.statusCode == 200) {
    //       final data = jsonDecode(response.body);
    //       final currentStep = data["progress"]?["current_step"] ?? "";
    //       final status = data["status"] ?? "";
    //
    //       debugPrint("Server response: ${response.body}");
    //       debugPrint("Fetched step: $currentStep, status: $status");
    //
    //       setState(() {
    //         instructionText = currentStep.isNotEmpty
    //             ? currentStep
    //             : '📸 손을 카메라에 잘 보여주세요 🙌';
    //       });
    //
    //       if (status.toString().toLowerCase() == "success") {
    //         // 4. 모델 다운로드 완료 → 저장 버튼 활성화
    //         setState(() {
    //           _isCompleted = true;
    //           _isCollecting = false;
    //         });
    //         completed = true;
    //       } else {
    //         await Future.delayed(const Duration(seconds: 2));
    //       }
    //     } else {
    //       debugPrint("Failed to load status: ${response.statusCode}");
    //       await Future.delayed(const Duration(seconds: 2));
    //     }
    //   } catch (e) {
    //     debugPrint("Error fetching status: $e");
    //     await Future.delayed(const Duration(seconds: 2));
    //   }
    // }
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
                  // --- Gemini가 수정한 부분 시작 ---
                  // 업로드 중에는 뒤로가기 막으려고 기능 추가
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () {
                      if (!_isUploading) {
                        Navigator.pop(context);
                      }
                    },
                  ),
                  // --- Gemini가 수정한 부분 끝 ---
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                instructionText,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
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
                    // --- Gemini가 수정한 부분 시작 ---
                    // 수집 중일 때만 카메라 보여주고, 아닐 땐 아이콘 보여주기
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
                        : Center(
                            child: Icon(
                            Icons.camera_alt,
                            color: Colors.grey.shade400,
                            size: 80,
                          )),
                    // --- Gemini가 수정한 부분 끝 ---
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
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _startOrRetakeRecording,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
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
                  // --- Gemini가 수정한 부분 시작 ---
                  // 버튼 UI 로직 전체를 상태에 따라 제어하도록 바꿨어.
                  : SizedBox(
                      height: 50,
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              // 업로드 중일 땐 "다시촬영" 못하게 막기
                              onPressed: _isUploading ? null : _startOrRetakeRecording,
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 50),
                              ),
                              child: const Text('다시촬영'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              // 최종 완료되면 홈으로, 저장 준비되면 업로드 함수 호출, 그 외엔 비활성화
                              onPressed: _isCompleted
                                  ? () => Navigator.pushReplacementNamed(context, '/')
                                  : (_isReadyToSave ? _uploadData : null),
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(0, 50),
                                // 저장 준비 완료 또는 최종 완료 상태일 때만 활성화 색상 보여주기
                                backgroundColor: (_isReadyToSave || _isCompleted)
                                    ? Colors.indigo
                                    : Colors.grey.shade300,
                                foregroundColor: Colors.white,
                              ),
                              // 업로드 중이면 로딩 아이콘, 아니면 상태에 따라 텍스트 보여주기
                              child: _isUploading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(_isCompleted ? '완료' : '저장하기'),
                            ),
                          ),
                        ],
                      ),
                    ),
              // --- Gemini가 수정한 부분 끝 ---
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }
}