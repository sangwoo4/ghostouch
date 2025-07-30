import numpy as np
import pandas as pd
from sklearn.model_selection import train_test_split
import logging
import os
from config import Config
import json

logger = logging.getLogger(__name__)

class DataManager:
    # 데이터 로딩, 분할, 결합 등 데이터셋을 관리하는 클래스.
    # NPY, CSV 파일과 라벨 맵을 처리합니다.
    
    def __init__(self, config: Config):
        self.config = config

    def _load_npy_data(self, file_path: str):
        # NPY 파일에서 특징 벡터(X)와 라벨(y)을 로드합니다.
    
        if not os.path.exists(file_path):
            logger.warning(f"----- NPY 파일을 찾을 수 없습니다: {file_path}")
            return None, None
        try:
            data = np.load(file_path, allow_pickle=True)
            # 마지막 열은 라벨, 그 외는 특징 벡터

            return data[:, :-1].astype(np.float32), data[:, -1]
        except Exception as e:
            logger.error(f"----- NPY 파일 로드 중 오류 발생 ({file_path}): {e}")
            return None, None

    def load_vectors_only(self, file_path: str):
        # NPY 파일에서 특징 벡터(X)만 로드합니다. (중복 검사용)
        
        if not os.path.exists(file_path):
            logger.warning(f"----- 데이터 파일을 찾을 수 없음: {file_path}")
            return None
        try:
            data = np.load(file_path)
            if data.ndim < 2 or data.shape[1] <= 1:
                return np.array([])
            return data[:, :-1]
        except Exception as e:
            logger.error(f"----- NPY 파일 로드 중 오류 발생 {file_path}: {e}")
            return None

    def load_data_grouped_by_label(self, npy_path: str, label_map_path: str): 
        # NPY 파일과 라벨맵을 로드하여, 라벨 이름을 key로, 데이터 벡터 배열을 value로 갖는 딕셔너리를 반환합니다.
        # 이는 데이터셋 간의 중복을 라벨별로 검사할 때 유용합니다.

        if not all([os.path.exists(npy_path), os.path.exists(label_map_path)]):
            logger.warning(f"----- 데이터 또는 라벨맵 파일을 찾을 수 없습니다: {npy_path}, {label_map_path}")
            return {}

        with open(label_map_path, 'r') as f:
            label_map = json.load(f)
        
        # 라벨맵의 value(인덱스)를 key로, key(이름)를 value로 뒤집어 인덱스로 이름을 찾을 수 있게 함

        index_to_label_name = {v: k for k, v in label_map.items()}
        
        data = np.load(npy_path, allow_pickle=True)
        if data.size == 0:
            return {}
            
        labels_int = data[:, -1].astype(int)
        vectors = data[:, :-1]

        grouped_data = {label_name: [] for label_name in label_map.keys()}

        for i, label_int in enumerate(labels_int):
            label_name = index_to_label_name.get(label_int)
            if label_name:
                grouped_data[label_name].append(vectors[i])

        # 리스트를 NumPy 배열로 변환하고, 데이터가 없는 라벨은 최종 딕셔너리에서 제외
        
        final_grouped_data = {}
        for label_name, data_list in grouped_data.items():
            if data_list:
                final_grouped_data[label_name] = np.array(data_list)

        return final_grouped_data

    def combine_and_save_data(self):
        # 'basic'과 'incremental' 데이터셋을 결합하여 'combine' 데이터셋을 생성하고 저장합니다.
        
        # 1. 라벨 맵 병합
        combined_map = self.combine_label_maps(
            self.config.LABEL_MAP_PATHS['basic'],
            self.config.LABEL_MAP_PATHS['incremental'],
            self.config.LABEL_MAP_PATHS['combine']
        )
        if not combined_map:
            logger.error("----- 라벨 맵 병합에 실패하여 데이터 결합을 중단합니다.")
            return

        # 2. 각 데이터셋 로드
        X_basic, y_basic = self._load_npy_data(self.config.BASIC_TRAIN_DATA_PATH)
        X_inc, y_inc = self._load_npy_data(self.config.INCREMENTAL_TRAIN_DATA_PATH)

        # 3. 데이터 결합
        if X_basic is not None and X_inc is not None:
            # 증분 데이터의 라벨을 새로운 통합 라벨맵 기준으로 업데이트
            with open(self.config.LABEL_MAP_PATHS['incremental'], 'r') as f:
                inc_map = json.load(f)
            
            # 라벨 이름 <-> 이전 인덱스
            inc_idx_to_name = {v: k for k, v in inc_map.items()}
            
            # 새로운 라벨 인덱스로 변환
            y_inc_new = np.array([combined_map[inc_idx_to_name[int(label)]] for label in y_inc])

            # 데이터 결합
            X_combined = np.vstack([X_basic, X_inc])
            y_combined = np.hstack([y_basic, y_inc_new])
            
            combined_data = np.c_[X_combined, y_combined]
            np.save(self.config.COMBINE_TRAIN_DATA_PATH, combined_data)
            logger.info(f"----- 'combine' 학습 데이터셋 저장 완료: {self.config.COMBINE_TRAIN_DATA_PATH}")

    def create_basic_npy_datasets(self, csv_path: str, train_npy_path: str, test_npy_path: str, test_size: float = 0.2, random_state: int = 42):
        # 랜드마크가 저장된 CSV 파일로부터 학습 및 테스트용 NPY 데이터셋을 생성
        try:
            df = pd.read_csv(csv_path, header=None)
            data = df.values
            
            X = data[:, :-1]
            y = data[:, -1]

            X_train, X_test, y_train, y_test = train_test_split(
                X, y, test_size=test_size, random_state=random_state, stratify=y
            )

            train_data = np.c_[X_train, y_train]
            test_data = np.c_[X_test, y_test]

            np.save(train_npy_path, train_data)
            np.save(test_npy_path, test_data)
            
            logger.info(f"----- NPY 데이터셋 생성 완료: {train_npy_path}, {test_npy_path}")

        except Exception as e:
            logger.error(f"----- NPY 데이터셋 생성 중 오류 발생: {e}")

    @staticmethod
    def combine_label_maps(basic_map_path: str, incremental_map_path: str, combined_map_save_path: str):
        # 라벨 맵을 병합하고 저장
        try:
            with open(basic_map_path, 'r', encoding='utf-8') as f:
                basic_map = json.load(f)
            with open(incremental_map_path, 'r', encoding='utf-8') as f:
                incremental_map = json.load(f)

            combined_map = basic_map.copy()
            next_index = max(basic_map.values()) + 1 if basic_map else 0

            for label in incremental_map.keys():
                if label not in combined_map:
                    combined_map[label] = next_index
                    next_index += 1
            
            with open(combined_map_save_path, 'w', encoding='utf-8') as f:
                json.dump(combined_map, f, ensure_ascii=False, indent=4)
            
            logger.info(f"----- 통합 라벨 맵 저장 완료: {combined_map_save_path}")
            return combined_map

        except Exception as e:
            logger.error(f"----- 라벨 맵 병합 중 오류 발생: {e}")
            return None
