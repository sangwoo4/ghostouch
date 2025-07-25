import argparse
import logging
from config import Config
from data_processor import DataProcessor
from data_manager import DataManager
from model_trainer import ModelTrainer, BasicCNNBuilder, TransferLearningModelBuilder

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
    data_processor.create_label_map()
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
    parser.add_argument('--mode', type=str, choices=['train', 'transfer'], default='train', help='----- 모드 선택: train(기본학습), transfer(전이학습)')
    parser.add_argument('--base_model_path', type=str, default=None, help='----- 전이 학습에 사용할 기본 모델 경로입니다.')

    args = parser.parse_args()
    config = Config()

    if args.mode == 'train':
        # 1. 기본 데이터셋 생성
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

    elif args.mode == 'transfer':
        # 1. 새로운 데이터셋 생성
        _process_and_create_dataset(
            config,
            config.TRANSFER_IMAGE_DATA_DIR,
            config.TRANSFER_LANDMARK_CSV_PATH,
            config.LABEL_MAP_PATHS['transfer'],
            config.TRANSFER_TRAIN_DATA_PATH,
            config.TRANSFER_TEST_DATA_PATH
        )

        # 2. 모든 데이터셋 병합
        data_manager = DataManager(config)
        final_train_X, final_train_y, final_test_X, final_test_y = data_manager.load_and_combine_all_datasets()
        if final_train_X is not None:
            data_manager.save_combined_datasets(final_train_X, final_train_y, final_test_X, final_test_y)

        # 3. 통합 라벨 맵 생성
        DataManager.combine_label_maps(config.LABEL_MAP_PATHS['basic'], config.LABEL_MAP_PATHS['transfer'], config.LABEL_MAP_PATHS['combine'])

        # 4. 전이 학습 모델 학습
        if not args.base_model_path:
            raise ValueError("----- 전이 학습 모드에서는 --base_model_path가 필요합니다.")
        model_builder = TransferLearningModelBuilder(args.base_model_path)
        model_trainer = ModelTrainer(model_builder, config, 
                                     model_save_path=config.KERAS_MODEL_PATHS['combine'], 
                                     tflite_save_path=config.TFLITE_MODEL_PATHS['combine'],
                                     label_map_path=config.LABEL_MAP_PATHS['combine'],
                                     train_data_path=config.COMBINE_TRAIN_DATA_PATH,
                                     test_data_path=config.COMBINE_TEST_DATA_PATH,
                                     is_transfer_learning=True)
        model_trainer.train()

if __name__ == '__main__':
    main()