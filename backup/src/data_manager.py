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
            "basic": self.config.BASIC_DATA_PATH,
            "incremental": self.config.INCREMENTAL_DATA_PATH
        }
        all_original_maps = {
            "basic": basic_map,
            "incremental": incremental_map
        }

        all_X = []
        all_y = []

        for dataset_name in ["basic", "incremental"]:
            npy_path = all_data_paths.get(dataset_name)
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

            index_to_original_label_map = {v: k for k, v in original_map.items()}
            
            for i, original_numeric_label in enumerate(y_original_numeric_labels):
                string_label = index_to_original_label_map.get(original_numeric_label)
                if string_label is not None and string_label in combined_map:
                    all_y.append(combined_map[string_label])
                    all_X.append(X[i])
                else:
                    logger.warning(f"----- 라벨 '{original_numeric_label}' ({string_label})이(가) 통합 라벨맵에 없거나 유효하지 않습니다. 데이터에서 제외합니다.")

        if not all_X:
            logger.error("데이터셋을 병합할 수 없습니다. 하나 이상의 npy 파일이 비어있거나 없습니다.")
            return None, None

        return np.array(all_X), np.array(all_y, dtype=int)

    def save_combined_dataset(self, X, y):
        np.save(self.config.COMBINE_DATA_PATH, np.column_stack((X, y)))
        logger.info(f"----- 최종 통합 데이터 저장 완료: {self.config.COMBINE_DATA_PATH}")

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
        # 기존 및 증분 데이터셋을 결합하고, 최종 NPY 파일을 저장
        
        # 모든 데이터셋 로드 및 통합
        X, y = self.load_and_combine_all_datasets(combined_map, basic_map, incremental_map)

        if X is None:
            logger.error("데이터 통합에 실패했습니다. 모델 학습을 진행할 수 없습니다.")
            return

        # 통합된 데이터셋 저장
        self.save_combined_dataset(X, y)

    def create_npy_dataset(self, csv_path: str, npy_path: str, label_map: dict):
        logger.info(f"----- CSV 파일({csv_path})로부터 NPY 데이터셋 생성 중 -> {npy_path}")
        if not os.path.exists(csv_path):
            raise FileNotFoundError(f"CSV 파일을 찾을 수 없습니다: {csv_path}")

        df = pd.read_csv(csv_path)
        X = df.drop(columns=['label']).values
        y_string_labels = df['label'].values

        y_numeric_labels = np.array([label_map[label] for label in y_string_labels], dtype=int)

        combined_data = np.column_stack((X, y_numeric_labels))
        
        np.save(npy_path, combined_data)
        logger.info(f"----- NPY 데이터 저장 완료: {npy_path}")

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