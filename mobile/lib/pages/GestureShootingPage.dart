// // get 호출 코드 및 상태바 메소드 함수 삽입
// import 'dart:convert';
// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:http/http.dart' as http;

// class GestureShootingPage extends StatefulWidget {
//   // GestureRegisterPage로부터 제스처 이름을 전달받기 위해 final로 선언
//   final String gestureName;

//   const GestureShootingPage({super.key, required this.gestureName});

//   @override
//   State<GestureShootingPage> createState() => _GestureShootingPageState();
// }

// class _GestureShootingPageState extends State<GestureShootingPage> {
//   double _progressPercent = 0.0; // 상태바
//   bool _isStarted = false; // add
//   bool _isCollecting = false; // add
//   bool _isCompleted = false; // add
//   String? taskId;
//   String instructionText = '📸 손을 카메라에 잘 보여주세요 🙌';
//   bool apiCalled = false; // GET API 중복 호출 방지

//   static const taskIdChannel = MethodChannel('com.pentagon.gesture/task-id');
//   static const handDetectionChannel = MethodChannel(
//     'com.pentagon.ghostouch/hand_detection',
//   );

//   @override
//   void initState() {
//     super.initState();
//     _getTaskIdFromNative();
//     // _listenNativeProgress();
//     // 네이티브에서 오는 호출을 수신할 핸들러 설정
//     handDetectionChannel.setMethodCallHandler(_handleMethodCall);
//   }

//   /// 네이티브에서 task_id 가져오기
//   Future<void> _getTaskIdFromNative() async {
//     try {
//       final String result = await taskIdChannel.invokeMethod('getTaskId');
//       setState(() {
//         taskId = result;
//       });
//     } on PlatformException catch (e) {
//       debugPrint("Failed to get task_id: ${e.message}");
//     }
//   }

//   @override
//   void dispose() {
//     // 화면이 사라질 때, 만약 수집 중이었다면 중단 신호를 보냄
//     if (_isCollecting) {
//       _stopCollecting();
//     }
//     super.dispose();
//   }

//   // 네이티브로부터 오는 메소드 호출을 처리
//   Future<void> _handleMethodCall(MethodCall call) async {
//     switch (call.method) {
//       case 'updateProgress':
//         final int progress = call.arguments as int;
//         setState(() {
//           _progressPercent = progress / 100.0;
//         });
//         break;
//       case 'collectionComplete':
//         setState(() {
//           _isCollecting = false;
//           _isCompleted = true; // ✅ 저장 버튼 활성화
//           _progressPercent = 1.0;
//         });
//         _fetchCurrentStep(); // 서버 current_step만 업데이트
//         break;

//       default:
//         print('Unknown method ${call.method}');
//     }
//   }

//   // "제스처 촬영 시작" 버튼을 눌렀을 때 호출
//   Future<void> _startOrRetakeRecording() async {
//     setState(() {
//       _isStarted = true; // 버튼 한 번만 나타나도록
//       _isCollecting = true;
//       _isCompleted = false;
//       _progressPercent = 0.0;
//     });

//     try {
//       await handDetectionChannel.invokeMethod('startCollecting', {
//         'gestureName': widget.gestureName,
//       });
//       print("Native call: Started collecting for ${widget.gestureName}");
//     } on PlatformException catch (e) {
//       print("Failed to call startCollecting: '${e.message}'.");
//       setState(() {
//         _isCollecting = false;
//       });
//     }
//   }

//   // 네이티브에 수집 중단을 알리는 내부 함수
//   Future<void> _stopCollecting() async {
//     try {
//       await handDetectionChannel.invokeMethod('stopCollecting');
//       print("Native call: Stopped collecting.");
//     } on PlatformException catch (e) {
//       print("Failed to call stopCollecting: '${e.message}'.");
//     }
//   }

