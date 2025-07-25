import os

class Config:
    # 프로젝트의 모든 설정을 관리하는 중앙 클래스
    def __init__(self):
        self.BASE_DIR = os.path.dirname(os.path.abspath(__file__))
        self.PROJECT_ROOT = os.path.dirname(os.path.dirname(self.BASE_DIR))

        # 01. 기본 경로 설정
        self.DATA_DIR = os.path.join(self.PROJECT_ROOT, 'gesture', 'data')
        self.MODELS_DIR = os.path.join(self.PROJECT_ROOT, 'gesture', 'models')
        self.PROCESSED_DATA_DIR = os.path.join(self.DATA_DIR, 'processed')

        # 02. 데이터 소스별 경로
        self.BASIC_IMAGE_DATA_DIR = os.path.join(self.DATA_DIR, 'image_data')
        self.BASIC_LANDMARK_CSV_PATH = os.path.join(self.PROCESSED_DATA_DIR, 'basic_hand_landmarks.csv')
        self.BASIC_TRAIN_DATA_PATH = os.path.join(self.PROCESSED_DATA_DIR, 'basic_train_data.npy')
        self.BASIC_TEST_DATA_PATH = os.path.join(self.PROCESSED_DATA_DIR, 'basic_test_data.npy')

        self.TRANSFER_IMAGE_DATA_DIR = os.path.join(self.DATA_DIR, 'new_image_data')
        self.TRANSFER_LANDMARK_CSV_PATH = os.path.join(self.PROCESSED_DATA_DIR, 'transfer_hand_landmarks.csv')
        self.TRANSFER_TRAIN_DATA_PATH = os.path.join(self.PROCESSED_DATA_DIR, 'transfer_train_data.npy')
        self.TRANSFER_TEST_DATA_PATH = os.path.join(self.PROCESSED_DATA_DIR, 'transfer_test_data.npy')

        self.COMBINE_TRAIN_DATA_PATH = os.path.join(self.PROCESSED_DATA_DIR, 'combine_train_data.npy')
        self.COMBINE_TEST_DATA_PATH = os.path.join(self.PROCESSED_DATA_DIR, 'combine_test_data.npy')

        # 03. 모델 타입별 경로 (라이브 테스트용)
        self.TFLITE_MODEL_PATHS = {
            'basic': os.path.join(self.MODELS_DIR, 'basic_gesture_model.tflite'),
            'transfer': os.path.join(self.MODELS_DIR, 'transfer_gesture_model.tflite'),
            'combine': os.path.join(self.MODELS_DIR, 'combine_gesture_model.tflite'),
        }
        self.LABEL_MAP_PATHS = {
            'basic': os.path.join(self.MODELS_DIR, 'basic_label_map.json'),
            'transfer': os.path.join(self.MODELS_DIR, 'transfer_label_map.json'),
            'combine': os.path.join(self.MODELS_DIR, 'combine_label_map.json'),
        }
        self.KERAS_MODEL_PATHS = {
            'basic': os.path.join(self.MODELS_DIR, 'basic_gesture_model.keras'),
            'transfer': os.path.join(self.MODELS_DIR, 'transfer_gesture_model.keras'),
            'combine': os.path.join(self.MODELS_DIR, 'combine_gesture_model.keras'),
        }

        # 04. 학습 관련 설정
        self.EPOCHS = 1000
        self.BATCH_SIZE = 32
        self.LEARNING_RATE = 0.001
        self.TRANSFER_LEARNING_RATE = 0.0001

        # 05. 실시간 테스트 관련 설정
        self.CAM_WIDTH = 640
        self.CAM_HEIGHT = 480
        self.MIN_DETECTION_CONFIDENCE = 0.5
        self.MIN_TRACKING_CONFIDENCE = 0.5
        self.CONFIDENCE_THRESHOLD = 0.9
