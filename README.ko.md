# 👋 제스처 인식 프로젝트: 증분 학습 파이프라인

웹캠을 통해 실시간으로 손 제스처(예: '가위', '바위', '보)를 인식하는 딥러닝 프로젝트입니다. MediaPipe로 손 랜드마크를 추출하고, TensorFlow/Keras 기반의 CNN 모델로 제스처를 분류합니다.

**이 프로젝트의 모든 코드와 학습된 모델은 MIT License에 따라 배포됩니다.**

---

## ✨ 주요 기능

-   **실시간 제스처 인식**: 웹캠을 활용하여 손 제스처를 즉시 감지하고 분류합니다.
-   **증분 학습 (Incremental Learning)**: 기존에 학습된 모델에 새로운 제스처를 효율적으로 추가하여 학습할 수 있습니다.
-   **멀티프로세싱 기반 데이터 처리**: 이미지에서 손 랜드마크를 병렬로 추출하여 전처리 속도를 대폭 향상시킵니다.
-   **자동 라벨 맵 관리**: 이미지 폴더 구조를 기반으로 라벨 맵을 동적으로 생성하고, 여러 라벨 맵을 충돌 없이 통합합니다.
-   **클래스 불균형 처리**: 데이터셋 내 클래스 간 불균형을 자동으로 보정하여, 데이터가 적은 새로운 제스처도 효과적으로 학습합니다.
-   **모델 학습 및 변환**: CNN 모델을 학습시키고, 실시간 추론에 최적화된 TensorFlow Lite (`.tflite`) 모델로 자동 변환합니다.
-   **모듈화된 구조**: 설정, 데이터 처리, 모델 학습, 실시간 테스트 등 기능별로 코드가 명확하게 분리되어 있어 유지보수와 확장이 용이합니다.

---

## 📂 프로젝트 구조

```
gesture/
├── data/
│   ├── image_data/         # 기본 학습용 원본 이미지 (가위, 바위, 보 등)
│   ├── new_image_data/     # 증분 학습용 새로운 제스처 이미지 (예: '하나')
│   └── processed/          # 전처리된 데이터 (csv, npy 등)
├── models/
│   ├── basic_gesture_model.keras # 기본 학습된 Keras 모델
│   ├── basic_gesture_model.tflite# 기본 학습된 TFLite 모델
│   ├── basic_label_map.json      # 기본 제스처 라벨 맵
│   ├── combine_gesture_model.keras # 증분 학습으로 업데이트된 통합 Keras 모델
│   ├── combine_gesture_model.tflite# 증분 학습으로 업데이트된 통합 TFLite 모델
│   └── combine_label_map.json      # 통합 제스처 라벨 맵
└── src/
    ├── main.py             # 데이터 처리 및 모델 학습 파이프라인 실행
    ├── live_test.py        # 실시간 제스처 인식 실행
    ├── config.py           # 프로젝트 설정 관리
    ├── data_processor.py   # 이미지 전처리 및 랜드마크 추출
    ├── data_manager.py     # 데이터셋 분할, 병합 및 라벨 관리
    └── model_trainer.py    # 모델 정의 및 학습
```

---

## 🚀 시작하기

### 1. 환경 설정

프로젝트 실행에 필요한 라이브러리들을 설치하기 전에, 파이썬 가상 환경을 생성하고 활성화하는 것을 권장합니다.

```bash
# 가상 환경 생성 (venv)
python -m venv venv

# 가상 환경 활성화
# Windows
.\venv\Scripts\activate
# macOS/Linux
source venv/bin/activate
```

가상 환경 활성화 후, 필요한 라이브러리들을 설치합니다.

```bash
pip install -r requirements.txt
```

### 2. 데이터 준비

`gesture/data/image_data/` 폴더는 저작권 및 라이센스 문제로 인해 Git 저장소에 포함되지 않습니다. 이 폴더에는 주로 **Google MediaPipe에서 제공하는 예시 이미지**나 공개된 데이터셋에서 가져온 학습용 이미지 데이터를 준비해 주세요.

새로운 제스처를 추가하거나 기존 데이터를 보강하려면 `gesture/data/image_data/` 디렉토리 아래에 제스처 이름으로 폴더를 만들고 이미지를 추가합니다.

**증분 학습을 위한 데이터**: `gesture/data/new_image_data/` 폴더에는 **직접 카메라로 촬영한 새로운 제스처 이미지**를 추가합니다. 이 폴더의 데이터는 기존 `image_data`와 함께 증분 학습에 사용됩니다.

MediaPipe Gesture Recognizer에 대한 자세한 정보는 [여기](https://ai.google.dev/edge/mediapipe/solutions/vision/gesture_recognizer?hl=ko)에서 확인할 수 있습니다.

### 3. 모델 학습 (`main.py`)

`main.py`를 실행하여 데이터 처리부터 모델 학습까지 전체 파이프라인을 실행합니다. `--mode` 인자를 사용하여 학습 모드를 선택할 수 있습니다.

*   **Basic 모델 학습 (기본 학습)**:
    `gesture/data/image_data/`의 이미지를 기반으로 `basic_hand_landmarks.csv`, `basic_train_data.npy`, `basic_test_data.npy`를 생성하고, `basic_gesture_model.keras`, `basic_gesture_model.tflite`, `basic_label_map.json`을 `models` 폴더에 저장합니다.
    ```bash
    python gesture/src/main.py --mode train
    ```

*   **통합 모델 업데이트 (증분 학습)**:
    `gesture/data/image_data/`의 기존 데이터와 `gesture/data/new_image_data/`의 새로운 데이터를 모두 사용하여 통합 데이터셋을 구성합니다. 기존 `basic_gesture_model.keras`를 기반으로 증분 학습을 수행하여 `combine_gesture_model.keras`, `combine_gesture_model.tflite`, `combine_label_map.json`을 `models` 폴더에 저장합니다. `--base_model_path` 인자로 기본 모델의 경로를 지정할 수 있으며, 지정하지 않으면 `basic_gesture_model.keras`가 기본값으로 사용됩니다.
    ```bash
    python gesture/src/main.py --mode update [--base_model_path gesture/models/basic_gesture_model.keras]
    ```

### 4. 실시간 제스처 인식 (`live_test.py`)

`live_test.py`를 실행하여 웹캠을 통해 학습된 모델의 성능을 실시간으로 확인합니다. `--model_type` 인자를 사용하여 사용할 모델을 선택할 수 있습니다.

*   **Basic 모델로 테스트**:
    `basic_gesture_model.tflite`와 `basic_label_map.json`을 사용하여 실시간 인식을 수행합니다.
    ```bash
    python gesture/src/live_test.py --model_type basic
    ```
    (또는 `--model_type basic`이 기본값이므로 단순히 `python gesture/src/live_test.py`로 실행해도 됩니다.)

*   **통합 모델로 테스트**:
    `combine_gesture_model.tflite`와 `combine_label_map.json`을 사용하여 실시간 인식을 수행합니다.
    ```bash
    python gesture/src/live_test.py --model_type combine
    ```
ESC 키를 누르면 프로그램이 종료됩니다. 손이 감지되지 않을 경우 "Unknown"이 출력됩니다.

---

## ⚙️ 작동 원리

1.  **데이터 처리 (`data_processor.py`)**:
    -   `image_data` 또는 `new_image_data` 폴더의 이미지를 읽어들입니다.
    -   **멀티프로세싱**을 사용하여 MediaPipe Hands로 각 이미지에서 21개의 손 랜드마크 좌표(x, y, z)를 병렬로 추출합니다.
    -   추출된 랜드마크를 **이동(translation), 크기(scale), 회전(rotation)**에 대해 정규화하여 손의 위치, 크기, 방향에 관계없이 일관된 특징을 학습할 수 있도록 합니다.
    -   이미지 폴더 구조를 기반으로 라벨 맵을 **동적으로 생성**하고, 처리된 랜드마크 데이터와 **문자열 라벨**을 `basic_hand_landmarks.csv` 또는 `incremental_hand_landmarks.csv` 파일로 저장합니다.

2.  **데이터 관리 (`data_manager.py`)**:
    -   생성된 랜드마크 CSV 파일을 로드합니다.
    -   데이터를 학습용(train)과 테스트용(test)으로 분할하고, 모델 학습에 적합한 NumPy 배열(`.npy`) 형태로 저장합니다.
    -   `basic` 라벨 맵과 `incremental` 라벨 맵을 병합하여 `combine_label_map.json`을 생성합니다. 이때 `basic` 라벨의 인덱스를 우선하고, 새로운 라벨만 뒤에 추가하여 **라벨 충돌을 방지**합니다.
    -   `basic` 데이터와 `transfer` 데이터를 병합할 때, 각 데이터의 라벨을 통합 라벨 맵 기준으로 **재조정(re-mapping)**하여 정확한 통합 데이터셋을 구성합니다.

3.  **모델 학습 (`model_trainer.py`)**:
    -   분할된 `.npy` 데이터셋을 로드합니다.
    -   **Basic 학습**: 새로운 CNN(Convolutional Neural Network) 모델을 구성하고 학습시킵니다. 가장 성능이 좋은 모델을 `basic_gesture_model.keras`로 저장하고, 경량화된 `basic_gesture_model.tflite` 파일로 변환합니다.
    -   **증분 학습**: 기존 `basic_gesture_model.keras`를 불러와 특징 추출기로 사용하고, 새로운 분류 레이어를 추가하여 미세 조정(fine-tuning)을 수행합니다. 이때 **`class_weight`를 적용**하여 데이터셋 내 클래스 불균형을 자동으로 보정합니다. 학습된 모델은 `combine_gesture_model.keras`로 저장되고 `combine_gesture_model.tflite`로 변환됩니다.

4.  **실시간 테스트 (`live_test.py`)**:
    -   선택된 모델 (`basic_gesture_model.tflite` 또는 `combine_gesture_model.tflite`)과 해당 라벨 맵을 로드합니다.
    -   OpenCV를 사용하여 웹캠 피드를 받아옵니다.
    -   각 프레임에서 손 감지 후 랜드마크를 추출한 뒤, 학습 시와 동일한 방식으로 정규화합니다.
    -   TFLite 모델을 통해 정규화된 랜드마크를 입력으로 제스처를 예측하고, 예측 신뢰도가 `CONFIDENCE_THRESHOLD`(0.8) 이상일 경우 결과를 화면에 표시합니다.
    -   손이 감지되지 않거나 신뢰도가 낮을 경우 "Unknown"이 출력됩니다.

---

## 🛠️ 주요 기술 스택

-   **Python**
-   **TensorFlow / Keras**: 모델 학습 및 추론
-   **MediaPipe**: 손 랜드마크 추출
-   **OpenCV**: 실시간 영상 처리
-   **NumPy, Pandas**: 데이터 처리
-   **Scikit-learn**: 데이터 분할