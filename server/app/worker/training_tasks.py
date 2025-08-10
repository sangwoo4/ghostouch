
import logging
from app.core import celery_app, HparamsConfig, PathConfig
from .ml.data_preprocessor import DataPreprocessor
from .ml.dataset_combiner import DatasetCombiner
from .ml.label_manager import LabelManager
from .ml.model_summary_printer import ModelSummaryPrinter
from .ml.model_trainer import ModelTrainer
from app.utils.utils import generate_model_id, convert_landmarks_to_csv
from .ml.update_model_builder import UpdateModelBuilder
from ..services import firebase_service
import asyncio

logger = logging.getLogger(__name__)

@celery_app.task
def archive_other_files_task(files_paths):
    print("Archiving other files")
    return "Archiving Complete"


@celery_app.task
def training_task(model_code, landmarks):
        new_model_code = generate_model_id()
        hparams_configs = HparamsConfig()
        path_configs = PathConfig(model_code, new_model_code)


        # 1. 데이터 준비
        path_configs.incremental_csv_path = convert_landmarks_to_csv(landmarks)
        base = DataPreprocessor.csv_to_npy_mem(path_configs.base_csv_path)
        incremental = DataPreprocessor.csv_to_npy_mem(path_configs.incremental_csv_path)

        #2. 중복 검사

        # 3.데이터 병합 및 저장
        dataset_combiner = DatasetCombiner(path_configs.combined_csv_path)
        combined_data = dataset_combiner.combine_and_save_data(base, incremental)

        # 4. combine 데이터 라벨맵 생성
        label_manager = LabelManager(base, combined_data)  # 메모리 데이터로 전달
        label_map, final_label_order = label_manager.build_label_map()
        print(f"[CHECK] 최종 라벨 순서: {final_label_order} / label_map: {label_map}")

        # 5. 모델 학습
        model_builder = UpdateModelBuilder(path_configs.base_keras_model_path)
        trainer = ModelTrainer(model_builder, path_configs, hparams_configs, label_map, combined_data)
        trainer.train()

        ModelSummaryPrinter.print_summaries(path_configs)
        logger.info("증분 학습이 성공적으로 완료되었습니다.")

        return {
                "tflite_model_path": path_configs.tflite_model_path,
                "combined_keras_model_path": path_configs.combined_keras_model_path,
                "combined_csv_path": path_configs.combined_csv_path,
        }




@celery_app.task
def upload_task(paths: dict):
    # asyncio 환경에서 실행
    return asyncio.run(_upload_task_async(paths))


async def _upload_task_async(paths: dict):
    tflite_url = await firebase_service.upload_tflite_and_get_url(
        paths["tflite_model_path"]
    )
    logger.info(f"TFLite 모델 업로드 완료 및 URL 수신: {tflite_url}")

    asyncio.create_task(firebase_service.upload_keras_model(
        paths["combined_keras_model_path"]
    ))

    asyncio.create_task(firebase_service.upload_csv_data(
        paths["combined_csv_path"]
    ))
    logger.info("Keras 모델 및 CSV 데이터 백그라운드 업로드 시작됨.")

    return tflite_url