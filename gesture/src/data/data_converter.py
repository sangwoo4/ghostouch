import os
import numpy as np
import pandas as pd
import logging
from typing import Tuple, Dict

logger = logging.getLogger(__name__)

class DataConverter:
    """
    CSV와 NPY 파일 간의 데이터 변환을 담당하는 클래스
    CSV에서 NPY 데이터셋을 생성하거나, NPY 데이터를 로드하는 기능을 제공
    """

    def create_npy_dataset(self, csv_path: str, npy_path: str):
        """
        CSV 파일로부터 NPY 데이터셋을 생성

        Args:
            csv_path (str): 입력 CSV 파일의 경로
            npy_path (str): 출력 NPY 파일의 경로
            label_map (Dict[str, int]): 라벨 문자열을 정수 인덱스에 매핑하는 딕셔너리
        
        Raises:
            FileNotFoundError: CSV 파일을 찾을 수 없을 때 발생
        """
        logger.info(f"----- CSV 파일({csv_path})로부터 NPY 데이터셋 생성 중 -> {npy_path}")
        if not os.path.exists(csv_path):
            raise FileNotFoundError(f"----- CSV 파일을 찾을 수 없습니다: {csv_path}")

        df = pd.read_csv(csv_path)
        X = df.drop(columns=['label']).values.astype(np.float32)
        y_string_labels = df['label'].values

        combined_data = np.hstack((X, y_string_labels.reshape(-1, 1)))
        
        np.save(npy_path, combined_data)
        logger.info(f"----- NPY 데이터 저장 완료: {npy_path}")

    def _load_npy_data(self, file_path: str) -> Tuple[np.ndarray, np.ndarray] | Tuple[None, None]:
        """
        NPY 파일로부터 데이터를 로드

        Args:
            file_path (str): 로드할 NPY 파일의 경로

        Returns:
            Tuple[np.ndarray, np.ndarray] | Tuple[None, None]: 로드된 특징(X)과 라벨(y) 배열 튜플 또는 로드 실패 시 (None, None)
        """
        logger.info(f"----- NPY 파일({file_path})로부터 데이터 로드 중")
        if not os.path.exists(file_path):
            logger.warning(f"----- NPY 파일을 찾을 수 없습니다: {file_path}")
            return None, None
        try:
            data = np.load(file_path, allow_pickle=True)

            # Features (X) as float, Labels (y) as string
            return data[:, :-1].astype(np.float32), data[:, -1].astype(str) 
        except Exception as e:
            logger.error(f"----- NPY 파일 로드 중 오류 발생 ({file_path}): {e}")
            return None, None