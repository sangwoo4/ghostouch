import os

class Config:
    # 프로젝트의 모든 설정을 관리하는 중앙 클래스.
    # 경로, 하이퍼파라미터, 모델 설정 등을 포함합니다.

    def __init__(self):
        # 기본 경로 설정

        self.BASE_DIR = os.path.dirname(os.path.abspath(__file__))
        self.PROJECT_ROOT = os.path.dirname(os.path.dirname(self.BASE_DIR))

        # 01. 데이터 및 모델 폴더 경로
        self.DATA_DIR = os.path.join(self.PROJECT_ROOT, 'gesture', 'data')
        self.MODELS_DIR = os.path.join(self.PROJECT_ROOT, 'gesture', 'models')
        self.PROCESSED_DATA_DIR = os.path.join(self.DATA_DIR, 'processed')

        # 02. 'basic' 모드 데이터셋 경로

        self.BASIC_IMAGE_DATA_DIR = os.path.join(self.DATA_DIR, 'image_data')
        self.BASIC_LANDMARK_CSV_PATH = os.path.join(self.PROCESSED_DATA_DIR, 'basic_hand_landmarks.csv')
        self.BASIC_TRAIN_DATA_PATH = os.path.join(self.PROCESSED_DATA_DIR, 'basic_train_data.npy')
        self.BASIC_TEST_DATA_PATH = os.path.join(self.PROCESSED_DATA_DIR, 'basic_test_data.npy')

        # 'update' 모드 데이터셋 경로

        self.INCREMENTAL_IMAGE_DATA_DIR = os.path.join(self.DATA_DIR, 'new_image_data')
        self.INCREMENTAL_LANDMARK_CSV_PATH = os.path.join(self.PROCESSED_DATA_DIR, 'incremental_hand_landmarks.csv')
        self.INCREMENTAL_TRAIN_DATA_PATH = os.path.join(self.PROCESSED_DATA_DIR, 'incremental_train_data.npy')
        self.INCREMENTAL_TEST_DATA_PATH = os.path.join(self.PROCESSED_DATA_DIR, 'incremental_test_data.npy')

        # 'update' 모드 최종 데이터셋 경로

        self.COMBINE_TRAIN_DATA_PATH = os.path.join(self.PROCESSED_DATA_DIR, 'combine_train_data.npy')
        self.COMBINE_TEST_DATA_PATH = os.path.join(self.PROCESSED_DATA_DIR, 'combine_test_data.npy')

        # 03. 모델 및 라벨맵 경로

        self.TFLITE_MODEL_PATHS = {
            'basic': os.path.join(self.MODELS_DIR, 'basic_gesture_model.tflite'),
            'combine': os.path.join(self.MODELS_DIR, 'combine_gesture_model.tflite'),
        }
        # 각 데이터셋의 라벨(이름)과 정수(인덱스)를 매핑한 JSON 파일 경로

        self.LABEL_MAP_PATHS = {
            'basic': os.path.join(self.MODELS_DIR, 'basic_label_map.json'),
            'incremental': os.path.join(self.MODELS_DIR, 'incremental_label_map.json'),
            'combine': os.path.join(self.MODELS_DIR, 'combine_label_map.json'),
        }
        # 학습에 사용될 Keras 모델 경로

        self.KERAS_MODEL_PATHS = {
            'basic': os.path.join(self.MODELS_DIR, 'basic_gesture_model.keras'),
            'combine': os.path.join(self.MODELS_DIR, 'combine_gesture_model.keras'),
        }

        # 04. 모델 학습 관련 하이퍼파라미터

        self.EPOCHS = 500  # 에포크
        self.BATCH_SIZE = 32  # 배치 크기
        self.LEARNING_RATE = 0.001  # 'basic' 학습률
        self.INCREMENTAL_LEARNING_RATE = 0.0001  # 'update' 학습률

        # 05. 실시간 테스트(live_test.py) 관련 설정

        self.CAM_HEIGHT = 480  # 웹캠 해상도 높이
        self.CAM_WIDTH = 640  # 웹캠 해상도 너비
        self.MIN_DETECTION_CONFIDENCE = 0.5  # 최소 손 감지 신뢰도
        self.MIN_TRACKING_CONFIDENCE = 0.5  # 최소 손 추적 신뢰도
        self.CONFIDENCE_THRESHOLD = 0.8  # 제스처 예측 결과에 대한 최소 신뢰도 임계값
