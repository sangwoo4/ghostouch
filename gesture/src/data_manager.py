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

            return data[:, :-1].astype(np.float32), data[:, -1].astype(int) # 라벨을 명시적으로 정수형
        except Exception as e:
            logger.error(f"----- NPY 파일 로드 중 오류 발생 ({file_path}): {e}")
            return None, None

    def load_and_combine_all_datasets(self, combined_map: dict, basic_map: dict, incremental_map: dict):
        all_data_paths = {
            "basic_train": self.config.BASIC_TRAIN_DATA_PATH,
            "basic_test": self.config.BASIC_TEST_DATA_PATH,
            "incremental_train": self.config.INCREMENTAL_TRAIN_DATA_PATH,
            "incremental_test": self.config.INCREMENTAL_TEST_DATA_PATH
        }
        all_original_maps = {
            "basic": basic_map,
            "incremental": incremental_map
        }

        final_datasets = {"train_X": [], "train_y": [], "test_X": [], "test_y": []}

        for data_type in ["train", "test"]:
            for dataset_name in ["basic", "incremental"]:
                npy_path = all_data_paths.get(f"{dataset_name}_{data_type}")
                original_map = all_original_maps.get(dataset_name)

                if not npy_path or not os.path.exists(npy_path):
                    logger.warning(f"----- NPY 파일을 찾을 수 없습니다: {npy_path}")
                    continue
                if not original_map:
                    logger.warning(f"----- 원본 라벨맵 '{dataset_name}'이(가) 제공되지 않았습니다.")
                    continue

                X, y_original_numeric_labels = self._load_npy_data(npy_path)
                if X is None:
                    continue

                # 원본 숫자 라벨을 문자열 라벨로 변환 (original_map을 뒤집어 사용)
                index_to_original_label_map = {v: k for k, v in original_map.items()}
                
                y_combined_numeric_labels = []
                X_valid = []
                for i, original_numeric_label in enumerate(y_original_numeric_labels):
                    string_label = index_to_original_label_map.get(original_numeric_label)
                    if string_label is not None and string_label in combined_map:
                        y_combined_numeric_labels.append(combined_map[string_label])
                        X_valid.append(X[i])
                    else:
                        logger.warning(f"----- 라벨 '{original_numeric_label}' ({string_label})이(가) 통합 라벨맵에 없거나 유효하지 않습니다. 데이터에서 제외합니다.")

                if not X_valid:
                    logger.warning(f"----- {dataset_name}_{data_type} 데이터셋에서 유효한 라벨을 가진 데이터가 없습니다. 건너뜁니다.")
                    continue

                final_datasets[f"{data_type}_X"].append(np.array(X_valid))
                final_datasets[f"{data_type}_y"].append(np.array(y_combined_numeric_labels, dtype=int))

        if not final_datasets["train_X"] or not final_datasets["test_X"]:
            logger.error("데이터셋을 병합할 수 없습니다. 하나 이상의 npy 파일이 비어있거나 없습니다.")
            return None, None, None, None

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

    def load_data_grouped_by_label(self, npy_path: str, label_map: dict):
        # NPY 파일에서 데이터를 로드하고, 라벨 맵을 사용하여 라벨별로 그룹화
        X, y_numeric_labels = self._load_npy_data(npy_path)
        if X is None:
            return {}

        # 숫자 라벨을 문자열 라벨로 변환
        index_to_label_map = {v: k for k, v in label_map.items()}
        y_string_labels = [index_to_label_map.get(num_label) for num_label in y_numeric_labels]

        grouped_data = {}
        for i, str_label in enumerate(y_string_labels):
            if str_label is None:
                continue
            if str_label not in grouped_data:
                grouped_data[str_label] = []
            grouped_data[str_label].append(X[i])

        for label, vectors in grouped_data.items():
            grouped_data[label] = np.array(vectors)

        return grouped_data

    def combine_and_save_data(self, combined_map: dict, basic_map: dict, incremental_map: dict):
        # 기존 및 증분 데이터셋을 결합하고, 최종 학습 및 테스트 NPY 파일을 저장
        
        # 모든 데이터셋 로드 및 통합
        final_train_X, final_train_y, final_test_X, final_test_y = \
            self.load_and_combine_all_datasets(combined_map, basic_map, incremental_map)

        if final_train_X is None or final_test_X is None:
            logger.error("데이터 통합에 실패했습니다. 모델 학습을 진행할 수 없습니다.")
            return

        # 통합된 데이터셋 저장
        self.save_combined_datasets(final_train_X, final_train_y, final_test_X, final_test_y)

    def create_basic_npy_datasets(self, csv_path: str, train_npy_path: str, test_npy_path: str, label_map: dict, test_size: float = 0.2, random_state: int = 42):
        logger.info(f"----- CSV 파일로부터 기본 NPY 데이터셋 생성 중: {csv_path}")
        if not os.path.exists(csv_path):
            raise FileNotFoundError(f"CSV 파일을 찾을 수 없습니다: {csv_path}")

        df = pd.read_csv(csv_path)
        X = df.drop(columns=['label']).values
        y_string_labels = df['label'].values # 문자열 라벨

        # 문자열 라벨을 숫자형 라벨로 변환
        y_numeric_labels = np.array([label_map[label] for label in y_string_labels], dtype=int)

        X_filtered = X
        y_filtered = y_numeric_labels

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