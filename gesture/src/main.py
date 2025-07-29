import argparse
import logging
import os
from config import Config
from data_processor import DataProcessor
from data_manager import DataManager
from model_trainer import ModelTrainer, BasicCNNBuilder, UpdateModelBuilder

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

def _process_and_create_dataset(config: Config, image_dir: str, csv_path: str, label_map_path: str, train_npy_path: str, test_npy_path: str):
    # 이미지 데이터를 처리하고 NPY 데이터셋을 생성
    
    # 1. 이미지 데이터 처리 (CSV 생성)
    data_processor = DataProcessor(
        config,
        data_dirs=[image_dir],
        output_csv_path=csv_path,
        label_map_path=label_map_path
    )
    data_processor.process()
    # 2. NPY 데이터셋 생성
    data_manager = DataManager(config)
    data_manager.create_basic_npy_datasets(
        csv_path,
        train_npy_path,
        test_npy_path
    )
    logging.info(f"----- '{image_dir}'에 대한 NPY 데이터셋 생성 완료")
    
def main():
    parser = argparse.ArgumentParser(description="----- 가위바위보 제스처 인식 모델 학습 파이프라인")
    parser.add_argument('--mode', type=str, choices=['train', 'update'], default='train', help='----- 모드 선택: train(기본 모델 학습), update(새로운 데이터로 모델 업데이트)')
    parser.add_argument('--base_model_path', type=str, default=None, help='----- 업데이트에 사용할 기본 모델 경로. 지정하지 않으면 기본 basic 모델을 사용합니다.')

    args = parser.parse_args()
    config = Config()

    if args.mode == 'train':
        # 1. 기본 데이터셋 생성
        logging.info("----- [train] 모드 시작: 기본 모델을 학습합니다.")
        _process_and_create_dataset(
            config,
            config.BASIC_IMAGE_DATA_DIR,
            config.BASIC_LANDMARK_CSV_PATH,
            config.LABEL_MAP_PATHS['basic'],
            config.BASIC_TRAIN_DATA_PATH,
            config.BASIC_TEST_DATA_PATH
        )

        # 2. 기본 모델 학습
        model_builder = BasicCNNBuilder()
        model_trainer = ModelTrainer(model_builder, config, 
                                     model_save_path=config.KERAS_MODEL_PATHS['basic'], 
                                     tflite_save_path=config.TFLITE_MODEL_PATHS['basic'],
                                     label_map_path=config.LABEL_MAP_PATHS['basic'],
                                     train_data_path=config.BASIC_TRAIN_DATA_PATH,
                                     test_data_path=config.BASIC_TEST_DATA_PATH)
        model_trainer.train()
        logging.info("----- [train] 모드 완료: 기본 모델 생성이 완료되었습니다.")

    elif args.mode == 'update':
        logging.info("----- [update] 모드 시작: 새로운 데이터로 모델을 업데이트합니다.")
        base_model_path = args.base_model_path if args.base_model_path else config.KERAS_MODEL_PATHS['basic']
        
        # 기반 모델 존재 여부 확인
        if not os.path.exists(base_model_path):
            raise FileNotFoundError(f"기반 모델을 찾을 수 없습니다: {base_model_path}\n'train' 모드를 먼저 실행하여 기본 모델을 생성하세요.")

        # 1. 새로운 데이터셋 생성
        _process_and_create_dataset(
            config,
            config.INCREMENTAL_IMAGE_DATA_DIR,
            config.INCREMENTAL_LANDMARK_CSV_PATH,
            config.LABEL_MAP_PATHS['incremental'],
            config.INCREMENTAL_TRAIN_DATA_PATH,
            config.INCREMENTAL_TEST_DATA_PATH
        )

        # 3. 통합 라벨 맵 생성
        combined_map = DataManager.combine_label_maps(config.LABEL_MAP_PATHS['basic'], config.LABEL_MAP_PATHS['incremental'], config.LABEL_MAP_PATHS['combine'])

        # 2. 모든 데이터셋 병합 (라벨 재조정 포함)
        data_manager = DataManager(config)
        final_train_X, final_train_y, final_test_X, final_test_y = data_manager.load_and_combine_all_datasets(config.LABEL_MAP_PATHS['combine'])
        if final_train_X is not None:
            data_manager.save_combined_datasets(final_train_X, final_train_y, final_test_X, final_test_y)

        # 4. 통합 모델 학습 (증분 학습)
        model_builder = UpdateModelBuilder(base_model_path)
        model_trainer = ModelTrainer(model_builder, config, 
                                     model_save_path=config.KERAS_MODEL_PATHS['combine'], 
                                     tflite_save_path=config.TFLITE_MODEL_PATHS['combine'],
                                     label_map_path=config.LABEL_MAP_PATHS['combine'],
                                     train_data_path=config.COMBINE_TRAIN_DATA_PATH,
                                     test_data_path=config.COMBINE_TEST_DATA_PATH,
                                     is_incremental_learning=True)
        model_trainer.train()
        logging.info("----- [update] 모드 완료: 통합 모델 생성이 완료되었습니다.")

if __name__ == '__main__':
    main()