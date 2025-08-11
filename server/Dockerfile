# --- 1단계: 빌드 환경 (Builder) ---
# 여기서는 라이브러리를 설치하기 위한 모든 도구를 사용합니다.
FROM python:3.10 as builder

# 시스템 레벨의 의존성 설치 (라이브러리 빌드에 필요할 수 있음)
RUN apt-get update && apt-get install -y --no-install-recommends build-essential

WORKDIR /app

# requirements.txt를 먼저 복사하여 Docker 캐시를 활용합니다.
COPY requirements.txt ./

# pip를 업그레이드하고, requirements.txt에 명시된 라이브러리들을 설치합니다.
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt


# --- 2단계: 최종 실행 환경 (Final Image) ---
# 여기서는 실제 애플리케이션 실행에 필요한 최소한의 것들만 포함합니다.
FROM python:3.10-slim

WORKDIR /app

# 빌드 환경(builder)에서 설치된 파이썬 라이브러리들만 복사해옵니다.
COPY --from=builder /usr/local/lib/python3.10/site-packages /usr/local/lib/python3.10/site-packages
COPY --from=builder /usr/local/bin /usr/local/bin

ENV PATH=/usr/local/bin:$PATH
# 애플리케이션 소스 코드를 복사합니다. (.dockerignore에 명시된 파일 제외)
COPY . .

# entrypoint.sh 스크립트에 실행 권한을 부여합니다.
RUN chmod +x ./entrypoint.sh

# 8000번 포트를 외부에 노출합니다.
EXPOSE 8000

# entrypoint.sh 스크립트를 실행하여 앱을 시작합니다.
CMD ["./entrypoint.sh"]