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
            logger.warning(f"----- NPY 파일을 찾을 수 없습니다: {file_path}")
            return None, None
        try:
            data = np.load(file_path, allow_pickle=True)
            return data[:, :-1].astype(np.float32), data[:, -1]
        except Exception as e:
            logger.error(f"----- NPY 파일 로드 중 오류 발생 ({file_path}): {e}")
            return None, None

    def load_and_combine_all_datasets(self, combined_map_path: str):
        # 0. 통합 라벨맵 로드
        try:
            with open(combined_map_path, 'r') as f:
                combined_map = json.load(f)
        except FileNotFoundError:
            logger.error(f"----- 통합 라벨맵을 찾을 수 없습니다: {combined_map_path}")
            return None, None, None, None

        # 1. 모든 데이터 로드 (기존 로직과 동일)
        all_data_paths = {
            "basic_train": self.config.BASIC_TRAIN_DATA_PATH,
            "basic_test": self.config.BASIC_TEST_DATA_PATH,
            "incremental_train": self.config.INCREMENTAL_TRAIN_DATA_PATH,
            "incremental_test": self.config.INCREMENTAL_TEST_DATA_PATH
        }
        all_original_maps = {
            "basic": self.config.LABEL_MAP_PATHS['basic'],
            "incremental": self.config.LABEL_MAP_PATHS['incremental']
        }

        final_datasets = {"train_X": [], "train_y": [], "test_X": [], "test_y": []}

        for data_type in ["train", "test"]:
            for dataset_name in ["basic", "incremental"]:
                npy_path = all_data_paths.get(f"{dataset_name}_{data_type}")
                if not npy_path or not os.path.exists(npy_path):
                    logger.warning(f"----- NPY 파일을 찾을 수 없습니다: {npy_path}")
                    continue
                
                X, y_original_indices = self._load_npy_data(npy_path)
                if X is None:
                    continue

                # 원본 라벨맵 로드
                original_map_path = all_original_maps[dataset_name]
                with open(original_map_path, 'r') as f:
                    original_map = json.load(f)
                
                # 인덱스를 문자열 라벨로 변환
                index_to_str_map = {v: k for k, v in original_map.items()}
                y_str_labels = [index_to_str_map.get(idx) for idx in y_original_indices]

                # 문자열 라벨을 통합 인덱스로 변환
                y_combined_indices = [combined_map.get(s_label) for s_label in y_str_labels if s_label is not None]
                
                # 유효한 라벨이 있는 데이터만 필터링
                valid_mask = [s_label is not None for s_label in y_str_labels]
                X_filtered = X[valid_mask]

                final_datasets[f"{data_type}_X"].append(X_filtered)
                final_datasets[f"{data_type}_y"].append(np.array(y_combined_indices))

        if not final_datasets["train_X"] or not final_datasets["test_X"]:
            logger.error("데이터셋을 병합할 수 없습니다. 하나 이상의 npy 파일이 비어있거나 없습니다.")
            return None, None, None, None

        # 2. 데이터 병합
        final_train_X = np.vstack(final_datasets["train_X"])
        final_train_y = np.concatenate(final_datasets["train_y"])
        final_test_X = np.vstack(final_datasets["test_X"])
        final_test_y = np.concatenate(final_datasets["test_y"])

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
        y = df['label'].values # 문자열 라벨

        label_map_path_for_csv = self.config.LABEL_MAP_PATHS['basic'] if 'basic' in csv_path else self.config.LABEL_MAP_PATHS['incremental']
        try:
            with open(label_map_path_for_csv, 'r') as f:
                label_map = json.load(f)
        except FileNotFoundError:
            logger.error(f"----- 라벨 맵 파일을 찾을 수 없습니다: {label_map_path_for_csv}")
            raise

        y_encoded = y # 이미 정수 라벨로 인코딩되어 있음

        none_label_int = label_map.get("none", -1)

        if none_label_int != -1:
            mask = (y_encoded != none_label_int)
            X_filtered = X[mask]
            y_filtered = y_encoded[mask]
            logger.info(f"----- 'none' 라벨 데이터 {len(y_encoded) - len(y_filtered)}개 제외 완료.")
        else:
            X_filtered = X
            y_filtered = y_encoded
            logger.warning("----- 라벨 맵에서 'none' 라벨을 찾을 수 없습니다. 'none' 데이터 필터링을 건너뜁니다.")

        if len(y_filtered) == 0:
            logger.error("----- 'none' 라벨 필터링 후 학습/테스트 데이터가 없습니다. 데이터셋을 확인하세요.")
            raise ValueError("----- 'none' label 이 후 데이터 및 라벨이 존재하지 않습니다.")

        X_train, X_test, y_train, y_test = train_test_split(X_filtered, y_filtered, test_size=test_size, random_state=random_state, stratify=y_filtered)

        np.save(train_npy_path, np.column_stack((X_train, y_train)))
        logger.info(f"----- 기본 학습 데이터 저장 완료: {train_npy_path}")
        np.save(test_npy_path, np.column_stack((X_test, y_test)))
        logger.info(f"----- 기본 테스트 데이터 저장 완료: {test_npy_path}")

    @staticmethod
    def combine_label_maps(basic_map_path: str, incremental_map_path: str, combined_map_save_path: str):
        combined_map = {}
        current_idx = 0

        if os.path.exists(basic_map_path):
            with open(basic_map_path, 'r') as f:
                basic_map = json.load(f)
                for label_str in sorted(basic_map.keys()):
                    if label_str not in combined_map:
                        combined_map[label_str] = current_idx
                        current_idx += 1

        if os.path.exists(incremental_map_path):
            with open(incremental_map_path, 'r') as f:
                incremental_map = json.load(f)
                
                for label_str in sorted(incremental_map.keys()):
                    if label_str not in combined_map:
                        combined_map[label_str] = current_idx
                        current_idx += 1

        with open(combined_map_save_path, 'w') as f:
            json.dump(combined_map, f, indent=4)
        logger.info(f"----- 통합 라벨이 저장되었습니다.: {combined_map_save_path}")
        return combined_map
