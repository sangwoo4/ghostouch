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
from tensorflow.keras.callbacks import EarlyStopping, ReduceLROnPlateau

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

        # 모델 입력 형태를 (데이터 수, 특징 수, 1)로 변환 (Conv1D를 위함)
        x_train = x_train.reshape(-1, x_train.shape[1], 1).astype(np.float32)
        x_test  = x_test.reshape(-1,  x_test.shape[1],  1).astype(np.float32)

        return x_train, y_train, x_test, y_test, y_train_numeric

    # 모델 학습 실행
    def train(self):
        x_train, y_train, x_test, y_test, y_train_numeric = self._load_and_prepare_data()

        input_shape = (x_train.shape[1], x_train.shape[2])  # 예: (64, 1)
        num_classes = len(self.label_map)

        model = self.model_builder.build(input_shape, num_classes)
        model.compile(optimizer=tf.keras.optimizers.Adam(self.hparams_config.INCREMENTAL_LEARNING_RATE), loss='categorical_crossentropy', metrics=['accuracy'])

        # 클래스 불균형을 고려하여 클래스 가중치 계산
        all_classes = np.arange(num_classes, dtype=int)
        class_weights = compute_class_weight('balanced', classes=all_classes, y=y_train_numeric.astype(int))
        class_weights_dict = {int(c): float(w) for c, w in zip(all_classes, class_weights)}

        early_stopping = EarlyStopping(
            monitor='val_loss',
            patience=5,
            min_delta=1e-4,
            restore_best_weights=True,
            verbose=1
        )
        lr_scheduler = ReduceLROnPlateau(
            monitor='val_loss',
            factor=0.5,
            patience=5,
            min_lr=1e-5,
            verbose=1
        )
        callbacks = [early_stopping, lr_scheduler]


        logger.info("모델 학습 시작")
        model.fit(
          x_train, y_train,
          validation_data=(x_test, y_test),
          epochs=self.hparams_config.EPOCHS,
          batch_size=self.hparams_config.BATCH_SIZE,
          callbacks=callbacks,
          class_weight=class_weights_dict,
          verbose=2
        )
        logger.info("모델 학습 완료")

        loss, acc = model.evaluate(x_test, y_test, verbose=0)
        logger.info(f"[EVAL] Test accuracy: {acc:.4f}, loss: {loss:.4f}")

        model.save(self.path_configs.combined_keras_model_path)
        logger.info(f"Keras 모델 저장 완료: {os.path.basename(self.path_configs.combined_keras_model_path)}")
        self._convert_to_tflite(model, x_train)

    # Keras 모델을 TFLite 모델로 변환 (양자화 포함)
    def _convert_to_tflite(self, model, x_train):
        # 1) 대표데이터 형상/채널 가드 (경고/런타임 오류 예방)
        assert x_train.ndim == 3 and x_train.shape[2] == 1

        # 표본 수 안전 가드
        take_n = min(300, len(x_train))

        def representative_data_gen():
            # 2) float32 캐스팅 + (1, L, 1) 배치
            dataset = tf.data.Dataset.from_tensor_slices(
                tf.cast(x_train, tf.float32)
            ).shuffle(min(len(x_train), 10_000)
            ).batch(1
            ).take(take_n
            ).prefetch(tf.data.AUTOTUNE)

            for batch in dataset: yield [batch]

        converter = tf.lite.TFLiteConverter.from_keras_model(model)
        converter.optimizations = [tf.lite.Optimize.DEFAULT]
        converter.representative_dataset = representative_data_gen
        converter.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS_INT8]
        converter.inference_input_type = tf.uint8
        converter.inference_output_type = tf.uint8

        tflite_quant_model = converter.convert()

        with open(self.path_configs.tflite_model_path, "wb") as f: f.write(tflite_quant_model)
        logger.info(f"TFLite 모델 저장 완료: {os.path.basename(self.path_configs.tflite_model_path)}")