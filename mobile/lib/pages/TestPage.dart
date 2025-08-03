import 'package:flutter/material.dart';

class TestPage extends StatelessWidget {
  const TestPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('테스트 페이지'),
        backgroundColor: Colors.orange,
      ),
      body: const Center(
        child: Text(
          '여기는 테스트 페이지입니다!',
          style: TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}