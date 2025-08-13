import sys
import os
import argparse
import logging
import json
import numpy as np
from typing import Dict, Any
from gesture.src.config.file_config import FileConfig
from gesture.src.config.train_config import TrainConfig
from gesture.src.data.data_preprocessor import DataPreprocessor
from gesture.src.data.data_combiner import DataCombiner
from gesture.src.data.data_converter import DataConverter
from gesture.src.model.model_architect import BasicCNNBuilder, UpdateModelBuilder
from gesture.src.train.model_train import ModelTrainer
from gesture.src.utils.duplicate_checker import DuplicateChecker
from gesture.src.label.label_processor import LabelProcessor

# 로깅 설정: 스크립트 실행 전반에 걸쳐 정보를 제공
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

def _process_and_create_dataset(file_config: FileConfig, image_dir: str, csv_path: str, label_map_path: str, npy_path: str):
    """
    이미지 데이터를 처리하고 CSV 및 NPY 데이터셋을 생성

    Args:
        file_config (FileConfig): 파일 경로 설정을 담고 있는 FileConfig 객체
        image_dir (str): 이미지 데이터가 있는 디렉토리 경로
        csv_path (str): 랜드마크 CSV 파일을 저장할 경로
        label_map_path (str): 라벨 맵 JSON 파일을 저장할 경로
        npy_path (str): NPY 데이터셋을 저장할 경로
    """
    # 1. 이미지에서 랜드마크를 추출하고 CSV로 저장 (DataPreprocessor)
    data_preprocessor = DataPreprocessor(
        file_config,
        data_dirs=[image_dir],
        output_csv_path=csv_path,
        label_map_path=label_map_path
    )
    data_preprocessor.process()

    # 2. CSV를 NPY 데이터셋으로 변환 (DataConverter)
    data_converter = DataConverter()
    data_converter.create_npy_dataset(
        csv_path,
        npy_path
    )
    logging.info(f"----- '{image_dir}'에 대한 NPY 데이터셋 생성 완료")

