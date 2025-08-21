import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ghostouch/services/native_channel_service.dart';
import 'package:ghostouch/data/gesture_data.dart';
import 'package:ghostouch/widgets/header.dart';

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
            HeaderWidget(
              title: '제스처 기능 설정',
              description: '오프라인 상태에서 사용할 제스처를 골라주세요.',
              isMain: false,
            ),

            const SizedBox(height: 20),

            // 제스처 리스트
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: gestureNames.length,
                      itemBuilder: (context, index) {
                        String gestureKey = gestureNames.keys.elementAt(index);
                        String gestureValue = gestureNames.values.elementAt(
                          index,
                        );

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 6,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 15,
                              vertical: 5,
                            ),
                            title: Text(
                              gestureValue,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            trailing: GestureActionDropdown(
                              gestureKey: gestureKey,
                            ),
                          ),
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

  void _showActionDialog() async {
    final options = getActionOptions();

    final String? selectedKey = await showDialog<String>(
      context: context,
      builder: (context) {
        return Center(
          child: Material(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white,
            child: Container(
              width: 200,
              height: 400,
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: ListView(
                shrinkWrap: true,
                children: options.entries.map((entry) {
                  final isSelected = selectedAction == entry.value;
                  return Container(
                    color: isSelected
                        ? const Color(0xFF0E1539)
                        : Colors.transparent,
                    child: ListTile(
                      title: Text(
                        entry.value,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          color: isSelected ? Colors.white : Colors.black,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context, entry.key); // 선택된 key 반환
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
    );

    if (selectedKey != null) {
      setState(() {
        selectedAction = options[selectedKey]!;
      });
      _setGestureAction(selectedKey);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: _showActionDialog,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10),
      ),
      child: Text(
        selectedAction,
        style: const TextStyle(fontSize: 14, color: Colors.black),
      ),
    );
  }
}