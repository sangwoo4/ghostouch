import os


class PathConfig:
    def __init__(self, model_code: str, new_model_code: str, base_dir='.'):

        # 프로젝트 루트, 데이터, 모델, 처리된 데이터 디렉토리 설정 및 생성

        self.PROJECT_ROOT = os.path.abspath(base_dir)
        self.MODELS_DIR = os.path.join(self.PROJECT_ROOT, 'models')
        os.makedirs(self.MODELS_DIR, exist_ok=True)

        self.model_code = model_code
        self.new_model_code = new_model_code

        # 기존 모델(model_id)의 기본 디렉토리
        self.base_model_dir = os.path.join(self.MODELS_DIR, self.model_code)
        os.makedirs(self.base_model_dir, exist_ok=True)

        #새로 생성될 모델(new_model_code)의 디렉토리
        self.new_model_dir = os.path.join(self.MODELS_DIR, self.new_model_code)
        os.makedirs(self.new_model_dir, exist_ok=True)



        self.base_csv_path = os.path.join(self.base_model_dir, f"{model_code}_landmarks.csv")
        self.incremental_csv_path = os.path.join(self.MODELS_DIR, self.new_model_code)
        self.combined_csv_path = os.path.join(self.new_model_dir, self.new_model_code + '.csv')

        self.base_keras_model_path = os.path.join(self.base_model_dir, f"{model_code}_model.keras")
        self.combined_keras_model_path = os.path.join(self.new_model_dir, f"{new_model_code}_model.keras")
        self.tflite_model_path = os.path.join(self.new_model_dir, f"{new_model_code}_model.tflite")


        # self.base_model_dir = os.path.join(self.MODELS_DIR, self.model_code)
        # os.makedirs(self.base_model_dir, exist_ok=True)
        #
        # #새로 생성될 모델(new_model_code)의 디렉토리
        # self.new_model_dir = os.path.join(self.MODELS_DIR, self.new_model_code)
        # os.makedirs(self.new_model_dir, exist_ok=True)
        #
        # # ----기존 모델(model_id) 관련 경로----
        # # self.base_landmark_csv_path = os.path.join(self.model_base_dir, f"{model_id}_landmarks.csv") # 필요하면 주석 해제
        # self.base_test_data_path = os.path.join(self.base_model_dir, f"{model_code}_test.npy")
        # self.base_train_data_path = os.path.join(self.base_model_dir, f"{model_code}_train.npy")
        #
        # # ----새로운 모델(new_model_code) 관련 경로 ----
        # # 증분 학습 관련 경로
        # self.incremental_landmark_csv_path = os.path.join(self.new_model_dir, f"{new_model_code}_incremental_landmarks.csv")
        # self.incremental_train_data_path = os.path.join(self.new_model_dir,f"{new_model_code}_incremental_train.npy")
        # self.incremental_test_data_path = os.path.join(self.new_model_dir, f"{new_model_code}_incremental_test.npy")
        #
        # # 결합 학습 관련 경로
        # self.combine_train_data_path = os.path.join(self.new_model_dir,f"{new_model_code}_combine_train.npy")
        # self.combine_test_data_path = os.path.join(self.new_model_dir, f"{new_model_code}_combine_test.npy")
        #
        # # Keras 모델 파일 경로 정의
        # self.keras_model_paths = {
        #     'basic': os.path.join(self.base_model_dir, f"{model_code}_model.keras"),
        #     'combine': os.path.join(self.new_model_dir, f"{new_model_code}_model.keras"),
        # }
        # # TFLite 모델 파일 경로 정의
        # self.tflite_model_paths = {
        #     'combine': os.path.join(self.new_model_dir, f"{new_model_code}_model.tflite"),
        # }
        #
        # # 라벨 맵 경로 추가
        # self.base_label_path= os.path.join(self.base_model_dir, f"{model_code}_label_map.json")
        # self.incremental_label_path = os.path.join(self.new_model_dir, f"{new_model_code}_incremental_label_map.json")
        # self.combine_label_path = os.path.join(self.new_model_dir, f"{new_model_code}_combine_label_map.json")