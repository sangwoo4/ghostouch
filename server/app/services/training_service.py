from app.core import celery_app
from app.worker import training_tasks
from celery.result import AsyncResult

def start_new_training_job(model_code, landmarks, gesture) -> str:

    """
    :param model_code: 사용자 지정 모델 코드`
    :param landmarks: 수집한 렌드마크
    :param gesture: 학습할 제스처 이름
    :return: celery task id
    """
    task = training_tasks.training_task.delay(model_code, landmarks, gesture)

    return task.id




def get_job_status(task_id: str) -> dict:
    task_result = AsyncResult(task_id, app = celery_app)
    status = task_result.status
    
    # 반환될 필드들을 초기화합니다.
    progress = None
    result = None # 이전의 'result' 필드에 해당
    error = None # 이전의 'error_info' 필드에 해당

    if status == "PROGRESS":
        meta = task_result.info or {}
        progress = {
            "current_step": meta.get("current_step")
        }

    elif task_result.ready(): # 태스크가 최종 상태(SUCCESS 또는 FAILURE)에 도달했을 때
        if task_result.successful():
            # 태스크가 SUCCESS로 완료된 경우
            result = task_result.result # training_task의 최종 반환값 (dict)
            
            # 만약 이전 버전의 중복 처리 로직(SUCCESS로 반환)이 남아있다면 처리
            if isinstance(result, dict) and result.get("status_message") == "Duplicate data, operation skipped.":
                status = "DUPLICATE" # 상태를 DUPLICATE로 오버라이드

        else: # 태스크가 FAILURE 상태일 때
            error_traceback = task_result.traceback
            
            # DuplicateDataError인 경우 특별 처리
            if "DuplicateDataError" in error_traceback:
                status = "DUPLICATE" # 상태를 DUPLICATE로 오버라이드
                error = "제스처 중복"
            else:
                # 일반적인 실패
                error = "알 수 없는 오류 발생"

    return {
        "task_id": task_id,
        "status": status,
        "progress": progress,
        "result": result, # 최종 결과 데이터
        "error_info": error # 에러 상세 정보
    }