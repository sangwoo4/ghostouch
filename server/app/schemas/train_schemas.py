from pydantic import BaseModel
from typing import List, Any, Optional

class TaskRequest(BaseModel):
    model_code: str
    landmarks: List[Any]
    gesture: str

class TaskResponse(BaseModel):
    task_id: str

class StatusResponse(BaseModel):
    task_id: str
    status: str
    progress: Optional[dict] = None
    result: Optional[Any] = None # 'result' 대신 'data'
    error_info: Optional[str] = None # 'error_info' 대신 'error'

