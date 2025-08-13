import numpy as np
import logging
import os
from typing import Dict, List, Tuple, Any
from gesture.src.config.file_config import FileConfig
from gesture.src.data.data_converter import DataConverter

logger = logging.getLogger(__name__)

class DataCombiner:
    """
    다양한 소스의 데이터를 로드하고 결합하는 역할을 담당하는 클래스
    NPY 파일 로드, 데이터셋 결합 및 저장, 라벨별 데이터 그룹화 기능을 제공
    """

    def __init__(self, config: FileConfig):
        """
        DataCombiner를 초기화

        Args:
            config (FileConfig): 파일 경로 설정을 담고 있는 FileConfig 객체
        """
        self.config = config
        self.converter = DataConverter() # DataConverter 인스턴스 생성

    def load_and_combine_all_datasets(self, combined_map: Dict[str, int], basic_map: Dict[str, int], incremental_map: Dict[str, int]) -> Tuple[np.ndarray, np.ndarray] | Tuple[None, None]:
        """
        기본 및 증분 데이터셋을 로드하고 통합 라벨 맵에 따라 결합

        Args:
            combined_map (Dict[str, int]): 통합 라벨 맵
            basic_map (Dict[str, int]): 기본 데이터셋의 라벨 맵
            incremental_map (Dict[str, int]): 증분 데이터셋의 라벨 맵

        Returns:
            Tuple[np.ndarray, np.ndarray] | Tuple[None, None]: 결합된 특징(X)과 라벨(y) 배열 튜플 또는 실패 시 (None, None)
        """
        all_data_paths = {
            "basic": self.config.BASIC_DATA_PATH,
            "incremental": self.config.INCREMENTAL_DATA_PATH
        }
        all_original_maps = {
            "basic": basic_map,
            "incremental": incremental_map
        }

        all_X: List[np.ndarray] = []
        all_y_numeric: List[int] = []

        for dataset_name in ["basic", "incremental"]:
            npy_path = all_data_paths.get(dataset_name)
            original_map = all_original_maps.get(dataset_name)

            if not npy_path or not os.path.exists(npy_path):
                logger.warning(f"----- NPY 파일을 찾을 수 없습니다: {npy_path}")
                continue
            if not original_map:
                logger.warning(f"----- 원본 라벨맵 '{dataset_name}'이(가) 제공되지 않았습니다")
                continue

            X, y_original_string_labels = self.converter._load_npy_data(npy_path)
            if X is None:
                continue
            
            for i, string_label in enumerate(y_original_string_labels):
                if string_label is not None and string_label in combined_map:
                    all_y_numeric.append(combined_map[string_label])
                    all_X.append(X[i])
                else:
                    logger.warning(f"----- 라벨 '{string_label}'이(가) 통합 라벨맵에 없거나 유효하지 않습니다. 데이터에서 제외합니다")

        if not all_X:
            logger.error("----- 데이터셋을 병합할 수 없습니다. 하나 이상의 npy 파일이 비어있거나 없습니다")
            return None, None

        reversed_combined_map = {v: k for k, v in combined_map.items()}
        all_y_string = np.array([reversed_combined_map[num_label] for num_label in all_y_numeric])

        return np.array(all_X), all_y_string

    def save_combined_dataset(self, X: np.ndarray, y: np.ndarray):
        """
        결합된 데이터셋을 NPY 파일로 저장

        Args:
            X (np.ndarray): 특징 데이터 배열
            y (np.ndarray): 라벨 데이터 배열
        """
        np.save(self.config.COMBINE_DATA_PATH, np.column_stack((X, y)))
        logger.info(f"----- 최종 통합 데이터 저장 완료: {self.config.COMBINE_DATA_PATH}")

    def load_data_grouped_by_label(self, npy_path: str) -> Dict[str, np.ndarray]:
        """
        NPY 파일에서 데이터를 로드하고, 라벨별로 그룹화

        Args:
            npy_path (str): 로드할 NPY 파일의 경로

        Returns:
            Dict[str, np.ndarray]: 라벨 문자열을 키로 하고 해당 특징 벡터 배열을 값으로 하는 딕셔너리
        """
        X, y_string_labels_from_npy = self.converter._load_npy_data(npy_path)
        if X is None:
            return {}

        grouped_data: Dict[str, List[np.ndarray]] = {}
        for i, str_label in enumerate(y_string_labels_from_npy):
            if str_label is None:
                continue
            if str_label not in grouped_data:
                grouped_data[str_label] = []
            grouped_data[str_label].append(X[i])

        # 리스트를 NumPy 배열로 변환
        for label, vectors in grouped_data.items():
            grouped_data[label] = np.array(vectors)

        return grouped_data

    def combine_and_save_data(self, combined_map: Dict[str, int], basic_map: Dict[str, int], incremental_map: Dict[str, int]):
        """
        Basic 및 Incremental 데이터셋을 결합하고, 최종 NPY 파일을 저장

        Args:
            combined_map (Dict[str, int]): 통합 라벨 맵
            basic_map (Dict[str, int]): 기본 데이터셋의 라벨 맵
            incremental_map (Dict[str, int]): 증분 데이터셋의 라벨 맵
        """
        # 모든 데이터셋 로드 및 통합
        X, y = self.load_and_combine_all_datasets(combined_map, basic_map, incremental_map)

        if X is None:
            logger.error("----- 데이터 통합에 실패했습니다. 모델 학습을 진행할 수 없습니다")
            return

        # 통합된 데이터셋 저장
        self.save_combined_dataset(X, y)