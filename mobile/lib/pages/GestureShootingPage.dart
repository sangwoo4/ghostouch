// import 'dart:io'; // Platform 체크를 위해 필요
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';

// class GestureShootingPage extends StatelessWidget {
//   const GestureShootingPage({super.key});

//   @override
//   Widget build(BuildContext context) {
//     // 상태바가 100% 차고 나면 get으로 api 불러와서 progress 실행 및 status 로그 받아오기
//     double progressPercent = 0.0; // 상태바

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

//             const Padding(
//               padding: EdgeInsets.symmetric(horizontal: 16),
//               child: Align(
//                 alignment: Alignment.centerLeft,
//                 child: Text(
//                   '프레임 안에 제스처를 취한 후, 등록 버튼을 누르세요.\n지시사항에 따라 등록을 완료하세요.',
//                   style: TextStyle(fontSize: 12, color: Colors.grey),
//                 ),
//               ),
//             ),
//             const SizedBox(height: 12),

//             // 안내 텍스트
//             const Text(
//               '📸 손을 카메라에 잘 보여주세요 🙌',
//               style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
//             ),
//             const SizedBox(height: 12),

//             // 진행률 표시
//             Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 32),
//               child: Column(
//                 children: [
//                   LinearProgressIndicator(
//                     value: progressPercent,
//                     backgroundColor: Colors.grey.shade300,
//                     color: Colors.indigo,
//                     minHeight: 4,
//                   ),
//                   const SizedBox(height: 4),
//                   Align(
//                     alignment: Alignment.center,
//                     child: Text('${(progressPercent * 100).toInt()}%'),
//                   ),
//                 ],
//               ),
//             ),
//             const SizedBox(height: 16),

//             // 카메라 뷰 (원형) - 플랫폼별 분기 처리
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
//               child: Row(
//                 children: [
//                   Expanded(
//                     child: OutlinedButton(
//                       onPressed: () {
//                         // 다시촬영 기능
//                       },
//                       child: const Text('다시촬영'),
//                     ),
//                   ),
//                   const SizedBox(width: 16),
//                   Expanded(
//                     child: ElevatedButton(
//                       onPressed: null, // 저장 비활성화 상태
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: Colors.grey.shade300,
//                       ),
//                       child: const Text('저장하기'),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//             const SizedBox(height: 50),
//           ],
//         ),
//       ),
//     );
//   }
// }

// get 호출 코드 및 상태바 메소드 함수 삽입
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class GestureShootingPage extends StatefulWidget {
  const GestureShootingPage({super.key});

  @override
  State<GestureShootingPage> createState() => _GestureShootingPageState();
}

class _GestureShootingPageState extends State<GestureShootingPage> {
  double progressPercent = 0.0; // 상태바
  String? taskId;
  String instructionText = '📸 손을 카메라에 잘 보여주세요 🙌';
  bool apiCalled = false; // GET API 중복 호출 방지

  static const taskIdChannel = MethodChannel('com.pentagon.gesture/task-id');

  @override
  void initState() {
    super.initState();
    _getTaskIdFromNative();
    _listenNativeProgress();
  }

  /// 네이티브에서 task_id 가져오기
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

  /// 네이티브에서 진행률 업데이트 수신
  void _listenNativeProgress() {
    taskIdChannel.setMethodCallHandler((call) async {
      if (call.method == 'updateProgress') {
        final double percent = (call.arguments ?? 0) / 100.0; // 0~100 → 0.0~1.0
        setState(() {
          progressPercent = percent;
        });

        // 100%가 되었을 때 API 호출
        if (percent >= 1.0 && !apiCalled) {
          apiCalled = true;
          _fetchCurrentStep();
        }
      }
    });
  }

  /// API 호출해서 current_step 가져오기
  Future<void> _fetchCurrentStep() async {
    if (taskId == null) return;
    try {
      final response = await http.get(
        Uri.parse("http://localhost:8000/status/$taskId"),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final currentStep = data["progress"]?["current_step"] ?? "";
        setState(() {
          instructionText = currentStep.isNotEmpty
              ? currentStep
              : '📸 손을 카메라에 잘 보여주세요 🙌';
        });
      } else {
        debugPrint("Failed to load status: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Error fetching status: $e");
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

            // 안내 텍스트 (current_step 반영)
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
                    value: progressPercent,
                    backgroundColor: Colors.grey.shade300,
                    color: Colors.indigo,
                    minHeight: 4,
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.center,
                    child: Text('${(progressPercent * 100).toInt()}%'),
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
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        // 다시촬영 기능
                      },
                      child: const Text('다시촬영'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: null, // 저장 비활성화 상태
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade300,
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
