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
   ```bash
   flutter run
   ```

---

## Flutter Multi Cross Channel Name

| 기능 설명                       | 채널 이름                                | 개설 여부 | IOS | Android |
| ------------------------------- | ---------------------------------------- | --------- | --- | ------- |
| 메인화면 Ghostouch 사용 토글    | `com.pentagon.ghostouch/toggle`          | ✅        | ✅  | ✅      |
| 제스처 촬영 버튼(카메라 실행)   | `com.pentagon.ghostouch/camera`          | ✅        |     |         |
| 등록된 제스처 목록 보기         | `com.pentagon.ghostouch/list-gesture`    |           |     |         |
| 제스처 초기화                   | `com.pentagon.ghostouch/reset-gesture`   | ✅        |     |         |
| 제스처 동작 설정                | `com.pentagon.ghostouch/funtion-gesture` |           |     |         |
| 포그라운드 자동 꺼짐 기능 설정  | `com.pentagon.ghostouch/foreground`      |           |     |         |
| 안드로이드 백그라운드 시간 설정 | `com.pentagon.ghostouch/background`      |           |     |
