# 데이터셋을 생성, 통합, 관리하는 클래스 정의
import io
import os
import pandas as pd
import numpy as np
import logging

logger = logging.getLogger(__name__)

class DataPreprocessor:
    @staticmethod
    def csv_to_npy_mem(csv_path):
        if not os.path.exists(csv_path):
            error_msg = f"CSV 파일이 존재하지 않습니다: {csv_path}"
            logger.error(error_msg)
            raise FileNotFoundError(error_msg)
        df = pd.read_csv(csv_path)
        x = df.drop('label', axis=1).values
        y = df['label'].values

        data = np.hstack((x, y.reshape(-1, 1)))
        return data


    @staticmethod
    def group_by_label(np_array):
        x = np_array[:, :-1]
        y = np_array[:, -1].astype(str)

        # 비교(중복검사)용으로 X만 float 변경
        if x.dtype.kind in ('U', 'S', 'O'):
            x = x.astype(np.float32, copy=False)

        unique_labels = np.unique(y)
        grouped_data = {label: x[y == label] for label in unique_labels}
        return grouped_data
