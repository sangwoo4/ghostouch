import os

class FileConfig:
    """
    프로젝트의 모델 및 학습 관련 파일 경로 및 디렉토리 설정을 관리하는 클래스
    데이터, 모델, 처리된 파일 등의 경로를 정의
    """
    def __init__(self):
        # 현재 파일의 디렉토리 (gesture/src/config)
        self.BASE_DIR = os.path.dirname(os.path.abspath(__file__))

        # 프로젝트의 루트 디렉토리 (Gesture_Model)
        self.PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(self.BASE_DIR)))

        # 01. 기본 경로 설정
        self.DATA_DIR = os.path.join(self.PROJECT_ROOT, 'gesture', 'data')
        self.MODELS_DIR = os.path.join(self.PROJECT_ROOT, 'gesture', 'models')
        self.PROCESSED_DATA_DIR = os.path.join(self.DATA_DIR, 'processed')

        # 02. 데이터 소스별 경로
        self.BASIC_IMAGE_DATA_DIR = os.path.join(self.DATA_DIR, 'image_data')

        # 02-1. 기본(basic) 데이터 관련 경로
        self.BASIC_LANDMARK_CSV_PATH = os.path.join(self.PROCESSED_DATA_DIR, 'basic_hand_landmarks.csv')
        self.BASIC_DATA_PATH = os.path.join(self.PROCESSED_DATA_DIR, 'basic_data.npy')

        # 02-2. 증분(incremental) 데이터 관련 경로
        self.INCREMENTAL_IMAGE_DATA_DIR = os.path.join(self.DATA_DIR, 'new_image_data')
        self.INCREMENTAL_LANDMARK_CSV_PATH = os.path.join(self.PROCESSED_DATA_DIR, 'incremental_hand_landmarks.csv')
        self.INCREMENTAL_DATA_PATH = os.path.join(self.PROCESSED_DATA_DIR, 'incremental_data.npy')

        # 02-3. 결합(combine) 데이터 관련 경로 (basic + incremental)
        self.COMBINE_DATA_PATH = os.path.join(self.PROCESSED_DATA_DIR, 'combine_data.npy')

        # 03. 모델 타입별 경로 (라이브 테스트 및 학습용)
        # 03-1. # 03. TFLite 타입별 경로 
        self.TFLITE_MODEL_PATHS = {
            'basic': os.path.join(self.MODELS_DIR, 'basic_gesture_model.tflite'),
            'combine': os.path.join(self.MODELS_DIR, 'combine_gesture_model.tflite'),
        }
        # 03-2. # 03. JSON 타입별 경로 
        self.LABEL_MAP_PATHS = {
            'basic': os.path.join(self.MODELS_DIR, 'basic_label_map.json'),
            'incremental': os.path.join(self.MODELS_DIR, 'incremental_label_map.json'),
            'combine': os.path.join(self.MODELS_DIR, 'combine_label_map.json'),
        }
        # 03-3. # 03. Keras 타입별 경로 
        self.KERAS_MODEL_PATHS = {
            'basic': os.path.join(self.MODELS_DIR, 'basic_gesture_model.keras'),
            'combine': os.path.join(self.MODELS_DIR, 'combine_gesture_model.keras'),
        }