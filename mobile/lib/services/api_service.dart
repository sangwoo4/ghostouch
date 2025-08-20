import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:ghostouch/services/native_channel_service.dart';

class ApiService {
  /// 서버 URL 가져오기
  static Future<String> getServerUrl() async {
    try {
      final String result = await NativeChannelService.toggleChannel
          .invokeMethod('getServerUrl');
      return result;
    } on PlatformException catch (e) {
      print("❌ Failed to get server URL: ${e.message}");
      // fallback URL
      return "http://localhost:8000";
    }
  }

  /// 제스처 수집 완료 후 상태 확인 (폴링)
  static Future<void> handleGestureCompletion({
    required String taskId,
    required String serverUrl,
    required void Function(String currentStep) onProgress,
    required void Function() onSuccess,
  }) async {
    bool completed = false;

    while (!completed) {
      try {
        final response = await http.get(Uri.parse("$serverUrl/status/$taskId"));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final currentStep = data["progress"]?["current_step"] ?? "";
          final status = data["status"] ?? "";

          print("📡 Server response: ${response.body}");
          print("Step: $currentStep, Status: $status");

          onProgress(currentStep.isNotEmpty ? currentStep : "모델 다운로드중..");

          if (status.toString().toLowerCase() == "success") {
            onSuccess();
            completed = true;
          } else {
            await Future.delayed(const Duration(seconds: 2));
          }
        } else {
          print("⚠️ Failed to load status: ${response.statusCode}");
          await Future.delayed(const Duration(seconds: 2));
        }
      } catch (e) {
        print("❌ Error fetching status: $e");
        await Future.delayed(const Duration(seconds: 2));
      }
    }
  }
}