//   // 제스처 수집이 완료되면 자동으로 API 호출해서 current_step 가져오기
//   // 카메라 off 및 api status가 success면 저장하기 버튼 활성화
//   Future<void> _fetchCurrentStep() async {
//     if (taskId == null) return;

//     // 1. 네이티브에 수집 중단 신호 전송 및 서버 업로드 시작
//     await _stopCollecting();

//     // 2. 훈련 시작 안내
//     ScaffoldMessenger.of(context).showSnackBar(
//       const SnackBar(
//         content: Text("서버에 데이터를 업로드하고 모델 훈련을 시작합니다..."),
//         duration: Duration(seconds: 3),
//       ),
//     );

//     try {
//       // 3. 서버 상태 조회
//       final response = await http.get(
//         Uri.parse("http://172.30.1.88:8000/status/$taskId"),
//       );

//       if (response.statusCode == 200) {
//         final data = jsonDecode(response.body);

//         final currentStep = data["progress"]?["current_step"] ?? "";
//         final status = data["status"] ?? "";

//         setState(() {
//           instructionText = currentStep.isNotEmpty
//               ? currentStep
//               : '📸 손을 카메라에 잘 보여주세요 🙌';

//           if (status.toString().toLowerCase() == "success") {
//             _isCompleted = true; // 저장 버튼 활성화
//             _isCollecting = false; // 촬영 상태 종료
//           }
//         });
//       } else {
//         debugPrint("Failed to load status: ${response.statusCode}");
//       }
//     } catch (e) {
//       debugPrint("Error fetching status: $e");
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.white,
//       body: SafeArea(
//         child: Column(
//           children: [
//             // 상단 헤더
//             Container(
//               width: double.infinity,
//               padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
//               decoration: const BoxDecoration(
//                 color: Color(0xFF0E1539),
//                 borderRadius: BorderRadius.vertical(
//                   bottom: Radius.circular(30),
//                 ),
//               ),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   IconButton(
//                     icon: const Icon(Icons.arrow_back, color: Colors.white),
//                     onPressed: () => Navigator.pop(context),
//                   ),
//                   const SizedBox(height: 10),
//                   const Text(
//                     '사용자 제스처 등록',
//                     style: TextStyle(
//                       fontSize: 20,
//                       fontWeight: FontWeight.bold,
//                       color: Colors.white,
//                     ),
//                   ),
//                   const SizedBox(height: 4),
//                   const Text(
//                     '프레임 안에 제스처를 취한 후, 등록 버튼을 누르세요.\n지시사항에 따라 등록을 완료하세요.',
//                     style: TextStyle(
//                       fontSize: 12,
//                       color: Colors.white70,
//                       height: 1.4,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//             const SizedBox(height: 20),

//             // 안내 텍스트 (current_step 반영)
//             Text(
//               instructionText,
//               style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
//             ),
//             const SizedBox(height: 12),

//             // 진행률 표시
//             Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 32),
//               child: Column(
//                 children: [
//                   LinearProgressIndicator(
//                     value: _progressPercent,
//                     backgroundColor: Colors.grey.shade300,
//                     color: Colors.indigo,
//                     minHeight: 4,
//                   ),
//                   const SizedBox(height: 4),
//                   Align(
//                     alignment: Alignment.center,
//                     child: Text('${(_progressPercent * 100).toInt()}%'),
//                   ),
//                 ],
//               ),
//             ),
//             const SizedBox(height: 16),

//             // 카메라 뷰 (원형)
//             Expanded(
//               child: Center(
//                 child: ClipOval(
//                   child: Container(
//                     width: 350,
//                     height: 350,
//                     color: Colors.black12,
//                     child: Platform.isAndroid
//                         ? const AndroidView(
//                             viewType: 'hand_detection_view',
//                             layoutDirection: TextDirection.ltr,
//                           )
//                         : const UiKitView(
//                             viewType: 'camera_view',
//                             creationParamsCodec: StandardMessageCodec(),
//                           ),
//                   ),
//                 ),
//               ),
//             ),

