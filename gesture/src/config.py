import os

class Config:
    # 프로젝트의 모든 설정을 관리하는 중앙 클래스
    # 모든 경로는 절대 경로로 관리하여 일관성을 유지
    def __init__(self):
        self.BASE_DIR = os.path.dirname(os.path.abspath(__file__))
        self.PROJECT_ROOT = os.path.dirname(os.path.dirname(self.BASE_DIR)) 

        # 01. 기본 경로 설정 (PROJECT_ROOT 기준)
        self.GESTURE_DIR = os.path.join(self.PROJECT_ROOT, 'gesture')
        self.DATA_DIR = os.path.join(self.GESTURE_DIR, 'data')
        self.MODELS_DIR = os.path.join(self.GESTURE_DIR, 'models')
        self.PROCESSED_DATA_DIR = os.path.join(self.DATA_DIR, 'processed')

        # 02. 데이터 관련 설정
        # 기본 학습 경로
        self.BASIC_IMAGE_DATA_DIR = os.path.join(self.DATA_DIR, 'image_data')
        self.BASIC_LANDMARK_CSV_PATH = os.path.join(self.PROCESSED_DATA_DIR, 'basic_hand_landmarks.csv')
        self.BASIC_TRAIN_DATA_PATH = os.path.join(self.PROCESSED_DATA_DIR, 'basic_train_data.npy')
        self.BASIC_TEST_DATA_PATH = os.path.join(self.PROCESSED_DATA_DIR, 'basic_test_data.npy')
        self.BASIC_MODEL_PATH = os.path.join(self.MODELS_DIR, 'basic_gesture_model.keras')
        self.BASIC_TFLITE_MODEL_PATH = os.path.join(self.MODELS_DIR, 'basic_gesture_model.tflite')
        self.BASIC_LABEL_MAP_PATH = os.path.join(self.MODELS_DIR, 'basic_label_map.json')

        # 전이 학습 경로
        self.TRANSFER_IMAGE_DATA_DIR = os.path.join(self.DATA_DIR, 'new_image_data')
        self.TRANSFER_LANDMARK_CSV_PATH = os.path.join(self.PROCESSED_DATA_DIR, 'transfer_hand_landmarks.csv')
        self.TRANSFER_TRAIN_DATA_PATH = os.path.join(self.PROCESSED_DATA_DIR, 'transfer_train_data.npy')
        self.TRANSFER_TEST_DATA_PATH = os.path.join(self.PROCESSED_DATA_DIR, 'transfer_test_data.npy')
        self.TRANSFER_MODEL_PATH = os.path.join(self.MODELS_DIR, 'transfer_gesture_model.keras')
        self.TRANSFER_TFLITE_MODEL_PATH = os.path.join(self.MODELS_DIR, 'transfer_gesture_model.tflite')
        self.TRANSFER_LABEL_MAP_PATH = os.path.join(self.MODELS_DIR, 'transfer_label_map.json')

        # 06. 학습 관련 설정
        self.EPOCHS = 1000
        self.BATCH_SIZE = 32
        self.LEARNING_RATE = 0.001
        
        # 07. 실시간 테스트 관련 설정
        self.CAM_WIDTH = 640
        self.CAM_HEIGHT = 480
        self.MIN_DETECTION_CONFIDENCE = 0.5
        self.MIN_TRACKING_CONFIDENCE = 0.5

# 사용 예시: from config import Config
# print(Config.MODEL_PATH)