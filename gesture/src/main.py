import argparse
import logging
from config import Config
from data_processor import DataProcessor, UnifiedPreprocessingStrategy
from data_manager import DataManager
from model_trainer import ModelTrainer, BasicCNNBuilder, TransferLearningModelBuilder

# 로깅 설정
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

def main():
    parser = argparse.ArgumentParser(description="----- 가위바위보 제스처 인식 모델 학습 파이프라인")
    parser.add_argument('--strategy', type=str, help='="----- 전처리 전략을 선택합니다.')
    parser.add_argument('--mode', type=str, choices=['train', 'transfer'], default='train', help='----- 학습 모드를 선택합니다.')
    parser.add_argument('--base_model_path', type=str, default=None, help='----- 전이 학습에 사용할 기본 모델 경로입니다.')

    args = parser.parse_args()
    config = Config()

    # 1. 데이터 전처리 및 라벨 맵 생성
    strategy = UnifiedPreprocessingStrategy()
    data_processor = DataProcessor(config, strategy)
    data_processor.process()

    # 2. 데이터 변환 및 분할
    data_manager = DataManager(config)
    data_manager.process_data()

    # 3. 모델 학습
    if args.mode == 'train':
        model_builder = BasicCNNBuilder()
    elif args.mode == 'transfer':
        if not args.base_model_path:
            raise ValueError("----- 전이 학습 모드에서는 --base_model_path가 필요합니다.")
        model_builder = TransferLearningModelBuilder(args.base_model_path)
    
    model_trainer = ModelTrainer(model_builder, config)
    model_trainer.train()

if __name__ == '__main__':
    main()