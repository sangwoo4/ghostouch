import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ghostouch/services/native_channel_service.dart';
import 'package:ghostouch/data/gesture_data.dart';

class GestureSettingsPage extends StatefulWidget {
  const GestureSettingsPage({super.key});

  @override
  State<GestureSettingsPage> createState() => _GestureSettingsPageState();
}

class _GestureSettingsPageState extends State<GestureSettingsPage> {
  // 동적으로 로드할 제스처 맵
  Map<String, String> gestureNames = Map.from(defaultGestureMapping);

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAvailableGestures();
    // 메서드 채널 핸들러 등록
    NativeChannelService.nameMappingChannel.setMethodCallHandler(
      _handleMethodCall,
    );
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method == 'refreshGestureList') {
      await _loadAvailableGestures();
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
      final result = await NativeChannelService.nameMappingChannel.invokeMethod(
        'getAvailableGestures',
      );

      if (result is Map) {
        Map<String, String> newGestureNames = {};

        result.forEach((key, value) {
          String englishKey = key.toString();
          String koreanName =
              defaultGestureMapping[englishKey] ?? '$englishKey 제스처';
          newGestureNames[englishKey] = koreanName;
        });

        setState(() {
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
  String selectedAction = '동작 없음';

  // SharedPreferences에서 초기값 로드
  @override
  void initState() {
    super.initState();
    _loadSavedAction();
  }

  Future<void> _loadSavedAction() async {
    try {
      // 네이티브에서 해당 제스처에 저장된 액션 키를 불러옴 (예: "action_open_memo")
      final String? savedActionKey = await NativeChannelService.mappingChannel
          .invokeMethod('getGestureAction', {'gesture': widget.gestureKey});

      if (savedActionKey != null &&
          getActionOptions().containsKey(savedActionKey)) {
        setState(() {
          // 액션 키에 해당하는 표시 이름(value)으로 상태 업데이트
          selectedAction = getActionOptions()[savedActionKey]!;
        });
      }
    } on PlatformException catch (e) {
      print("❌ 설정 불러오기 실패: ${e.message}");
    }
  }

  Future<void> _setGestureAction(String actionKey) async {
    try {
      await NativeChannelService.mappingChannel.invokeMethod(
        'setGestureAction',
        {'gesture': widget.gestureKey, 'action': actionKey},
      );
      print('✅ 설정 전송: ${widget.gestureKey} -> $actionKey');
    } on PlatformException catch (e) {
      print("❌ 설정 전송 실패: ${e.message}");
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = getActionOptions();

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
