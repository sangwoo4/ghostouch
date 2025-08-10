# 모델 학습, 평가, 변환을 담당하는 클래스 정의
import os

from app.core import PathConfig, HparamsConfig
from app.worker.ml.update_model_builder import ModelBuilder
import numpy as np
import tensorflow as tf
import logging
from tensorflow.keras.utils import to_categorical
from sklearn.model_selection import train_test_split
from sklearn.utils.class_weight import compute_class_weight
from tensorflow.keras.callbacks import EarlyStopping

logger = logging.getLogger(__name__)

class ModelTrainer:
    def __init__(self, model_builder: ModelBuilder, path_configs: PathConfig, hparams_config: HparamsConfig, label_map: dict, combined_data: np.ndarray):
        self.model_builder = model_builder
        self.path_configs = path_configs
        self.hparams_config = hparams_config
        self.label_map = label_map
        self.combined_data = combined_data

    # 데이터 로드 및 준비
    def _load_and_prepare_data(self):
        data = self.combined_data

        x = data[:, :-1].astype(np.float32)
        y_str = data[:, -1].astype(str)

        # 학습/검증 데이터 분할 (기능적 버그 수정)
        x_train, x_test, y_train_str, y_test_str = train_test_split(
            x, y_str, test_size=0.2, random_state=42, stratify=y_str
        )

        y_train_numeric = np.array([self.label_map[label] for label in y_train_str])
        y_test_numeric = np.array([self.label_map[label] for label in y_test_str])

        y_train = to_categorical(y_train_numeric, num_classes=len(self.label_map))
        y_test = to_categorical(y_test_numeric, num_classes=len(self.label_map))

        return x_train, y_train, x_test, y_test, y_train_numeric

    # 모델 학습 실행
    def train(self):
        x_train, y_train, x_test, y_test, y_train_numeric = self._load_and_prepare_data()
        model = self.model_builder.build((x_train.shape[1], 1), len(self.label_map))

        model.compile(optimizer=tf.keras.optimizers.Adam(self.hparams_config.INCREMENTAL_LEARNING_RATE), loss='categorical_crossentropy', metrics=['accuracy'])

        # 클래스 불균형을 고려하여 클래스 가중치 계산
        unique_numeric_labels = np.unique(y_train_numeric)
        class_weights = compute_class_weight('balanced', classes=unique_numeric_labels, y=y_train_numeric)
        class_weights_dict = dict(zip(unique_numeric_labels, class_weights))

        logger.info("모델 학습 시작")
        model.fit(x_train.reshape(-1, x_train.shape[1], 1), y_train,
                  validation_data=(x_test.reshape(-1, x_test.shape[1], 1), y_test),
                  epochs=self.hparams_config.EPOCHS,
                  batch_size=self.hparams_config.BATCH_SIZE,
                  callbacks=[EarlyStopping(patience=5, restore_best_weights=True, verbose=1)],
                  class_weight=class_weights_dict,
                  verbose=2)
        logger.info("모델 학습 완료")

        model.save(self.path_configs.combined_keras_model_path)
        logger.info(f"Keras 모델 저장 완료: {os.path.basename(self.path_configs.combined_keras_model_path)}")
        self._convert_to_tflite(model, x_train)

    # Keras 모델을 TFLite 모델로 변환 (양자화 포함)
    def _convert_to_tflite(self, model, x_train_for_tflite):
        input_shape = (x_train_for_tflite.shape[1], 1)
        def representative_data_gen():
            # 데이터셋을 무작위로 섞어(shuffle) 100개의 샘플을 추출하여 편향을 방지
            dataset = tf.data.Dataset.from_tensor_slices(x_train_for_tflite)
            for input_value in dataset.shuffle(buffer_size=len(x_train_for_tflite)).batch(1).take(100):
                yield [tf.reshape(input_value, (1, *input_shape))]

        converter = tf.lite.TFLiteConverter.from_keras_model(model)
        converter.optimizations = [tf.lite.Optimize.DEFAULT]
        converter.representative_dataset = representative_data_gen
        converter.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS_INT8]
        converter.inference_input_type = tf.uint8
        converter.inference_output_type = tf.uint8
        tflite_quant_model = converter.convert()

        with open(self.path_configs.tflite_model_path, "wb") as f: f.write(tflite_quant_model)
        logger.info(f"TFLite 모델 저장 완료: {os.path.basename(self.path_configs.tflite_model_path)}")