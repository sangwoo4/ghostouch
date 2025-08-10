from app.core import celery_app
from app.worker import training_tasks
from celery.result import AsyncResult
from celery import chain

def start_new_training_job(model_code, landmarks) -> str:

    """
    :param model_code: 사용자 지정 모델 코드
    :param landmarks: 수집한 렌드마크
    :return: celery task id
    """
    print("model_code:", model_code)
    task = training_tasks.training_task.delay(model_code, landmarks)
    #
    # task_chain = chain(
    #     training_tasks.training_task.s(model_code, landmarks),
    #     training_tasks.upload_task.s()
    # )

    #result = task_chain.apply_async()
    return task.id

def get_job_status(task_id: str) -> dict:
    task_result = AsyncResult(task_id, app = celery_app)
    status = task_result.status
    result = None
    error_info = None
    progress = None

    if status == 'PROGRESS':
        progress = task_result.result
    elif task_result.ready():
        if task_result.successful():
            result = task_result.result
        elif task_result.failed():
            error_info = task_result.info

    return{
        "task_id": task_id,
        "status": status,
        "result": result,
        "error_info": error_info,
        "progress": progress,
    }
