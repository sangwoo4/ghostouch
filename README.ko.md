# 👋 제스처 인식 프로젝트: 증분 학습 파이프라인

<!-- TOC Start -->
- [✨ 주요 기능](#-주요-기능)
- [📂 프로젝트 구조](#-프로젝트-구조)
- [🚀 시작하기](#-시작하기)
  - [1. 환경 설정](#1-환경-설정)
  - [2. 데이터 준비](#2-데이터-준비)
  - [3. 모델 학습 및 평가 (`main.py`)](#3-모델-학습-및-평가-mainpy)
  - [4. 실시간 제스처 인식 (`live_test.py`)](#4-실시간-제스처-인식-live_testpy)
- [💻 시스템 요구 사항 및 의존성](#-시스템-요구-사항-및-의존성)
- [⚙️ 작동 원리](#-작동-원리)
- [🛠️ 주요 기술 스택](#-주요-기술-스택)
<!-- TOC End -->

웹캠을 통해 실시간으로 손 제스처(예: '가위', '바위', '보)를 인식하는 딥러닝 프로젝트입니다. MediaPipe로 손 랜드마크를 추출하고, TensorFlow/Keras 기반의 CNN 모델로 제스처를 분류하며, 학습 완료 후 자동으로 모델 성능을 평가합니다.

**이 프로젝트의 모든 코드와 학습된 모델은 MIT License에 따라 배포됩니다.**

---

## ✨ 주요 기능
-   **실시간 제스처 인식**: 웹캠을 활용하여 손 제스처를 즉시 감지하고 분류합니다.<br><br>
-   **증분 학습 (Incremental Learning)**: 기존에 학습된 모델에 새로운 제스처를 효율적으로 추가하여 학습할 수 있습니다.<br><br>
-   **통합 파이프라인**: 단일 명령어로 데이터 전처리, 모델 학습, 성능 평가까지 한 번에 실행합니다.<br><br>
-   **자동화된 모델 평가**: 모델 학습 직후, 혼동 행렬(Confusion Matrix), ROC/PR 커브 등 다양한 지표를 포함한 성능 보고서를 자동으로 생성합니다.<br><br>
-   **멀티프로세싱 기반 데이터 처리**: 이미지에서 손 랜드마크를 병렬로 추출하여 전처리 속도를 대폭 향상시킵니다.<br><br>
-   **자동 라벨 맵 관리**: 이미지 폴더 구조를 기반으로 라벨 맵을 동적으로 생성하고, 여러 라벨 맵을 충돌 없이 통합합니다.<br><br>
-   **클래스 불균형 처리**: 데이터셋 내 클래스 간 불균형을 자동으로 보정하여, 데이터가 적은 새로운 제스처도 효과적으로 학습합니다.<br><br>
-   **모듈화된 구조**: 설정, 데이터 처리, 모델 학습, 평가, 테스트 등 기능별로 코드가 명확하게 분리되어 있어 유지보수와 확장이 용이합니다.

---

## 📂 프로젝트 구조

```
gesture/
├── analysis/                       # 모델 평가 결과 저장
│   └── results/
│       ├── basic_model_evaluation/
│       └── combine_model_evaluation/
├── data/
│   ├── image_data/                 # 기본 학습용 원본 이미지
│   ├── new_image_data/             # 증분 학습용 새로운 제스처 이미지
│   └── processed/                  # 전처리된 데이터 (csv, npy 등)
├── models/                         # 생성된 모델 및 데이터 (keras, tflite, json 등)
└── src/
    ├── main.py                     # 전체 학습 및 평가 파이프라인 실행
    ├── config/                     # 프로젝트 설정 관리
    │   ├── analysis_config.py
    │   ├── file_config.py
    │   └── train_config.py
    ├── data/                       # 데이터 처리 관련 모듈
    │   ├── data_combiner.py
    │   ├── data_converter.py
    │   └── data_preprocessor.py
    ├── label/                      # 라벨 처리 관련 모듈
    │   └── label_processor.py
    ├── model/                      # 모델 아키텍처 정의
    │   └── model_architect.py
    ├── train/                      # 모델 학습 관련 모듈
    │   └── model_train.py
    └── utils/                      # 유틸리티 모듈
        ├── duplicate_checker.py    # 데이터 중복 방지 로직   
        ├── evaluation.py           # 모델 평가 로직
        └── live_test.py            # 실시간 제스처 인식 실행
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

가상 환경 활성화 후, pip을 최신 버전으로 업그레이드 하고 필요한 라이브러리들을 설치합니다.

```bash
# pip 업그레이드
python -m pip install --upgrade pip

# 라이브러리 설치
pip install -r requirements.txt
```

### 2. 데이터 준비

`gesture/data/image_data/` 폴더는 저작권 및 라이센스 문제로 인해 Git 저장소에 포함되지 않습니다. 이 폴더에는 주로 **Google MediaPipe에서 제공하는 예시 이미지**나 공개된 데이터셋에서 가져온 학습용 이미지 데이터를 준비해 주세요.

새로운 제스처를 추가하거나 기존 데이터를 보강하려면 `gesture/data/image_data/` 디렉토리 아래에 제스처 이름으로 폴더를 만들고 이미지를 추가합니다.

**증분 학습을 위한 데이터**: `gesture/data/new_image_data/` 폴더에는 **직접 카메라로 촬영한 새로운 제스처 이미지**를 추가합니다. 이 폴더의 데이터는 기존 `image_data`와 함께 증분 학습에 사용됩니다.

MediaPipe Gesture Recognizer에 대한 자세한 정보는 [여기](https://ai.google.dev/edge/mediapipe/solutions/vision/gesture_recognizer?hl=ko)에서 확인할 수 있습니다.

### 3. 모델 학습 및 평가 (`main.py`)

`main.py`는 데이터 처리부터 모델 학습, 그리고 **성능 평가까지 한 번에 실행**하는 통합 스크립트입니다. `--mode` 인자로 실행 모드를 선택합니다.

*   **기본 모델 학습 및 평가**:
    `gesture/data/image_data/`의 이미지를 기반으로 모델을 학습시키고, 완료 즉시 성능 평가를 수행합니다. 평가 결과는 `gesture/analysis/results/basic_model_evaluation/` 폴더에 저장됩니다.
    ```bash
    python gesture/src/main.py --mode train
    ```

*   **통합 모델 업데이트 및 평가 (증분 학습)**:
    기존 데이터와 `gesture/data/new_image_data/`의 새로운 데이터를 함께 사용하여 모델을 업데이트하고, 완료 즉시 성능 평가를 수행합니다. 평가 결과는 `gesture/analysis/results/combine_model_evaluation/` 폴더에 저장됩니다.
    ```bash
    python gesture/src/main.py --mode update
    ```

### 4. 실시간 제스처 인식 (`live_test.py`)

`live_test.py`를 실행하여 웹캠을 통해 학습된 모델의 성능을 실시간으로 확인합니다. `--model_type` 인자를 사용하여 사용할 모델을 선택할 수 있습니다.

*   **Basic 모델로 테스트**:
    ```bash
    python gesture/src/utils/live_test.py --model_type basic
    ```

*   **통합 모델로 테스트**:
    ```bash
    python gesture/src/utils/live_test.py --model_type combine
    ```
ESC 키를 누르면 프로그램이 종료됩니다.

## 💻 시스템 요구 사항 및 의존성

이 프로젝트는 Python 3.10 이상 환경에서 테스트되었습니다. 주요 라이브러리 버전은 `requirements.txt` 파일을 참조하십시오.

*   **Python**: 3.10+
*   **TensorFlow**: 2.x
*   **MediaPipe**: 0.x
*   **OpenCV**: 4.x

---

## ⚙️ 작동 원리

1.  **데이터 처리 (`data_preprocessor.py`)**:
    -   이미지 폴더에서 이미지를 읽어 **멀티프로세싱**을 사용해 병렬로 손 랜드마크를 추출합니다.
    -   추출된 랜드마크를 이동, 크기, 회전에 대해 정규화하여 일관된 특징을 만듭니다.
    -   폴더 구조 기반으로 라벨 맵을 동적으로 생성하고, 처리된 데이터를 CSV 파일로 저장합니다.

2.  **데이터 관리 (`data_combiner.py` 및 `data_converter.py`)**:
    -   CSV 파일을 모델 학습에 적합한 NumPy 배열(`.npy`) 형태로 변환합니다.
    -   증분 학습 시, 기존 데이터와 신규 데이터를 병합하고 라벨 맵을 충돌 없이 통합합니다.

3.  **모델 학습 (`model_train.py`)**:
    -   `.npy` 데이터셋을 로드하여 CNN 모델을 학습시킵니다.
    -   **증분 학습** 시, 기존 모델을 불러와 새로운 데이터에 대해 미세 조정(fine-tuning)을 수행하며, `class_weight`를 적용하여 데이터 불균형을 자동 보정합니다.
    -   학습 완료 후, Keras 모델(`.keras`)과 TFLite 모델(`.tflite`)을 저장합니다.

4.  **모델 평가 (`evaluation.py`)**:
    -   `main.py`의 학습 파이프라인 마지막 단계에서 자동으로 실행됩니다.
    -   `ModelEvaluator` 클래스가 저장된 모델과 테스트 데이터를 로드합니다.
    -   **성능 리포트(.txt)**, **혼동 행렬(.png)**, **ROC/PR 커브(.png)** 등 다양한 시각적, 정량적 평가 지표를 생성하여 `gesture/analysis/results/` 폴더에 저장합니다.

5.  **실시간 테스트 (`live_test.py`)**:
    -   경량화된 `.tflite` 모델을 로드하여 OpenCV로 받아온 웹캠 영상에 적용합니다.
    -   실시간으로 랜드마크를 추출 및 정규화하고, 모델을 통해 제스처를 예측하여 결과를 화면에 표시합니다.

---

## 🛠️ 주요 기술 스택

-   **Python**
-   **TensorFlow / Keras**: 모델 학습 및 추론
-   **MediaPipe**: 손 랜드마크 추출
-   **OpenCV**: 실시간 영상 처리
-   **NumPy, Pandas**: 데이터 처리
-   **Scikit-learn**: 데이터 분할
