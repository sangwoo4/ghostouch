import asyncio
import os
import logging
from firebase_admin import storage

logger = logging.getLogger(__name__)

async def upload_tflite_and_get_url(tflite_path: str) -> str:
    if not os.path.isfile(tflite_path):
        error_msg = f"업로드할 Tflite 파일이 존재하지 않습니다 : {tflite_path}"
        logger.error(error_msg)
        raise Exception(error_msg)

    try:
        bucket = storage.bucket()
        file_name = os.path.basename(tflite_path)
        destination_blob_name = f"models/tflite/{file_name}"

        blob = bucket.blob(destination_blob_name)

        logger.info(f"TFLite 모델 업로드 시작: {tflite_path} -> {destination_blob_name}")
        await asyncio.to_thread(blob.upload_from_filename, tflite_path)

        await asyncio.to_thread(blob.make_public)

        public_url = blob.public_url
        logger.info(f"TFLite 모델 업로드 완료. URL: {public_url}")

        return public_url

    except Exception as e:
        logger.error(f"Firebase TFLite 업로드 중 에러 발생: {e}", exc_info=True)
        raise e

async def upload_keras_model(keras_path: str) -> None:
    """
    Keras 모델을 Firebase Storage에 업로드합니다. (Fire-and-Forget)
    이 함수는 백그라운드에서 실행되며, 완료를 기다리지 않습니다.
    """
    if not os.path.exists(keras_path):
        logger.warning(f"Keras 파일이 존재하지 않아 업로드를 건너뜁니다: {keras_path}")
        return

    try:
        bucket = storage.bucket()
        file_name = os.path.basename(keras_path)
        destination_blob_name = f"models/keras/{file_name}"
        blob = bucket.blob(destination_blob_name)

        logger.info(f"백그라운드 Keras 모델 업로드 시작: {keras_path} -> {destination_blob_name}")
        await asyncio.to_thread(blob.upload_from_filename, keras_path)
        logger.info(f"백그라운드 Keras 모델 업로드 완료: {destination_blob_name}")

    except Exception as e:
        logger.error(f"백그라운드 Keras 업로드 중 에러 발생: {e}", exc_info=True)


async def upload_csv_data(csv_path: str) -> None:
    """
    학습 데이터를 Firebase Storage에 업로드합니다. (Fire-and-Forget)
    이 함수는 백그라운드에서 실행되며, 완료를 기다리지 않습니다.
    """
    if not os.path.exists(csv_path):
        logger.warning(f"CSV 파일이 존재하지 않아 업로드를 건너뜁니다: {csv_path}")
        return

    try:
        bucket = storage.bucket()
        file_name = os.path.basename(csv_path)
        destination_blob_name = f"models/csv/{file_name}"
        blob = bucket.blob(destination_blob_name)

        logger.info(f"백그라운드 CSV 데이터 업로드 시작: {csv_path} -> {destination_blob_name}")
        await asyncio.to_thread(blob.upload_from_filename, csv_path)
        logger.info(f"백그라운드 CSV 데이터 업로드 완료: {destination_blob_name}")

    except Exception as e:
        logger.error(f"백그라운드 CSV 업로드 중 에러 발생: {e}", exc_info=True)