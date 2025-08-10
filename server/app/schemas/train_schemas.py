from pydantic import BaseModel
from typing import List, Any, Optional

class TaskRequest(BaseModel):
    model_code: str
    landmarks: List[Any]

class TaskResponse(BaseModel):
    task_id: str

class StatusResponse(BaseModel):
    task_id: str
    status: str
    result: Optional[Any] = None
    error_info: Optional[str] = None
    progress: Optional[dict] = None

