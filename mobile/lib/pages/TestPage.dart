import 'dart:io';

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
      body: _buildPlatformView(),
    );
  }

  Widget _buildPlatformView() {
    if (Platform.isIOS) {
      return const UiKitView(
        viewType: 'com.example.ghostouch/test_page_view',
        layoutDirection: TextDirection.ltr,
        creationParamsCodec: StandardMessageCodec(),
      );
    } else if (Platform.isAndroid) {
      return const AndroidView(
        viewType: 'hand_detection_view',
        layoutDirection: TextDirection.ltr,
      );
    } else {
      return const Center(
        child: Text('This platform is not supported.'),
      );
    }
  }
}
