from fastapi import APIRouter

from app.services.training_service import start_new_training_job, get_job_status
from app.schemas.train_schemas import TaskRequest, TaskResponse, StatusResponse
router = APIRouter()

@router.post("/train", response_model=TaskResponse)
def train(request: TaskRequest):
    """
    새로운 모델 학습 Task를 시작합니다.

    Args:
        request(TaskRequest): model code, landmark, gesture name

    Returns:
          TaskResponse: 생성된 Celery 작업의 ID
    """

    task_id = start_new_training_job(
        model_code=request.model_code,
        landmarks=request.landmarks,
        gesture = request.gesture
    )

    return TaskResponse(task_id=task_id)

@router.get("/status/{task_id}", response_model=StatusResponse)
def get_task_status(task_id: str):
    """
    지덩된 작업 ID의 현재 상태를 조회합니다.

    Args:
        task_id(str): 상태를 조회할 Celery Task ID

    Returns:
        StatusResponse: 작업의 현재상태, 결과 또는 에러 정보를 포함하는 응답 모델

    """
    status_info = get_job_status(task_id)

    return status_info
