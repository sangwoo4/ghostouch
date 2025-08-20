import 'dart:io';

// 기본 제스처 한글 매핑
const Map<String, String> defaultGestureMapping = {
  'scissors': '가위 제스처',
  'rock': '주먹 제스처',
  'paper': '보 제스처',
};

// 플랫폼별 동작 옵션
Map<String, String> getActionOptions() {
  if (Platform.isAndroid) {
    return {
      'none': '동작 없음',
      'action_open_memo': '메모장 실행',
      'action_open_dialer': '전화 실행',
      'action_open_messages': '메시지 실행',
      'action_open_camera': '카메라 실행',
      'action_open_gallery': '갤러리 실행',
      'action_open_clock': '시계 실행',
      'action_open_calendar': '캘린더 실행',
      'action_open_calculator': '계산기 실행',
      'action_open_contacts': '연락처 실행',
      'action_open_settings': '설정 실행',
      'action_volume_up': '볼륨 증가',
      'action_volume_down': '볼륨 감소',
      'action_volume_mute': '음소거/해제',
      'action_flashlight_toggle': '플래시 켜기/끄기',
      'action_brightness_up': '화면 밝기 증가',
      'action_brightness_down': '화면 밝기 감소',
    };
  } else if (Platform.isIOS) {
    return {
      'none': '동작 없음',
      // 'action_open_memo': '메모장 실행',
      // 'action_open_dialer': '전화 실행',
      // 'action_open_messages': '메시지 실행',
      // 'action_open_camera': '카메라 실행',
      // 'action_open_gallery': '갤러리 실행',
      // 'action_open_clock': '시계 실행',
      // 'action_open_calendar': '캘린더 실행',
      // 'action_open_calculator': '계산기 실행',
      // 'action_open_contacts': '연락처 실행',
      // 'action_open_settings': '설정 실행',
      'action_brightness_up': '화면 밝기 증가',
      'action_brightness_down': '화면 밝기 감소',
      'action_volume_up': '볼륨 증가',
      'action_volume_down': '볼륨 감소',
      'action_volume_mute': '음소거/해제',
    };
  } else {
    return {'none': '동작 없음'};
  }
}
