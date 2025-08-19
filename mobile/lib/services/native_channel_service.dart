import 'package:flutter/services.dart';

// Native와 통신하는 채널 모음
class NativeChannelService {
  // main.dart
  static const toggleChannel = MethodChannel('com.pentagon.ghostouch/toggle');

  static const foregroundChannel = MethodChannel(
    'com.pentagon.ghostouch/foreground',
  );

  static const backgroundChannel = MethodChannel(
    'com.pentagon.ghostouch/background',
  );

  // ControlAppPage.dart
  static const controlAppChannel = MethodChannel(
    "com.pentagon.ghostouch/control-app",
  );
  static const iosCameraChannel = MethodChannel(
    "com.pentagon.ghostouch/ios-camera",
  );

  // GestureRegisterPage.dart
  static const cameraChannel = MethodChannel('com.pentagon.ghostouch/camera');
  static const resetChannel = MethodChannel(
    'com.pentagon.ghostouch/reset-gesture',
  );
  static const listChannel = MethodChannel(
    'com.pentagon.ghostouch/list-gesture',
  );

  // GestureSettingPage.dart
  static const nameMappingChannel = MethodChannel(
    'com.pentagon.ghostouch/toggle',
  );
  static const mappingChannel = MethodChannel('com.pentagon.ghostouch/mapping');

  // GestureShootingPage.dart
  static const taskIdChannel = MethodChannel('com.pentagon.gesture/task-id');
  static const handDetectionChannel = MethodChannel(
    'com.pentagon.ghostouch/hand_detection',
  );
}
