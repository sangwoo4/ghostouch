# Ghostouch Flutter 프로젝트

### Flutter version

- **flutter vesion : 3.32.6**
- **dart sdk version : 3.8.1**

---

## 시작하기

순서대로 명령어를 실행

1. 프로젝트 정리

   ```bash
   flutter clean
   ```

2. 패키지 설치

   ```bash
   flutter pub get
   ```

3. 앱 실행

- 3-1: 애뮬레이터로 실행 시

  ```bash
  flutter run
  ```

- 3-2 : 실기기로 실행 시 (android)

```bash
	# 1) 기기의 Serial Number 검색
	flutter devices

	# 2) AndroidManifest.xml파일에 <IP_주소>에 기기와 연결된 실제 IP 주소 삽입
	<meta-data
		android:name="com.pentagon.ghostouch.SERVER_IP"
		android:value="192.xxx.xxx.xxx" /> # 실제 IP 주소
	<meta-data
		android:name="com.pentagon.ghostouch.SERVER_PORT"
		android:value="8000" />

	# 3) 앱 설치 및 실행
	flutter run -d <serial_number>
```

- 3-3: 실기기로 실행 시 (ios)

(VSCode에서 Xcode의 자동화 권한 설정 필수 / 로컬 네트워크와 카메라 권한 필수)

```bash
	# 1) 기기의 Serial Number 검색
	flutter devices

	# 2) info.plist 파일에 <IP_주소>에 기기와 연결된 실제 IP 주소 삽입
	<key>ServerIP</key>
	<string>192.xxx.xxx.xxx</string>
	<key>ServerPort</key>
	<string>8000</string>

	# 3) 앱 설치 및 실행
	flutter run -d <serial_number>
```

4. 앱 로고 아이콘이 보이지 않을 때 별도 설치
   ```bash
   flutter pub run flutter_launcher_icons
   flutter pub run flutter_native_splash:create
   ```

---

## Flutter Multi Cross Channel Name

플러터-네이티브(IOS 및 Android) 간 MethodChannel 연결 구조
각 채널은 특정 기능을 담당 및 iOS/Android 모두에서 동작

| 기능 설명                       | 채널 이름                                | 개설 여부 | IOS | Android |
| ------------------------------- | ---------------------------------------- | --------- | --- | ------- |
| 메인화면 Ghostouch 사용 토글    | `com.pentagon.ghostouch/toggle`          | ✅        | ✅  | ✅      |
| 제스처 촬영 버튼(카메라 실행)   | `com.pentagon.ghostouch/camera`          | ✅        | ✅  | ✅      |
| 등록된 제스처 목록 보기         | `com.pentagon.ghostouch/list-gesture`    | ✅        | ✅  | ✅      |
| 제스처 초기화                   | `com.pentagon.ghostouch/reset-gesture`   | ✅        | ✅  | ✅      |
| 제스처 동작 설정                | `com.pentagon.ghostouch/funtion-gesture` | ✅        | ✅  | ✅      |
| 안드로이드 백그라운드 시간 설정 | `com.pentagon.ghostouch/background`      | ✅        |     | ✅      |
| 외부 앱 사이트 들어가기         | `com.pentagon.ghostouch/control-app`     | ✅        | ✅  | ✅      |
| 사용자 제스처 수집 상태바       | `com.pentagon.gesture/task-id`           | ✅        | ✅  | ✅      |
| 제스처 수집 손 랜드마크 추출    | `com.pentagon.ghostouch/hand_detection`  | ✅        | ✅  | ✅      |
