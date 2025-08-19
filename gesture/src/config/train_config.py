class TrainConfig:
    """
    모델 학습 관련 하이퍼파라미터 설정을 관리하는 클래스
    """

    # 1. 학습 기본 설정
    EPOCHS = 1000
    BATCH_SIZE = 16
    LEARNING_RATE = 0.001
    
    # 2. 데이터 분할 설정
    TEST_SPLIT_SIZE = 0.2
    RANDOM_STATE = 42

    # 3. 콜백 설정
    # EarlyStopping: 검증 손실(val_loss)이 개선되지 않을 때 학습을 조기 종료
    ES_MONITOR = 'val_loss'
    ES_PATIENCE = 5
    ES_MIN_DELTA = 0.0001
    
    # ReduceLROnPlateau: 검증 손실(val_loss) 개선이 없을 때 학습률을 동적으로 감소
    LR_SCHEDULER_MONITOR = 'val_loss'
    LR_SCHEDULER_FACTOR = 0.5
    LR_SCHEDULER_PATIENCE = 5
    LR_SCHEDULER_MIN_LR = 0.00001

    # 4. TFLite 변환 설정
    TFLITE_REPRESENTATIVE_DATASET_SAMPLE_SIZE = 300
    TFLITE_SHUFFLE_BUFFER_SIZE = 10000
