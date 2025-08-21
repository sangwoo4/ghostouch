# Ghostouch - Backend Server 👻
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Ghostouch 프로젝트의 백엔드 서버 파트입니다. FastAPI를 기반으로 구축되었으며, 클라이언트로부터 수신한 손 랜드마크(hand landmark) 데이터를 전처리하고 증분 학습(incremental learning)을 수행하여 클라이언트에 맞춤형 모델을 배포하는 역할을 합니다.

## 아키텍처

-   **Web Framework:** `FastAPI`를 사용하여 비동기 API 서버를 구축했습니다.
-   **Asynchronous Tasks:** `Celery`와 `Redis`를 사용하여 모델 학습과 같은 시간이 많이 소요되는 작업을 백그라운드에서 비동기적으로 처리합니다.
-   **ML Pipeline:** 클라이언트로부터 받은 랜드마크 데이터를 `MediaPipe` 모델을 통해 증분 학습하여 개인화된 제스처 인식 모델을 생성합니다.
-   **Model Deployment:** 학습된 모델은 `Firebase Storage`를 통해 클라이언트에 안전하게 배포됩니다.
-   **Web Server:** `Uvicorn`을 ASGI 서버로 사용합니다.

## 기술 스택

-   **Language:** Python 3.10
-   **Framework:** FastAPI, Celery
-   **ML:** MediaPipe
-   **Database/Broker:** Redis
-   **Deployment:** Docker, Firebase (Storage, Admin SDK)
-   **Web Server:** Uvicorn

## 프로젝트 구조

```
server/
├── app/
│   ├── api/       # API 엔드포인트 로직
│   ├── core/      # 핵심 설정 (Celery, FastAPI 앱 등)
│   ├── schemas/   # 데이터 유효성 검사 스키마 (Pydantic)
│   ├── services/  # 비즈니스 로직 (Firebase, 모델 학습 등)
│   └── worker/    # Celery 워커 작업 정의
├── Dockerfile
├── requirements.txt
└── README.md
```

## 시작하기

### 사전 준비

1.  **Firebase 설정:**
    -   Firebase 프로젝트를 생성하고, 서비스 계정 키(`*.json` 파일)를 발급받습니다.
    -   Firebase Storage 버킷 이름을 확인합니다.
2.  **.env 파일 생성:**
    -   `server` 디렉토리 최상단에 `.env` 파일을 생성하고 아래 내용을 채워넣습니다.
    ```env
    FIREBASE_CREDENTIALS="your-firebase-key.json"
    FIREBASE_STORAGE_BUCKET="your-firebase-storage-bucket-name"
    ```

### 옵션 1: Docker를 사용하여 실행 (권장)

1.  **Docker 이미지 빌드:**
    ```bash
    docker build -t [프로젝트명:tag]
    ```
2.  **Docker 컨테이너 실행:**
    ```bash
    docker run --rm --env-file ./.env -p [port:port] -v FIREBASE_CREDENTIALS=/app/serviceAccountKey.json
FIREBASE_STORAGE_BUCKET=[firebase key josn 경로] [프로젝트명:tag]
    ```

### 옵션 2: 로컬 환경에서 직접 실행 (개발용)

1.  **Celery 설정:**
    - `app/core/celery_app.py` 파일의 주석 안내에 따라 Broker URL 등을 설정합니다.

2.  **가상 환경 및 의존성 설치:**
    ```bash
    python -m venv venv
    source venv/bin/activate
    pip install -r requirements.txt
    ```

3.  **서버 및 워커 실행:**
    -   각각의 터미널에서 다음 명령어를 실행합니다.
    ```bash
    # 터미널 1: FastAPI 서버 실행
    uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload

    # 터미널 2: Celery 워커 실행
    celery -A app.core.celery_app.celery_app worker -l info
    ```

## API Endpoints

전체 API 명세는 아래 링크에서 확인하실 수 있습니다.

-   **[Postman API Documentation](https://documenter.getpostman.com/view/28368657/2sB3BGFURM)**

## 라이선스

이 프로젝트는 MIT 라이선스를 따릅니다.
