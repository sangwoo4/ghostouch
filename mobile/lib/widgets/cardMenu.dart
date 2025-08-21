import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ghostouch/services/native_channel_service.dart';
import 'package:ghostouch/widgets/dialogs.dart';
import 'package:ghostouch/pages/ControlAppPage.dart';

/// 🔹 토글 카드
class ToggleCard extends StatelessWidget {
  final bool isGestureEnabled;
  final bool isToggleBusy;
  final Function(bool) onToggle;

  const ToggleCard({
    Key? key,
    required this.isGestureEnabled,
    required this.isToggleBusy,
    required this.onToggle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ListTile(
          leading: const Icon(Icons.touch_app, color: Colors.orange),
          title: Text(isGestureEnabled ? '사용함' : '사용 안 함'),
          trailing: Switch(
            value: isGestureEnabled,
            onChanged: isToggleBusy ? null : onToggle,
          ),
        ),
      ),
    );
  }
}

/// 🔹 일반 메뉴 카드
class MenuCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const MenuCard({
    Key? key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ListTile(
          leading: Icon(icon, color: Colors.black),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(subtitle, style: const TextStyle(color: Colors.brown)),
          onTap: onTap,
        ),
      ),
    );
  }
}

/// 🔹 백그라운드 자동 꺼짐 카드
class BackgroundCard extends StatelessWidget {
  final String selectedTimeoutLabel;
  final Map<String, int> timeoutOptions;
  final Function(String) onSelected;

  const BackgroundCard({
    Key? key,
    required this.selectedTimeoutLabel,
    required this.timeoutOptions,
    required this.onSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ListTile(
          leading: const Icon(Icons.access_time, color: Colors.black),
          title: const Text('백그라운드 자동 꺼짐'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(selectedTimeoutLabel, style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 4),
              PopupMenuButton<String>(
                icon: const Icon(Icons.settings, color: Colors.grey),
                onSelected: onSelected,
                itemBuilder: (BuildContext context) {
                  return timeoutOptions.keys.map((String choice) {
                    return PopupMenuItem<String>(
                      value: choice,
                      child: Text(choice),
                    );
                  }).toList();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
