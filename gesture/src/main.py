import argparse
import logging
from config import Config
from data_processor import DataProcessor
from data_manager import DataManager
from model_trainer import ModelTrainer, BasicCNNBuilder, TransferLearningModelBuilder

# 로깅 설정
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

def main():
    parser = argparse.ArgumentParser(description="----- 가위바위보 제스처 인식 모델 학습 파이프라인")
    parser.add_argument('--mode', type=str, choices=['train', 'transfer'], default='train', help='----- 학습 모드를 선택합니다.')
    parser.add_argument('--base_model_path', type=str, default=None, help='----- 전이 학습에 사용할 기본 모델 경로입니다.')

    args = parser.parse_args()
    config = Config()

    # 1. 데이터 전처리 및 라벨 맵 생성
    if args.mode == 'train':
        data_processor = DataProcessor(config, data_dir=config.BASIC_IMAGE_DATA_DIR, output_csv_path=config.BASIC_LANDMARK_CSV_PATH)
        data_processor.process()

        data_manager = DataManager(config, 
                                     csv_paths=[config.BASIC_LANDMARK_CSV_PATH],
                                     train_data_path=config.BASIC_TRAIN_DATA_PATH,
                                     test_data_path=config.BASIC_TEST_DATA_PATH,
                                     image_data_dirs=[config.BASIC_IMAGE_DATA_DIR],
                                     label_map_path=config.BASIC_LABEL_MAP_PATH)
        data_manager.create_label_map()
        data_manager.process_data()
        
        model_builder = BasicCNNBuilder()
        model_trainer = ModelTrainer(model_builder, config, 
                                     model_save_path=config.BASIC_MODEL_PATH, 
                                     tflite_save_path=config.BASIC_TFLITE_MODEL_PATH,
                                     label_map_path=config.BASIC_LABEL_MAP_PATH,
                                     train_data_path=config.BASIC_TRAIN_DATA_PATH,
                                     test_data_path=config.BASIC_TEST_DATA_PATH)
        model_trainer.train()

    elif args.mode == 'transfer':
        # 새로운 데이터만 처리
        data_processor_transfer = DataProcessor(config, data_dir=config.TRANSFER_IMAGE_DATA_DIR, output_csv_path=config.TRANSFER_LANDMARK_CSV_PATH)
        data_processor_transfer.process()
        
        # 기존 데이터와 새로운 데이터를 모두 DataManager에 전달
        data_manager = DataManager(config, 
                                     csv_paths=[config.BASIC_LANDMARK_CSV_PATH, config.TRANSFER_LANDMARK_CSV_PATH],
                                     train_data_path=config.TRANSFER_TRAIN_DATA_PATH,
                                     test_data_path=config.TRANSFER_TEST_DATA_PATH,
                                     image_data_dirs=[config.BASIC_IMAGE_DATA_DIR, config.TRANSFER_IMAGE_DATA_DIR],
                                     label_map_path=config.TRANSFER_LABEL_MAP_PATH,
                                     is_transfer_learning=True,
                                     deduplication_precision=6)
        data_manager.create_label_map()
        data_manager.process_data()
        data_manager.identify_cross_label_similarities()

        if not args.base_model_path:
            raise ValueError("----- 전이 학습 모드에서는 --base_model_path가 필요합니다.")
        model_builder = TransferLearningModelBuilder(args.base_model_path)
        model_trainer = ModelTrainer(model_builder, config, 
                                     model_save_path=config.TRANSFER_MODEL_PATH, 
                                     tflite_save_path=config.TRANSFER_TFLITE_MODEL_PATH,
                                     label_map_path=config.TRANSFER_LABEL_MAP_PATH,
                                     train_data_path=config.TRANSFER_TRAIN_DATA_PATH,
                                     test_data_path=config.TRANSFER_TEST_DATA_PATH,
                                     is_transfer_learning=True)
        model_trainer.train()

if __name__ == '__main__':
    main()
