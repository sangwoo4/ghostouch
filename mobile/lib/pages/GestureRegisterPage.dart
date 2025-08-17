import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'GestureShootingPage.dart';

class GestureRegisterPage extends StatefulWidget {
  const GestureRegisterPage({super.key});

  @override
  State<GestureRegisterPage> createState() => _GestureRegisterPageState();
}

class _GestureRegisterPageState extends State<GestureRegisterPage> {
  final TextEditingController _controller = TextEditingController();
  bool _isDuplicateChecked = false;
  bool _isNameValid = false;
  String _errorMessage = '';

  static const cameraChannel = MethodChannel('com.pentagon.ghostouch/camera');
  static const resetChannel = MethodChannel(
    'com.pentagon.ghostouch/reset-gesture',
  );
  static const listChannel = MethodChannel(
    'com.pentagon.ghostouch/list-gesture',
  );
  // static const registerNameChannel = MethodChannel(
  //   'com.pentagon.ghostouch/register-name',
  // );

  List<String> registeredGestures = ['가위 제스처', '주먹 제스처', '보 제스처', '한성대 제스처'];

  @override
  void initState() {
    super.initState();
    _loadGestureList();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 페이지가 다시 보일 때마다 제스처 목록 새로고침
    if (mounted) {
      _loadGestureList();
    }
  }

  Future<void> _loadGestureList() async {
    try {
      final List<dynamic> gestures = await listChannel.invokeMethod(
        'list-gesture',
      );
      setState(() {
        registeredGestures = gestures.cast<String>();
      });
    } catch (e) {
      debugPrint("⚠ 제스처 목록 불러오기 실패: $e");
    }
  }

  // 다이얼로그 표시 함수
  Future<bool?> _showCameraDialog(BuildContext parentContext) {
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
                            // try {
                            //   // ✅ 제스처 이름 네이티브로 전달
                            //   await registerNameChannel.invokeMethod(
                            //     'register-name',
                            //     {"name": _controller.text},
                            //   );
                            //   print("✅ 제스처 이름 전달 완료: ${_controller.text}");
                            // } on PlatformException catch (e) {
                            //   print("❌ register-name 호출 실패: ${e.message}");
                            // }

                            Navigator.of(context).pop(); // 먼저 다이얼로그를 닫고
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => GestureShootingPage(
                                  gestureName: _controller.text,
                                ),
                              ),
                            );

                            try {
                              await cameraChannel.invokeMethod('openSettings');

                              if (parentContext.mounted) {
                                Navigator.push(
                                  parentContext,
                                  MaterialPageRoute(
                                    builder: (context) => GestureShootingPage(
                                      gestureName: _controller.text,
                                    ),
                                  ),
                                );
                              }
                            } on PlatformException catch (e) {
                              print("❌ openSettings 호출 실패: ${e.message}");
                            }
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

  void _checkDuplicate() {
    String input = _controller.text.trim();

    if (input.isEmpty) {
      setState(() {
        _isNameValid = false;
        _isDuplicateChecked = false;
        _errorMessage = '공백은 등록할 수 없습니다.';
      });
      return;
    }

    bool isDuplicate = registeredGestures.contains(input);

    setState(() {
      _isNameValid = !isDuplicate;
      _isDuplicateChecked = true;
      _errorMessage = isDuplicate
          ? '이미 등록된 이름입니다.'
          : '등록할 수 있는 이름입니다. [제스처 촬영]을 눌러 촬영을 시작해주세요';
    });
  }

  Future<void> _startCamera() async {
    try {
      await cameraChannel.invokeMethod('startCamera');
      print('📷 네이티브 카메라 호출 완료');
    } on PlatformException catch (e) {
      print("❌ 카메라 호출 실패: '${e.message}'.");
    }
  }

  Future<void> _resetGesture() async {
    try {
      await resetChannel.invokeMethod('reset');
      print('🔄 제스처 초기화 완료');
      // 제스처 목록 새로고침
      await _loadGestureList();
      // 필요 시 사용자에게 알림 표시
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('제스처가 초기화되었습니다.')));
      }
    } on PlatformException catch (e) {
      print('❌ 제스처 초기화 실패: ${e.message}');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('초기화 실패: ${e.message}')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final inputValidAndChecked = _isDuplicateChecked && _isNameValid;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.white,
      body: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom, // 키보드 높이만큼 여백
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 상단 헤더
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 30,
                      vertical: 30,
                    ),
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
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                          ),
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
                          '새롭게 등록할 제스처의 이름을 설정해주세요.',
                          style: TextStyle(fontSize: 12, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 입력 + 중복검사
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            decoration: const InputDecoration(
                              hintText: '제스처 이름을 적어주세요...',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (_) {
                              setState(() {
                                _isDuplicateChecked = false;
                                _isNameValid = false;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          children: [
                            Icon(
                              _isDuplicateChecked
                                  ? (_isNameValid
                                        ? Icons.check_circle
                                        : Icons.cancel)
                                  : Icons.help_outline,
                              color: _isDuplicateChecked
                                  ? (_isNameValid ? Colors.green : Colors.red)
                                  : Colors.grey,
                            ),
                            TextButton(
                              onPressed: _checkDuplicate,
                              child: const Text('중복검사'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      _errorMessage,
                      style: TextStyle(
                        fontSize: 12,
                        color: _isNameValid ? Colors.orange : Colors.redAccent,
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),
                  // 제스처 촬영 버튼
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: inputValidAndChecked
                            ? () async {
                                final shouldStart = await _showCameraDialog(
                                  context,
                                );
                                if (shouldStart == true) {
                                  _startCamera();
                                }
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.black,
                          backgroundColor: inputValidAndChecked
                              ? Colors.white
                              : Colors.grey.shade300,
                          side: const BorderSide(color: Colors.black),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('제스처 촬영'),
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      '등록된 제스처 목록',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: registeredGestures.length,
                    itemBuilder: (context, index) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          border: Border.all(color: Colors.black26),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(registeredGestures[index]),
                      );
                    },
                  ),

                  const SizedBox(height: 20),
                  // 제스처 초기화 버튼
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _resetGesture,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[400],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('제스처 초기화'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}