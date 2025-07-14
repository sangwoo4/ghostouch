# 제스처 인식 프로젝트

웹캠을 통해 실시간으로 손 제스처(예: '가위', '바위', '보')를 인식하는 딥러닝 프로젝트입니다. MediaPipe로 손 랜드마크를 추출하고, TensorFlow/Keras 기반의 CNN 모델로 제스처를 분류합니다.

## ✨ 주요 기능

-   **실시간 제스처 인식**: 웹캠을 활용하여 손 제스처를 즉시 감지하고 분류합니다.
-   **데이터 처리 파이프라인**: 이미지에서 손 랜드마크를 추출하고 정규화하여 학습용 데이터셋을 자동으로 생성합니다.
-   **모델 학습 및 변환**: CNN 모델을 학습시키고, 실시간 추론에 최적화된 TensorFlow Lite (`.tflite`) 모델로 자동 변환합니다.
-   **모듈화된 구조**: 설정, 데이터 처리, 모델 학습, 실시간 테스트 등 기능별로 코드가 명확하게 분리되어 있어 유지보수와 확장이 용이합니다.

## 📂 프로젝트 구조

```
gesture/
├── data/
│   ├── image_data/         # 학습용 원본 이미지 (가위, 바위, 보 등)
│   └── processed/          # 전처리된 데이터 (landmark.csv, train_data.npy)
├── models/
│   ├── gesture_model.keras # 학습된 Keras 모델
│   ├── gesture_model.tflite# 변환된 TFLite 모델
│   └── label_map.json      # 제스처 라벨 맵
└── src/
    ├── main.py             # 데이터 처리 및 모델 학습 파이프라인 실행
    ├── live_test.py        # 실시간 제스처 인식 실행
    ├── config.py           # 프로젝트 설정 관리
    ├── data_processor.py   # 이미지 전처리 및 랜드마크 추출
    ├── data_manager.py     # 데이터셋 분할 및 저장
    └── model_trainer.py    # 모델 정의 및 학습
```

## 🚀 시작하기

### 1. 환경 설정

프로젝트 실행에 필요한 라이브러리들을 설치합니다.

```bash
pip install -r requirements.txt
```

### 2. 데이터 준비

`gesture/data/image_data/` 폴더는 저작권 및 라이센스 문제로 인해 Git 저장소에 포함되지 않습니다. 프로젝트를 실행하기 위해서는 사용자분께서 직접 학습용 이미지 데이터를 준비하여 이 폴더에 저장해 주셔야 합니다.

새로운 제스처를 추가하거나 기존 데이터를 보강하려면 `gesture/data/image_data/` 디렉토리 아래에 제스처 이름으로 폴더를 만들고 이미지를 추가합니다. MediaPipe Gesture Recognizer에 대한 자세한 정보는 [여기](https://ai.google.dev/edge/mediapipe/solutions/vision/gesture_recognizer?hl=ko)에서 확인할 수 있습니다.

### 3. 모델 학습

`main.py`를 실행하여 데이터 처리부터 모델 학습까지 전체 파이프라인을 실행합니다. 이 과정은 `image_data`의 이미지를 기반으로 `processed` 데이터를 생성하고, `models` 폴더에 새로운 모델을 저장합니다.

```bash
python gesture/src/main.py
```

### 4. 실시간 제스처 인식

`live_test.py`를 실행하여 웹캠을 통해 학습된 모델의 성능을 실시간으로 확인합니다.

```bash
python gesture/src/live_test.py
```
ESC 키를 누르면 프로그램이 종료됩니다.

## ⚙️ 작동 원리

1.  **데이터 처리 (`data_processor.py`)**:
    -   `image_data` 폴더의 이미지를 읽어들입니다.
    -   MediaPipe Hands를 사용하여 각 이미지에서 21개의 손 랜드마크 좌표(x, y, z)를 추출합니다.
    -   추출된 랜드마크를 **이동(translation), 크기(scale), 회전(rotation)**에 대해 정규화하여 손의 위치, 크기, 방향에 관계없이 일관된 특징을 학습할 수 있도록 합니다.
    -   처리된 랜드마크 데이터와 라벨을 `hand_landmarks.csv` 파일로 저장합니다.

2.  **데이터 관리 (`data_manager.py`)**:
    -   `hand_landmarks.csv` 파일을 로드합니다.
    -   데이터를 학습용(train)과 테스트용(test)으로 분할하고, 모델 학습에 적합한 NumPy 배열(`.npy`) 형태로 저장합니다.

3.  **모델 학습 (`model_trainer.py`)**:
    -   분할된 `.npy` 데이터셋을 로드합니다.
    -   CNN(Convolutional Neural Network) 모델을 구성합니다.
    -   모델을 학습시키고, 가장 성능이 좋은 모델을 `gesture_model.keras`로 저장합니다.
    -   저장된 Keras 모델을 경량화된 `gesture_model.tflite` 파일로 변환하여 실시간 추론 성능을 최적화합니다.

4.  **실시간 테스트 (`live_test.py`)**:
    -   `gesture_model.tflite` 모델과 `label_map.json`을 로드합니다.
    -   OpenCV를 사용하여 웹캠 피드를 받아옵니다.
    -   각 프레임에서 손을 감지하고 랜드마크를 추출한 뒤, 학습 시와 동일한 방식으로 정규화합니다.
    -   TFLite 모델을 통해 정규화된 랜드마크를 입력으로 제스처를 예측하고, 결과를 화면에 표시합니다.

## 🛠️ 주요 기술 스택

-   **Python**
-   **TensorFlow / Keras**: 모델 학습 및 추론
-   **MediaPipe**: 손 랜드마크 추출
-   **OpenCV**: 실시간 영상 처리
-   **NumPy, Pandas**: 데이터 처리
-   **Scikit-learn**: 데이터 분할