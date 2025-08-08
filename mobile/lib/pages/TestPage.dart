import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TestPage extends StatefulWidget {
  const TestPage({super.key});

  @override
  State<TestPage> createState() => _TestPageState();
}

class _TestPageState extends State<TestPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('손 제스처 인식 테스트'),
        backgroundColor: Colors.orange,
      ),
      body: const AndroidView(
        viewType: 'hand_detection_view',
        layoutDirection: TextDirection.ltr,
      ),
    );
  }
}