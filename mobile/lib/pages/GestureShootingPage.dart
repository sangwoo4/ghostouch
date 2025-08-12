import 'dart:io'; // Platform 체크를 위해 필요
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class GestureShootingPage extends StatelessWidget {
  const GestureShootingPage({super.key});

  @override
  Widget build(BuildContext context) {
    // 상태바가 100% 차고 나면 get으로 api 불러와서 progress 실행 및 status 로그 받아오기
    double progressPercent = 0.0; // 상태바

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

            // 안내 텍스트
            const Text(
              '📸 손을 카메라에 잘 보여주세요 🙌',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
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

            // 카메라 뷰 (원형) - 플랫폼별 분기 처리
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
