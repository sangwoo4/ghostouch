# --- 1단계: 빌드 환경 (Builder) ---
# 여기서는 라이브러리를 설치하기 위한 모든 도구를 사용합니다.
FROM python:3.10 as builder

WORKDIR /app

# 시스템 의존성 설치 (빌드에 필요)
RUN apt-get update && \
    apt-get install -y --no-install-recommends gcc libffi-dev libssl-dev build-essential && \
    rm -rf /var/lib/apt/lists/*

# requirements.txt를 먼저 복사하여 Docker 캐시를 활용합니다.
COPY requirements-dev.txt ./

# pip를 업그레이드하고, requirements.txt에 명시된 라이브러리들을 설치합니다.
# --no-deps는 이미 requirements.txt에 모든 의존성이 명시되어 있다는 가정 하에 사용합니다.
# 만약 그렇지 않다면 이 옵션을 제거하는 것이 안전합니다.
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements-dev.txt

# tensorflow는 별도로 설치합니다.
RUN pip install --no-cache-dir tensorflow==2.13.0


# --- 2단계: 최종 실행 환경 (Final Image) ---
# 여기서는 실제 애플리케이션 실행에 필요한 최소한의 것들만 포함합니다.
FROM python:3.10-slim

WORKDIR /app

# 빌드 환경(builder)에서 설치된 파이썬 라이브러리들만 복사해옵니다.
# site-packages 디렉토리의 위치는 파이썬 버전에 따라 다를 수 있습니다.
COPY --from=builder /usr/local/bin /usr/local/bin
COPY --from=builder /usr/local/lib/python3.10/site-packages /usr/local/lib/python3.10/site-packages

ENV PATH=/usr/local/bin:$PATH
# 앱 소스 코드를 복사합니다.
COPY app/ ./app/

# 8000번 포트를 외부에 노출합니다.
EXPOSE 8000

# 애플리케이션을 실행합니다.
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]