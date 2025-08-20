import 'package:flutter/material.dart';

class HeaderWidget extends StatelessWidget {
  final String title; // 메인 타이틀
  final String description; // 설명 문구
  final bool showBackButton; // 뒤로가기 버튼 표시 여부
  final bool isMain; // 메인 페이지 여부

  const HeaderWidget({
    Key? key,
    required this.title,
    required this.description,
    this.showBackButton = false,
    this.isMain = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 30),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1539),
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(isMain ? 30 : 30),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showBackButton)
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          if (isMain)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Text(
                    'Pentagon',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
                  ),
                ),
                Icon(Icons.touch_app, size: 60, color: Colors.white),
                CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Icon(Icons.menu_book, size: 30),
                ),
              ],
            ),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: isMain ? 24 : 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}
