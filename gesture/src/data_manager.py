import numpy as np
import pandas as pd
from sklearn.model_selection import train_test_split
import logging
import os
from config import Config

logger = logging.getLogger(__name__)

class DataManager:
    # 데이터 로드, 분할 및 저장을 관리
    def __init__(self, config: Config, csv_paths: list = None, train_data_path: str = None, test_data_path: str = None):
        self.config = config
        self.landmark_csv_paths = csv_paths if csv_paths else [self.config.BASIC_LANDMARK_CSV_PATH]
        self.train_data_path = train_data_path if train_data_path else self.config.BASIC_TRAIN_DATA_PATH
        self.test_data_path = test_data_path if test_data_path else self.config.BASIC_TEST_DATA_PATH

    def process_data(self):
        # CSV에서 데이터를 로드하고, 학습/테스트용으로 분할하여 저장
        df = self._load_from_csv()
        labels = df["label"].to_numpy(dtype=str)
        features = df.drop(columns=["label"]).to_numpy(dtype=np.float32)
        
        X_train, X_test, y_train, y_test = self._split_data(features, labels)
        self._save_data(X_train, y_train, self.train_data_path)
        self._save_data(X_test, y_test, self.test_data_path)
        logger.info("----- 데이터 분할 및 저장 완료!")

    def _load_from_csv(self):
        # 여러 CSV 파일에서 데이터프레임을 로드하고 결합
        dfs = []
        for path in self.landmark_csv_paths:
            if os.path.exists(path):
                dfs.append(pd.read_csv(path))
            else:
                logger.warning(f"----- CSV 파일을 찾을 수 없습니다: {path}")
        if not dfs:
            raise FileNotFoundError("----- 로드할 CSV 파일이 없습니다.")
        return pd.concat(dfs, ignore_index=True)

    def _split_data(self, X, y):
        # 데이터를 학습 및 테스트 세트로 분할
        return train_test_split(X, y, test_size=0.2, random_state=42, stratify=y)

    def _save_data(self, X, y, path):
        # 특징과 라벨을 결합하여 Numpy 파일로 저장
        data = np.column_stack((X, y.reshape(-1, 1)))
        np.save(path, data)