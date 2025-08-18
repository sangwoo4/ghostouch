import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class GestureSettingsPage extends StatefulWidget {
  const GestureSettingsPage({super.key});

  @override
  State<GestureSettingsPage> createState() => _GestureSettingsPageState();
}

class _GestureSettingsPageState extends State<GestureSettingsPage> {
  static const platform = MethodChannel('com.pentagon.ghostouch/toggle');

  // 동적으로 로드할 제스처 맵
  Map<String, String> gestureNames = {
    'scissors': '가위 제스처',
    'rock': '주먹 제스처',
    'paper': '보 제스처',
    'hs': '한성대 제스처',
  };

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAvailableGestures();
    // 메서드 채널 핸들러 등록
    platform.setMethodCallHandler(_handleMethodCall);
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'refreshGestureList':
        await _loadAvailableGestures();
        break;
      default:
        break;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 페이지가 다시 보일 때마다 제스처 목록 새로고침
    if (mounted) {
      _loadAvailableGestures();
    }
  }

  Future<void> _loadAvailableGestures() async {
    try {
      final result = await platform.invokeMethod('getAvailableGestures');
      if (result is Map) {
        setState(() {
          // 새로 로드된 제스처들을 기존 맵에 추가하면서 한글 이름 매핑
          Map<String, String> newGestureNames = {};

          result.forEach((key, value) {
            String englishKey = key.toString();
            String koreanName = _getKoreanName(englishKey);
            newGestureNames[englishKey] = koreanName;
          });

          gestureNames = newGestureNames;
          isLoading = false;
        });
      }
    } on PlatformException catch (e) {
      print("Failed to load gestures: '${e.message}'");
      setState(() {
        isLoading = false;
      });
    }
  }

  String _getKoreanName(String englishKey) {
    // 기본 제스처들의 한글 매핑
    const defaultMapping = {
      'scissors': '가위 제스처',
      'rock': '주먹 제스처',
      'paper': '보 제스처',
      'hs': '한성대 제스처',
    };

    // 기본 매핑에 있으면 해당 한글명 반환, 없으면 사용자 정의 제스처로 표시
    return defaultMapping[englishKey] ?? '$englishKey 제스처';
  }

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
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.separated(
                      itemCount: gestureNames.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        // 영어 키와 한글 값 가져오기
                        String gestureKey = gestureNames.keys.elementAt(index);
                        String gestureValue = gestureNames.values.elementAt(
                          index,
                        );

                        return ListTile(
                          title: Text(gestureValue),
                          trailing: GestureActionDropdown(
                            gestureKey: gestureKey,
                          ), // 영어 키 전달
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
  final String gestureKey; // 제스처 영어 키
  const GestureActionDropdown({super.key, required this.gestureKey});

  @override
  State<GestureActionDropdown> createState() => _GestureActionDropdownState();
}

class _GestureActionDropdownState extends State<GestureActionDropdown> {
  // MethodChannel 선언
  static const platform = MethodChannel('com.pentagon.ghostouch/mapping');

  String selectedAction = '동작 없음';

  // 실제 액션 값과 표시될 이름 매핑
  final Map<String, String> options = {
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
  };

  // SharedPreferences에서 초기값 로드
  @override
  void initState() {
    super.initState();
    _loadSavedAction();
  }

  Future<void> _loadSavedAction() async {
    try {
      // 네이티브에서 해당 제스처에 저장된 액션 키를 불러옴 (예: "action_open_memo")
      final String? savedActionKey = await platform.invokeMethod(
        'getGestureAction',
        {'gesture': widget.gestureKey},
      );

      if (savedActionKey != null && options.containsKey(savedActionKey)) {
        setState(() {
          // 액션 키에 해당하는 표시 이름(value)으로 상태 업데이트
          selectedAction = options[savedActionKey]!;
        });
      }
    } on PlatformException catch (e) {
      print("❌ 설정 불러오기 실패: ${e.message}");
    }
  }

  Future<void> _setGestureAction(String actionKey) async {
    try {
      await platform.invokeMethod('setGestureAction', {
        'gesture': widget.gestureKey,
        'action': actionKey,
      });
      print('✅ 설정 전송: ${widget.gestureKey} -> $actionKey');
    } on PlatformException catch (e) {
      print("❌ 설정 전송 실패: ${e.message}");
    }
  }

  @override
  Widget build(BuildContext context) {
    return DropdownButton<String>(
      value: selectedAction,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      style: const TextStyle(fontSize: 14, color: Colors.black),
      borderRadius: BorderRadius.circular(12),
      underline: const SizedBox(),
      items: options.entries.map((entry) {
        return DropdownMenuItem<String>(
          value: entry.value, // 화면에 표시될 이름
          child: Text(entry.value),
        );
      }).toList(),
      onChanged: (String? newValue) {
        if (newValue != null) {
          setState(() {
            selectedAction = newValue;
            // 선택된 표시 이름으로 실제 액션 키 찾기
            String actionKey = options.keys.firstWhere(
              (k) => options[k] == newValue,
              orElse: () => 'none',
            );
            _setGestureAction(actionKey);
          });
        }
      },
    );
  }
}
