import os

class HparamsConfig:
    """프로젝트의 모든 경로와 하이퍼파라미터를 관리하는 설정 클래스."""
    def __init__(self):
        # 하이퍼파라미터 정의
        self.EPOCHS = 500
        self.BATCH_SIZE = 32
        self.INCREMENTAL_LEARNING_RATE = 0.0001
        self.DUP_THRESHOLD = 10.0 # 중복 허용 임계값 (%)