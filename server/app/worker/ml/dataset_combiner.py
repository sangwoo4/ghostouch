import logging
import numpy as np
import pandas as pd

logger = logging.getLogger(__name__)

class DatasetCombiner:
    def __init__(self, combine_csv_path: str):
        self.combine_csv_path = combine_csv_path

    # basic + incremental NPY 파일 통합
    def combine_and_save_data(self, basic_data, inc_data):
        # 메모리 병합
        combined_data = np.vstack((basic_data, inc_data))

        # X(float32), y(str)로 명확히 분리/캐스팅
        X = combined_data[:, :-1].astype(np.float32, copy=False)  # 랜드마크
        y = combined_data[:, -1].astype(str)                      # 라벨
        num_features = X.shape[1]

        # BASIC/INCREMENTAL과 동일한 컬럼 구성
        feature_cols = [str(i) for i in range(num_features)]

        # 랜드마크 float / 라벨 str
        df = pd.DataFrame(X, columns=feature_cols)
        df.insert(0, 'label', y)

        # 5) 저장
        df.to_csv(self.combine_csv_path, index=False)
        logger.info(f"통합 데이터 저장 완료(컬럼 호환): {self.combine_csv_path}")

        return combined_data