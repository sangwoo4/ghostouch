from celery import Celery
from app.utils import firebase_util

# celery_app = Celery(
#     "worker",
#     broker="redis://localhost:6379/0", # 메시지 큐
#     backend="redis://localhost:6379/1", #결과 저장소로 사용
#     include=['app.worker.training_tasks']
# )

celery_app = Celery(
    "worker",
    broker="redis://host.docker.internal:6379/0", # 메시지 큐
    backend="redis://host.docker.internal:6379/1", #결과 저장소로 사용
    include=['app.worker.training_tasks']
)

celery_app.conf.update(
    result_expires = 300,
)