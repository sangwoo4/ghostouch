import os

class Config:
    # 프로젝트의 모든 설정을 관리하는 중앙 클래스입니다.
    # 모든 경로는 절대 경로로 관리하여 일관성을 유지합니다.
    # 01. 기본 경로 설정
    BASE_DIR = os.path.dirname(os.path.abspath(__file__))
    ROOT_DIR = os.path.dirname(BASE_DIR)
    DATA_DIR = os.path.join(ROOT_DIR, "data")
    MODELS_DIR = os.path.join(ROOT_DIR, "models")
    PROCESSED_DATA_DIR = os.path.join(DATA_DIR, "processed")

    # 02. 데이터 관련 설정
    IMAGE_DATA_DIR = os.path.join(DATA_DIR, "image_data")
    NEW_GESTURES_DIR = os.path.join(DATA_DIR, "new_gestures")

    # 03. 전처리 관련 설정
    LANDMARK_CSV_PATH = os.path.join(PROCESSED_DATA_DIR, "hand_landmarks.csv")

    # 04. 데이터 분할 관련 설정
    TRAIN_DATA_PATH = os.path.join(PROCESSED_DATA_DIR, "train_data.npy")
    TEST_DATA_PATH = os.path.join(PROCESSED_DATA_DIR, "test_data.npy")

    # 05. 모델 관련 설정
    MODEL_PATH = os.path.join(MODELS_DIR, "gesture_model.keras")
    TFLITE_MODEL_PATH = os.path.join(MODELS_DIR, "gesture_model.tflite")
    LABEL_MAP_PATH = os.path.join(MODELS_DIR, "label_map.json")

    # 06. 학습 관련 설정
    EPOCHS = 100
    BATCH_SIZE = 32
    LEARNING_RATE = 0.001
    
    # 07. 실시간 테스트 관련 설정
    CAM_WIDTH = 640
    CAM_HEIGHT = 480

# 사용 예시: from config import Config
# print(Config.MODEL_PATH)