# import os
#
# from app.core import PathConfig
#
#
# async def upload_model_to_firebase(
#         tflite_model_path: str,
#         combined_keras_model_path: str,
#         combined_csv_path: str,
# ) -> str:
#     # ✅ 1. 먼저 TFLite 파일만 업로드
#     tflite_file_name = os.path.basename(tflite_model_path)
#     tflite_blob = bucket.blob(f"{firebase_folder}/{tflite_file_name}")
#     tflite_blob.upload_from_filename(UPDATED_TFLITE_PATH)
#     tflite_blob.make_public()
#     tflite_url = tflite_blob.public_url
#     print(f"[TFLite 업로드 완료] {tflite_file_name} → {tflite_url}")
#
#     # ✅ 2. 나머지 파일은 백그라운드에서 업로드
#     other_files = [UPDATE_TRAIN_DATA, UPDATE_TEST_DATA, UPDATED_MODEL_PATH]
#     loop.run_in_executor(executor, upload_remaining_files, other_files, firebase_folder, new_model_code)
#
#     # ✅ 3. 클라이언트에게 TFLite URL 즉시 반환
#     return tflite_url