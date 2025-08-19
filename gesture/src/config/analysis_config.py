import os

class AnalysisConfig:
    """
    프로젝트의 평가지표 및 시각화 관련 파일 경로 및 디렉토리 설정을 관리하는 클래스
    처리된 파일들 경로를 정의
    """
    # 기본 경로 디렉토리
    BASE_ANALYSIS_DIR = os.path.join('gesture', 'analysis', 'results')

    # basic 모델 결과 디렉토리
    BASIC_MODEL_EVALUATION_DIR = os.path.join(BASE_ANALYSIS_DIR, 'basic_model_evaluation')

    # combine 모델 결과 디렉토리
    COMBINE_MODEL_EVALUATION_DIR = os.path.join(BASE_ANALYSIS_DIR, 'combine_model_evaluation')
