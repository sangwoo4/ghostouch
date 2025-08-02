from fastapi import APIRouter

from app.services.training_service import start_new_training_job, get_job_status
from app.schemas.train_schemas import TaskRequest, TaskResponse, StatusResponse
router = APIRouter()

@router.post("/train", response_model=TaskResponse)
def train(request: TaskRequest):
    task_id = start_new_training_job(
        model_code=request.model_code,
        landmarks=request.landmarks,
    )

    return TaskResponse(task_id=task_id)

@router.get("/status/{task_id}", response_model=StatusResponse)
def get_task_status(task_id: str):
    status_info = get_job_status(task_id)

    return status_info
