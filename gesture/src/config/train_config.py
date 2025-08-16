class TrainConfig:
    """
    모델 학습 관련 하이퍼파라미터 설정을 관리하는 클래스
    에포크, 배치 크기, 학습률 정의
    """
    # 학습 관련 설정
    EPOCHS = 1000
    BATCH_SIZE = 16
    LEARNING_RATE = 0.001
    INCREMENTAL_LEARNING_RATE = 0.001