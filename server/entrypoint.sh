#!/bin/sh

# 1. Uvicorn을 사용하여 FastAPI 서버를 백그라운드에서 실행
uvicorn app.main:app --host 0.0.0.0 --port 8000 &

# 2. Celery 워커를 포어그라운드에서 실행
#    (이 프로세스가 컨테이너의 메인 프로세스가 됨)
celery -A app.core.celery_app worker -l info
