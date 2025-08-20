import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../pages/GestureShootingPage.dart';

class CustomDialogs {
  // 메인화면 토글 다이얼로그
  static Future<bool?> showToggleDialog(
    BuildContext context,
    MethodChannel toggleChannel,
  ) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
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
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(false),
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
                            Navigator.of(dialogContext).pop(true);
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

  // 제스처 등록 화면 카메라 인식 사용법 다이얼로그
  static Future<bool?> showCameraDialog(
    BuildContext parentContext,
    MethodChannel cameraChannel,
    TextEditingController controller,
  ) {
    return showDialog<bool>(
      context: parentContext,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
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
                const Icon(Icons.camera, size: 40, color: Colors.orange),
                const SizedBox(height: 12),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    '💡 빛 반사가 없는 곳에서 진행해주세요.\n'
                    '✋ 프레임 가운데 손이 위치하도록 해주세요.\n'
                    '📸 촬영 중 움직이면 정확도가 떨어질 수 있습니다.\n'
                    '📶 네트워크를 연결했는지 확인해주세요.\n',
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
                            Navigator.of(dialogContext).pop(false);
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
                            Navigator.of(dialogContext).pop(true); // ✅ true만 반환
                          },
                          child: const Text(
                            '촬영하기',
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

  // 초기화 경고 다이얼로그
  static Future<bool?> showResetDialog(
    BuildContext context,
    MethodChannel resetChannel,
  ) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
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
                const Icon(Icons.warning, size: 40, color: Colors.redAccent),
                const SizedBox(height: 12),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    "⚠️ 정말로 초기화하시겠습니까?\n\n"
                    "❌ 기본을 제외한 모든 제스처들이 삭제됩니다.\n\n"
                    "🚫 초기화 시 복구할 수 없습니다! 🔥",
                    style: TextStyle(
                      fontSize: 13,
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
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(false),
                          child: const Text('취소'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () async {
                            Navigator.of(dialogContext).pop(true);
                            try {
                              await resetChannel.invokeMethod('reset');
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('✅ 제스처가 초기화되었습니다.'),
                                  ),
                                );
                                Navigator.of(context).pushNamedAndRemoveUntil(
                                  '/',
                                  (route) => false,
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('초기화 실패: $e')),
                                );
                              }
                            }
                          },
                          child: const Text('초기화'),
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
}