//             const SizedBox(height: 30),

//             // 하단 버튼
//             Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 20),
//               child: !_isStarted
//                   // 1️⃣ 초기 상태 → 제스처 촬영 시작 버튼 (한 번만)
//                   ? SizedBox(
//                       width: double.infinity,
//                       child: ElevatedButton(
//                         onPressed: _startOrRetakeRecording,
//                         style: ElevatedButton.styleFrom(
//                           backgroundColor: Colors.indigo,
//                           padding: const EdgeInsets.symmetric(vertical: 16),
//                         ),
//                         child: const Text(
//                           '제스처 촬영 시작',
//                           style: TextStyle(
//                             fontSize: 16,
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                       ),
//                     )
//                   // 2️⃣ 촬영 중 또는 완료 상태 → 다시촬영 + 저장하기 버튼
//                   : Row(
//                       children: [
//                         Expanded(
//                           child: OutlinedButton(
//                             onPressed: () {
//                               _startOrRetakeRecording();
//                             },
//                             child: const Text('다시촬영'),
//                           ),
//                         ),
//                         const SizedBox(width: 16),
//                         Expanded(
//                           child: ElevatedButton(
//                             onPressed: _isCompleted
//                                 ? () {
//                                     // 저장 로직
//                                   }
//                                 : null, // 촬영 완료 전에는 비활성화
//                             style: ElevatedButton.styleFrom(
//                               backgroundColor: _isCompleted
//                                   ? Colors.indigo
//                                   : Colors.grey.shade300,
//                             ),
//                             child: const Text('저장하기'),
//                           ),
//                         ),
//                       ],
//                     ),
//             ),

//             const SizedBox(height: 50),
//           ],
//         ),
//       ),
//     );
//   }
// }

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
  String instructionText = '📸 손을 카메라에 잘 보여주세요 🙌';

  static const taskIdChannel = MethodChannel('com.pentagon.gesture/task-id');
  static const handDetectionChannel = MethodChannel(
    'com.pentagon.ghostouch/hand_detection',
  );

  @override
  void initState() {
    super.initState();
    _getTaskIdFromNative();
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

  @override
  void dispose() {
    if (_isCollecting) {
      _stopCollecting();
    }
    super.dispose();
  }

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
          _progressPercent = 1.0; // 상태바 100%
        });
        // 수집 완료 처리 및 서버 업로드/모델 다운로드 시작
        _handleGestureCompletion();
        break;

      default:
        debugPrint('Unknown method ${call.method}');
    }
  }

  Future<void> _startOrRetakeRecording() async {
    setState(() {
      _isStarted = true;
      _isCollecting = true;
      _isCompleted = false;
      _progressPercent = 0.0;
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
    if (taskId == null) return;

    // 1. 카메라 종료
    await _stopCollecting();

    // 2. 서버 업로드/훈련 시작 안내
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("서버에 데이터를 업로드하고 모델 훈련을 시작합니다..."),
        duration: Duration(seconds: 3),
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("훈련이 완료되면 새로운 제스처를 인식할 수 있습니다."),
        duration: Duration(seconds: 5),
      ),
    );

    // 3. 서버 상태 확인 (폴링)
    bool completed = false;
    while (!completed) {
      try {
        final response = await http.get(
          Uri.parse("http://172.30.1.88:8000/status/$taskId"),
        );

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
                    child: Platform.isAndroid
                        ? const AndroidView(
                            viewType: 'hand_detection_view',
                            layoutDirection: TextDirection.ltr,
                          )
                        : const UiKitView(
                            viewType: 'camera_view',
                            creationParamsCodec: StandardMessageCodec(),
                          ),
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
                        onPressed: _startOrRetakeRecording,
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
                            onPressed: _startOrRetakeRecording,
                            child: const Text('다시촬영'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isCompleted
                                ? () {
                                    // 저장 로직
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
