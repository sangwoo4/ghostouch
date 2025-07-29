import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class GestureSettingsPage extends StatefulWidget {
  const GestureSettingsPage({super.key});

  @override
  State<GestureSettingsPage> createState() => _GestureSettingsPageState();
}

class _GestureSettingsPageState extends State<GestureSettingsPage> {
  final List<String> gestureNames = const [
    '가위 제스처',
    '주먹 제스처',
    '보 제스처',
    '한성대 제스처',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                    '제스처 기능 설정',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '오프라인 상태에서 사용할 제스처를 골라주세요.',
                    style: TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 제스처 리스트
            Expanded(
              child: ListView.separated(
                itemCount: gestureNames.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text(gestureNames[index]),
                    trailing: const GestureActionDropdown(),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 드롭다운 버튼 구성
class GestureActionDropdown extends StatefulWidget {
  const GestureActionDropdown({super.key});

  @override
  State<GestureActionDropdown> createState() => _GestureActionDropdownState();
}

class _GestureActionDropdownState extends State<GestureActionDropdown> {
  String selectedAction = '동작 없음';

  final List<String> options = ['동작 없음', '앱 실행', '스크린 캡처', '플레이/정지'];

  @override
  Widget build(BuildContext context) {
    return DropdownButton<String>(
      value: selectedAction,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      style: const TextStyle(fontSize: 14, color: Colors.black),
      borderRadius: BorderRadius.circular(12),
      underline: const SizedBox(),
      items: options.map((String value) {
        return DropdownMenuItem<String>(value: value, child: Text(value));
      }).toList(),
      onChanged: (String? newValue) {
        if (newValue != null) {
          setState(() {
            selectedAction = newValue;
          });
        }
      },
    );
  }
}
