import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ghostouch/widgets/dialogs.dart';
import 'GestureShootingPage.dart';
import 'package:ghostouch/services/native_channel_service.dart';
import 'package:ghostouch/widgets/header.dart';

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
      final List<dynamic> gestures = await NativeChannelService.listChannel
          .invokeMethod('list-gesture');
      setState(() {
        registeredGestures = gestures.cast<String>();
      });
    } catch (e) {
      debugPrint("⚠ 제스처 목록 불러오기 실패: $e");
    }
  }

  Future<void> _checkDuplicate() async {
    String input = _controller.text;

    try {
      // 네이티브에서 모든 검증 수행 (공백, 중복검사)
      final Map<dynamic, dynamic> result = await NativeChannelService
          .listChannel
          .invokeMethod('check-duplicate', {'gestureName': input});

      final bool isDuplicate = result['isDuplicate'] ?? false;
      final String message = result['message'] ?? '';

      setState(() {
        _isNameValid = !isDuplicate;
        _isDuplicateChecked = true;
        _errorMessage = isDuplicate
            ? message
            : '$message [제스처 촬영]을 눌러 촬영을 시작해주세요';
      });
    } catch (e) {
      debugPrint("⚠ 중복 검사 실패: $e");
      // 폴백: 로컬에서 기본 검사
      String trimmedInput = input.trim();
      if (trimmedInput.isEmpty) {
        setState(() {
          _isNameValid = false;
          _isDuplicateChecked = true;
          _errorMessage = '공백은 등록할 수 없습니다.';
        });
        return;
      }

      bool isDuplicate = registeredGestures.contains(trimmedInput);
      setState(() {
        _isNameValid = !isDuplicate;
        _isDuplicateChecked = true;
        _errorMessage = isDuplicate
            ? '이미 등록된 이름입니다.'
            : '등록할 수 있는 이름입니다. [제스처 촬영]을 눌러 촬영을 시작해주세요';
      });
    }
  }

  Future<void> _startCamera() async {
    try {
      await NativeChannelService.cameraChannel.invokeMethod('startCamera');
      print('📷 네이티브 카메라 호출 완료');
    } on PlatformException catch (e) {
      print("❌ 카메라 호출 실패: '${e.message}'.");
    }
  }

  Future<void> _resetGesture() async {
    try {
      await NativeChannelService.resetChannel.invokeMethod('reset');
      print('🔄 제스처 초기화 완료');
      // 제스처 목록 새로고침
      await _loadGestureList();
      // 초기화 후 사용자에게 알림
      // if (mounted) {
      //   ScaffoldMessenger.of(
      //     context,
      //   ).showSnackBar(const SnackBar(content: Text('제스처가 초기화되었습니다.')));
      // }
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
                  HeaderWidget(
                    title: '사용자 제스처 등록',
                    description: '새롭게 등록할 제스처의 이름을 설정해주세요.',
                    isMain: false,
                  ),

                  const SizedBox(height: 20),

                  // 제스처 이름 입력 및 중복검사
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            decoration: const InputDecoration(
                              hintText: '제스처 이름을 적어주세요.',
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
                                final shouldStart =
                                    await CustomDialogs.showCameraDialog(
                                      context,
                                      NativeChannelService.cameraChannel,
                                      _controller,
                                    );

                                if (shouldStart == true) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => GestureShootingPage(
                                        gestureName: _controller.text,
                                      ),
                                    ),
                                  );
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
                        onPressed: () async {
                          final shouldReset =
                              await CustomDialogs.showResetDialog(
                                context,
                                NativeChannelService.resetChannel,
                              );
                          if (shouldReset == true) {
                            _resetGesture();
                          }
                        },
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
