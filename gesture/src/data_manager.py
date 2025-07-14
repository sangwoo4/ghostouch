import numpy as np
import pandas as pd
from sklearn.model_selection import train_test_split
import logging
from config import Config

logger = logging.getLogger(__name__)

class DataManager:
    # 데이터 로드, 분할 및 저장을 관리합니다.
    def __init__(self, config: Config):
        self.config = config

    def process_data(self):
        # CSV에서 데이터를 로드하고, 학습/테스트용으로 분할하여 저장합니다.
        df = self._load_from_csv()
        labels = df["label"].to_numpy(dtype=str)
        features = df.drop(columns=["label"]).to_numpy(dtype=np.float32)
        
        X_train, X_test, y_train, y_test = self._split_data(features, labels)
        self._save_data(X_train, y_train, self.config.TRAIN_DATA_PATH)
        self._save_data(X_test, y_test, self.config.TEST_DATA_PATH)
        logger.info("----- 데이터 분할 및 저장 완료!")

    def _load_from_csv(self):
        # CSV 파일에서 데이터프레임을 로드합니다
        return pd.read_csv(self.config.LANDMARK_CSV_PATH)

    def _split_data(self, X, y):
        # 데이터를 학습 및 테스트 세트로 분할합니다.
        return train_test_split(X, y, test_size=0.2, random_state=42, stratify=y)

    def _save_data(self, X, y, path):
        # 특징과 라벨을 결합하여 Numpy 파일로 저장합니다.
        data = np.column_stack((X, y.reshape(-1, 1)))
        np.save(path, data)