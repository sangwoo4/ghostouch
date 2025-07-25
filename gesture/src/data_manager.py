import numpy as np
import pandas as pd
from sklearn.model_selection import train_test_split
import logging
import os
from config import Config
import json

logger = logging.getLogger(__name__)

class DataManager:
    def __init__(self, config: Config):
        self.config = config

    def _load_npy_data(self, file_path: str):
        if not os.path.exists(file_path):
            logger.warning(f"NPY 파일을 찾을 수 없습니다: {file_path}")
            return None, None
        try:
            data = np.load(file_path, allow_pickle=True)
            return data[:, :-1].astype(np.float32), data[:, -1]
        except Exception as e:
            logger.error(f"NPY 파일 로드 중 오류 발생 ({file_path}): {e}")
            return None, None

    def load_and_combine_all_datasets(self):
        # 1. 모든 데이터 로드
        all_data = {
            name: self._load_npy_data(path) for name, path in {
                "basic_train": self.config.BASIC_TRAIN_DATA_PATH,
                "basic_test": self.config.BASIC_TEST_DATA_PATH,
                "transfer_train": self.config.TRANSFER_TRAIN_DATA_PATH,
                "transfer_test": self.config.TRANSFER_TEST_DATA_PATH
            }.items()
        }
        if any(data[0] is None for data in all_data.values()):
            logger.error("필수 npy 파일 중 일부가 존재하지 않아 처리를 중단합니다.")
            return None, None, None, None

        # 2. 데이터 병합
        final_train_X = np.vstack([all_data["basic_train"][0], all_data["transfer_train"][0]])
        final_train_y = np.concatenate([all_data["basic_train"][1], all_data["transfer_train"][1]])
        final_test_X = np.vstack([all_data["basic_test"][0], all_data["transfer_test"][0]])
        final_test_y = np.concatenate([all_data["basic_test"][1], all_data["transfer_test"][1]])

        return final_train_X, final_train_y, final_test_X, final_test_y

    def save_combined_datasets(self, final_train_X, final_train_y, final_test_X, final_test_y):
        np.save(self.config.COMBINE_TRAIN_DATA_PATH, np.column_stack((final_train_X, final_train_y)))
        logger.info(f"----- 최종 학습 데이터 저장 완료: {self.config.COMBINE_TRAIN_DATA_PATH}")
        np.save(self.config.COMBINE_TEST_DATA_PATH, np.column_stack((final_test_X, final_test_y)))
        logger.info(f"----- 최종 테스트 데이터 저장 완료: {self.config.COMBINE_TEST_DATA_PATH}")

    def create_basic_npy_datasets(self, csv_path: str, train_npy_path: str, test_npy_path: str, test_size: float = 0.2, random_state: int = 42):
        logger.info(f"----- CSV 파일로부터 기본 NPY 데이터셋 생성 중: {csv_path}")
        if not os.path.exists(csv_path):
            raise FileNotFoundError(f"CSV 파일을 찾을 수 없습니다: {csv_path}")

        df = pd.read_csv(csv_path)
        X = df.drop(columns=['label']).values
        y = df['label'].values

        # 라벨 인코딩 (문자열 라벨을 숫자로 변환)
        unique_labels = np.unique(y)
        label_to_int = {label: i for i, label in enumerate(unique_labels)}
        y_encoded = np.array([label_to_int[label] for label in y])

        X_train, X_test, y_train, y_test = train_test_split(X, y_encoded, test_size=test_size, random_state=random_state, stratify=y_encoded)

        np.save(train_npy_path, np.column_stack((X_train, y_train)))
        logger.info(f"----- 기본 학습 데이터 저장 완료: {train_npy_path}")
        np.save(test_npy_path, np.column_stack((X_test, y_test)))
        logger.info(f"----- 기본 테스트 데이터 저장 완료: {test_npy_path}")

    @staticmethod
    def combine_label_maps(basic_map_path: str, transfer_map_path: str, combined_map_save_path: str):
        combined_map = {}
        current_idx = 0

        if os.path.exists(basic_map_path):
            with open(basic_map_path, 'r') as f:
                basic_map = json.load(f)
                for label_str in sorted(basic_map.keys()):
                    if label_str not in combined_map:
                        combined_map[label_str] = current_idx
                        current_idx += 1

        if os.path.exists(transfer_map_path):
            with open(transfer_map_path, 'r') as f:
                transfer_map = json.load(f)
                for label_str in sorted(transfer_map.keys()):
                    if label_str not in combined_map:
                        combined_map[label_str] = current_idx
                        current_idx += 1

        with open(combined_map_save_path, 'w') as f:
            json.dump(combined_map, f, indent=4)
        logger.info(f"----- 통합 라벨이 저장되었습니다.: {combined_map_save_path}")
        return combined_map