def main():
    """
    가위바위보 제스처 인식 모델 학습 파이프라인의 메인 실행 함수
    CLI 인자를 파싱하여 'train' 또는 'update' 모드를 실행
    """
    parser = argparse.ArgumentParser(description="----- 가위바위보 제스처 인식 모델 학습 파이프라인")
    parser.add_argument('--mode', type=str, choices=['train', 'update'], default='train',
                        help="'train': 기본 모델을 처음부터 학습합니다. "
                             "'update': 새로운 데이터로 기존 모델을 업데이트(전이 학습)합니다.")
    parser.add_argument('--base_model_path', type=str, default=None,
                        help="'update' 모드에서 사용할 기본 Keras 모델(.keras) 경로. 지정하지 않으면 config의 기본 경로를 사용합니다.")
    parser.add_argument('--dup_threshold', type=float, default=10.0,
                        help="'update' 모드에서, 추가 데이터와 기존 데이터 간의 라벨별 중복 허용 임계값(%%). "
                             "이 값을 초과하면 데이터 오염으로 간주하고 학습을 중단합니다.")

    args = parser.parse_args()
    file_config = FileConfig()
    train_config = TrainConfig()

    if args.mode == 'train':
        # --- 기본 모델 학습 모드 ---
        logging.info("----- [train] 모드 시작: 기본 모델을 학습합니다.")
        _process_and_create_dataset(
            file_config,
            file_config.BASIC_IMAGE_DATA_DIR,
            file_config.BASIC_LANDMARK_CSV_PATH,
            file_config.LABEL_MAP_PATHS['basic'],
            file_config.BASIC_DATA_PATH
        )


        data_from_npy = np.load(file_config.BASIC_DATA_PATH, allow_pickle=True)
        unique_labels_from_npy = np.unique(data_from_npy[:, -1].astype(str))
        basic_label_map = {label: i for i, label in enumerate(sorted(unique_labels_from_npy))}

        logging.debug(f"[DEBUG] Train mode - unique_labels_from_npy: {unique_labels_from_npy}")
        logging.debug(f"[DEBUG] Train mode - basic_label_map: {basic_label_map}")

        model_builder = BasicCNNBuilder()
        model_trainer = ModelTrainer(model_builder, file_config, train_config,
                                     model_save_path=file_config.KERAS_MODEL_PATHS['basic'],
                                     tflite_save_path=file_config.TFLITE_MODEL_PATHS['basic'],
                                     label_map=basic_label_map,
                                     data_path=file_config.BASIC_DATA_PATH)
        model_trainer.train()
        logging.info("----- [train] 모드 완료: 기본 모델 생성이 완료되었습니다.")

    elif args.mode == 'update':
        # --- 모델 업데이트(증분 학습) 모드 ---
        logging.info("----- [update] 모드 시작: 새로운 데이터로 모델을 업데이트합니다.")
        base_model_path = args.base_model_path if args.base_model_path else file_config.KERAS_MODEL_PATHS['basic']

        if not os.path.exists(base_model_path):
            raise FileNotFoundError(f"----- 기반 모델을 찾을 수 없습니다: {base_model_path}\n'train' 모드를 먼저 실행하여 기본 모델을 생성하세요.")

        # 1. 새로운(incremental) 데이터에 대해서만 이미지 처리부터 시작
        _process_and_create_dataset(
            file_config,
            file_config.INCREMENTAL_IMAGE_DATA_DIR,
            file_config.INCREMENTAL_LANDMARK_CSV_PATH,
            file_config.LABEL_MAP_PATHS['incremental'],
            file_config.INCREMENTAL_DATA_PATH
        )


        data_from_npy = np.load(file_config.INCREMENTAL_DATA_PATH, allow_pickle=True)
        unique_labels_from_npy = np.unique(data_from_npy[:, -1].astype(str))
        incremental_label_map = {label: i for i, label in enumerate(sorted(unique_labels_from_npy))}

        # 기존(basic) 데이터의 라벨 맵은 NPY 데이터에서 생성
        data_from_npy_basic = np.load(file_config.BASIC_DATA_PATH, allow_pickle=True)
        unique_labels_from_npy_basic = np.unique(data_from_npy_basic[:, -1].astype(str))
        basic_label_map: Dict[str, int] = {label: i for i, label in enumerate(sorted(unique_labels_from_npy_basic))}
        logging.info(f"----- 기존 라벨 맵 로드 완료 (NPY 데이터 기반): {file_config.LABEL_MAP_PATHS['basic']}")

        logging.debug(f"[DEBUG] Update mode - basic_label_map (from NPY): {basic_label_map}")
        logging.debug(f"[DEBUG] Update mode - incremental_label_map (from NPY): {incremental_label_map}")

        # 2. 통합 라벨 맵 생성 (메모리상의 딕셔너리 사용)
        combined_label_map: Dict[str, int] = LabelProcessor.combine_label_maps(
            basic_label_map, # 인메모리 basic_label_map 전달
            incremental_label_map, # 인메모리 incremental_label_map 전달
            file_config.LABEL_MAP_PATHS['combine']
        )
        logging.debug(f"[DEBUG] Update mode - combined_label_map: {combined_label_map}")

        data_combiner = DataCombiner(file_config)
        checker = DuplicateChecker()
        is_duplicate_found: bool = False

        # 3. 데이터 오염 방지를 위한 중복 검사 (메모리상의 딕셔너리 사용)
        inc_grouped: Dict[str, np.ndarray] = data_combiner.load_data_grouped_by_label(file_config.INCREMENTAL_DATA_PATH)
        basic_grouped: Dict[str, np.ndarray] = data_combiner.load_data_grouped_by_label(file_config.BASIC_DATA_PATH)

        logging.info("----- 검사: Incremental vs Basic")
        for inc_label, inc_vectors in inc_grouped.items():
            for basic_label, basic_vectors in basic_grouped.items():
                report: Dict[str, Any] = checker.check(inc_vectors, basic_vectors)
                logging.debug(f"[DEBUG] Report from check: {report}")
                logging.info(f"----- [검사] Inc '{inc_label}' vs Basic '{basic_label}': {report['duplicate_count']}/{report['total_count']} ({report['duplicate_rate']:.2f}%) 중복")
                if report['duplicate_rate'] > args.dup_threshold:
                    logging.error(f"----- 중복 허용 임계값 초과! ({report['duplicate_rate']:.2f}% > {args.dup_threshold}%)")
                    is_duplicate_found = True

        if is_duplicate_found:
            logging.error("중복 검사 실패. 데이터셋 간의 중복이 허용치를 초과하여 프로세스를 중단합니다.")
            sys.exit(1)
        else:
            logging.info("----- 중복 검사 통과. 데이터 통합 및 모델 학습을 계속합니다.")

        # 4. 데이터셋 결합 및 모델 학습 (메모리상의 딕셔너리 사용)
        data_combiner.combine_and_save_data(combined_map=combined_label_map, basic_map=basic_label_map, incremental_map=incremental_label_map)
        model_builder = UpdateModelBuilder(base_model_path)
        model_trainer = ModelTrainer(model_builder, file_config, train_config,
                                     model_save_path=file_config.KERAS_MODEL_PATHS['combine'],
                                     tflite_save_path=file_config.TFLITE_MODEL_PATHS['combine'],
                                     label_map=combined_label_map, # 파일 경로 대신 딕셔너리 전달
                                     data_path=file_config.COMBINE_DATA_PATH,
                                     is_incremental_learning=True)
        model_trainer.train()
        logging.info("----- [update] 모드 완료: 통합 모델 생성이 완료되었습니다.")

if __name__ == '__main__':
    main()
