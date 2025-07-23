import numpy as np
import pandas as pd
from sklearn.model_selection import train_test_split
import logging
import os
import json
from config import Config

logger = logging.getLogger(__name__)

class DataManager:
    # 데이터 로드, 분할 및 저장을 관리
    def __init__(self, config: Config, csv_paths: list = None, train_data_path: str = None, test_data_path: str = None,
                 is_transfer_learning: bool = False, deduplication_precision: int = 6):
        self.config = config
        self.landmark_csv_paths = csv_paths if csv_paths else [self.config.BASIC_LANDMARK_CSV_PATH]
        self.train_data_path = train_data_path if train_data_path else self.config.BASIC_TRAIN_DATA_PATH
        self.test_data_path = test_data_path if test_data_path else self.config.BASIC_TEST_DATA_PATH
        self.is_transfer_learning = is_transfer_learning
        self.deduplication_precision = deduplication_precision

    def identify_cross_label_similarities(self):
        logger.info("----- 새로운 데이터와 기존 라벨 간 정확한 중복 분석 시작...")
        
        # 기존 데이터 로드 및 전처리
        basic_df = pd.read_csv(self.config.BASIC_LANDMARK_CSV_PATH)
        basic_feature_columns = basic_df.columns.drop("label")
        basic_df['__rounded_features__'] = basic_df[basic_feature_columns].apply(
            lambda row: tuple(np.round(row.to_numpy(), decimals=self.deduplication_precision)), axis=1
        )
        
        # 새로운 데이터 로드 및 전처리
        transfer_df = pd.read_csv(self.config.TRANSFER_LANDMARK_CSV_PATH)
        transfer_feature_columns = transfer_df.columns.drop("label")
        transfer_df['__rounded_features__'] = transfer_df[transfer_feature_columns].apply(
            lambda row: tuple(np.round(row.to_numpy(), decimals=self.deduplication_precision)), axis=1
        )

        # 새로운 데이터의 각 라벨별로 분석
        for new_label in transfer_df['label'].unique():
            logger.info(f"----- 새로운 라벨 '{new_label}'의 데이터와 기존 라벨 간 중복 분석 중...")
            
            # 현재 새로운 라벨에 해당하는 데이터의 특징 집합
            current_new_features_set = set(
                transfer_df[transfer_df['label'] == new_label]['__rounded_features__']
            )
            total_new_label_count = len(current_new_features_set) # 중복 제거된 개수로 계산

            # 기존 데이터의 각 라벨별로 중복 검사
            for basic_label in basic_df['label'].unique():
                # 현재 기존 라벨에 해당하는 데이터의 특징 집합
                current_basic_features_set = set(
                    basic_df[basic_df['label'] == basic_label]['__rounded_features__']
                )
                
                # 두 특징 집합의 교집합 (중복되는 특징)
                common_features = current_new_features_set.intersection(current_basic_features_set)
                
                duplicate_count = len(common_features)
                
                if duplicate_count > 0:
                    percentage = (duplicate_count / total_new_label_count) * 100 if total_new_label_count > 0 else 0
                    logger.info(f"----- 라벨 '{new_label}'의 데이터 중 {duplicate_count}개 ({percentage:.2f}%)가 기존 라벨 '{basic_label}'의 데이터와 중복됨.")
                else:
                    logger.info(f"----- 라벨 '{new_label}'의 데이터와 기존 라벨 '{basic_label}'의 데이터 간 중복이 발견되지 않았습니다.")
        
        logger.info("----- 새로운 데이터와 기존 라벨 간 정확한 중복 분석 완료.")

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
        
        combined_df = pd.concat(dfs, ignore_index=True)
        
        # 'label' 컬럼을 제외한 특징 컬럼들을 선택 (항상 정의)
        feature_columns = combined_df.columns.drop('label')
        
        if self.is_transfer_learning:
            # 특징 컬럼의 부동 소수점 값들을 반올림하여 정밀도 문제 해결
            # 그리고 이를 해시 가능한 튜플 형태로 변환하여 임시 컬럼에 저장
            combined_df['__rounded_features__'] = combined_df[feature_columns].apply(
                lambda row: tuple(np.round(row.to_numpy(), decimals=self.deduplication_precision)), axis=1
            )
            
            # 'label'과 반올림된 특징 튜플을 기준으로 중복 제거
            # 중복 제거 전 각 라벨별 데이터 수 계산
            initial_counts = combined_df.groupby('label').size()

            deduplicated_df = combined_df.drop_duplicates(
                subset=['label', '__rounded_features__'], keep='first'
            ).drop(columns=['__rounded_features__']).reset_index(drop=True) # 임시 컬럼 제거
            
            # 중복 제거 후 각 라벨별 데이터 수 계산
            final_counts = deduplicated_df.groupby('label').size()

            if len(combined_df) != len(deduplicated_df):
                logger.info(f"----- 전체 데이터 중복 제거 완료 (라벨별): {len(combined_df)} -> {len(deduplicated_df)}")
                # 각 라벨별 중복 제거 상세 로그
                for label, initial_count in initial_counts.items():
                    final_count = final_counts.get(label, 0) # 해당 라벨이 모두 제거된 경우 0
                    removed_count = initial_count - final_count
                    if removed_count > 0:
                        removed_percentage = (removed_count / initial_count) * 100 if initial_count > 0 else 0
                        logger.info(f"----- 라벨 '{label}'에서 중복 데이터 {removed_count}개 제거됨 ({removed_percentage:.2f}%). (원래: {initial_count}, 현재: {final_count})")
            return deduplicated_df
        else:
            return combined_df

    def _split_data(self, X, y):
        # 데이터를 학습 및 테스트 세트로 분할
        return train_test_split(X, y, test_size=0.2, random_state=42, stratify=y)

    def _save_data(self, X, y, path):
        # 특징과 라벨을 결합하여 Numpy 파일로 저장
        data = np.column_stack((X, y.reshape(-1, 1)))
        np.save(path, data)
