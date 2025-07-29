import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class GestureRegisterPage extends StatefulWidget {
  const GestureRegisterPage({super.key});

  @override
  State<GestureRegisterPage> createState() => _GestureRegisterPageState();
}

class _GestureRegisterPageState extends State<GestureRegisterPage> {
  final TextEditingController _controller = TextEditingController();
  bool _isDuplicateChecked = false;
  bool _isNameValid = false;

  static const cameraChannel = MethodChannel('com.pentagon.ghostouch/camera');
  static const resetChannel = MethodChannel(
    'com.pentagon.ghostouch/reset-gesture',
  );

  final List<String> registeredGestures = [
    '가위 제스처',
    '주먹 제스처',
    '보 제스처',
    '한성대 제스처',
  ];

  String _errorMessage = '';

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
      // 필요 시 사용자에게 알림 표시
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('제스처가 초기화되었습니다.')));
    } on PlatformException catch (e) {
      print('❌ 제스처 초기화 실패: ${e.message}');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('초기화 실패: ${e.message}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final inputValidAndChecked = _isDuplicateChecked && _isNameValid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('사용자 제스처 등록'),
        backgroundColor: const Color(0xFF0E1539),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '새롭게 등록할 제스처의 이름을 설정해주세요.',
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 20),

            // 입력 + 중복검사
            Row(
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
                          ? (_isNameValid ? Icons.check_circle : Icons.cancel)
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
            const SizedBox(height: 8),
            Text(
              _errorMessage,
              style: TextStyle(
                fontSize: 12,
                color: _isNameValid ? Colors.orange : Colors.redAccent,
              ),
            ),
            const SizedBox(height: 30),

            // 제스처 촬영 버튼
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: inputValidAndChecked ? _startCamera : null,
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

            const SizedBox(height: 30),

            const Text(
              '등록된 제스처 목록',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),

            // 등록된 제스처 리스트
            Column(
              children: registeredGestures
                  .map(
                    (gesture) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: TextFormField(
                        initialValue: gesture,
                        readOnly: true,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.grey[100],
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 20),

            // 제스처 초기화 버튼
            SizedBox(
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
          ],
        ),
      ),
    );
  }
}
