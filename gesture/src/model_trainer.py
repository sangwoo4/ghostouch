import json
import numpy as np
import tensorflow as tf
import logging
from tensorflow.keras.models import Sequential, Model
from tensorflow.keras.layers import Dense, Dropout, Input
from tensorflow.keras.utils import to_categorical
from tensorflow.keras.callbacks import EarlyStopping, ReduceLROnPlateau
from abc import ABC, abstractmethod
from config import Config

logger = logging.getLogger(__name__)

class ModelBuilder(ABC):
    # 모델 생성을 위한 빌더 인터페이스
    @abstractmethod
    def build(self, input_shape, num_classes):
        pass

class BasicCNNBuilder(ModelBuilder):
    # 기본 CNN 모델을 생성 (1D 랜드마크 데이터에 최적화)
    def build(self, input_shape, num_classes):
        model = Sequential([
            Input(shape=input_shape), # 예: (64, 1)
            tf.keras.layers.Conv1D(filters=32, kernel_size=3, padding='same', activation='relu'),
            tf.keras.layers.MaxPooling1D(pool_size=2),
            tf.keras.layers.Dropout(0.2),
            tf.keras.layers.Conv1D(filters=64, kernel_size=3, padding='same', activation='relu'),
            tf.keras.layers.MaxPooling1D(pool_size=2),
            tf.keras.layers.Dropout(0.25),
            tf.keras.layers.Flatten(),
            tf.keras.layers.Dense(128, activation='relu'),
            tf.keras.layers.Dropout(0.35),
            tf.keras.layers.Dense(num_classes, activation='softmax')
        ])
        return model

class TransferLearningModelBuilder(ModelBuilder):
    # 전이 학습 모델을 생성
    def __init__(self, base_model_path, prefix='transfer'):
        self.base_model_path = base_model_path
        self.prefix = prefix

    def build(self, input_shape, num_classes):
        base_model = tf.keras.models.load_model(self.base_model_path)

        # 특징 추출기 생성 (마지막 두 Dense 레이어를 제외)
        # 전이 학습 시 특징 추출기 레이어를 학습 가능하게 설정 (미세 조정)
        feature_extractor = Sequential(base_model.layers[:-2], name="feature_extractor")
        feature_extractor.trainable = True

        model = Sequential([
            feature_extractor,
            Dense(128, activation='relu', name=f"{self.prefix}_dense1"),
            Dropout(0.3),
            Dense(num_classes, activation='softmax', name=f"{self.prefix}_output")
        ])
        
        # 새로운 모델을 빌드하여 입력 형태를 확정
        model.build(input_shape=(None, *input_shape))
        return model

class ModelTrainer:
    # 모델을 학습하고 저장
    def __init__(self, model_builder: ModelBuilder, config: Config, model_save_path: str = None, tflite_save_path: str = None, label_map_path: str = None, train_data_path: str = None, test_data_path: str = None, is_transfer_learning: bool = False):
        self.model_builder = model_builder
        self.config = config
        self.model_save_path = model_save_path if model_save_path else self.config.BASIC_MODEL_PATH
        self.tflite_save_path = tflite_save_path if tflite_save_path else self.config.BASIC_TFLITE_MODEL_PATH
        self.label_map_path = label_map_path if label_map_path else self.config.BASIC_LABEL_MAP_PATH
        self.train_data_path = train_data_path if train_data_path else self.config.BASIC_TRAIN_DATA_PATH
        self.test_data_path = test_data_path if test_data_path else self.config.BASIC_TEST_DATA_PATH
        self.is_transfer_learning = is_transfer_learning
        self.label_map = self._load_label_map()

    def _load_label_map(self):
        # 저장된 라벨 맵 로드
        try:
            with open(self.label_map_path, 'r') as f:
                return json.load(f)
        except FileNotFoundError:
            logger.error(f"----- 라벨 맵 파일을 찾을 수 없습니다: {self.label_map_path}")
            raise

    def train(self):
        X_train, y_train, X_test, y_test = self._load_and_prepare_data()
        num_classes = len(self.label_map)
        
        input_shape = (X_train.shape[1], 1)
        X_train = X_train.reshape(-1, *input_shape)
        X_test = X_test.reshape(-1, *input_shape)

        model = self.model_builder.build(input_shape, num_classes)
        learning_rate = self.config.TRANSFER_LEARNING_RATE if self.is_transfer_learning else self.config.LEARNING_RATE
        model.compile(optimizer=tf.keras.optimizers.Adam(learning_rate=learning_rate),
                      loss='categorical_crossentropy',
                      metrics=['accuracy'])

        early_stopping = EarlyStopping(monitor='val_loss', patience=3, min_delta=0.0001, restore_best_weights=True)
        lr_scheduler = ReduceLROnPlateau(monitor='val_loss', factor=0.5, patience=3, min_lr=0.00001)

        model.fit(X_train, y_train,
                  validation_data=(X_test, y_test),
                  epochs=self.config.EPOCHS,
                  batch_size=self.config.BATCH_SIZE,
                  callbacks=[early_stopping, lr_scheduler])

        model.save(self.model_save_path)
        logger.info(f"----- 모델 저장 완료: {self.model_save_path}")
        
        self._convert_to_tflite(model, X_train)

    def _load_and_prepare_data(self):
        # Numpy 데이터를 로드하고 라벨을 원-핫 인코딩으로 변환
        train_data = np.load(self.train_data_path, allow_pickle=True)
        test_data = np.load(self.test_data_path, allow_pickle=True)

        X_train = train_data[:, :-1].astype(np.float32)
        y_train_labels = train_data[:, -1]
        X_test = test_data[:, :-1].astype(np.float32)
        y_test_labels = test_data[:, -1]

        y_train = to_categorical([self.label_map[label] for label in y_train_labels], num_classes=len(self.label_map))
        y_test = to_categorical([self.label_map[label] for label in y_test_labels], num_classes=len(self.label_map))

        return X_train, y_train, X_test, y_test

    def _convert_to_tflite(self, model, X_train):
        # Keras 모델을 TFLite 모델로 변환하고 저장
        
        input_shape = model.input_shape[1:] # (height, width, channels)
        
        def representative_data_gen():
            # 학습 데이터에서 100개의 샘플을 사용하여 대표 데이터셋 생성
            for input_value in tf.data.Dataset.from_tensor_slices(X_train).batch(1).take(100):
                yield [tf.reshape(input_value, (1, *input_shape))]

        converter = tf.lite.TFLiteConverter.from_keras_model(model)
        converter.optimizations = [tf.lite.Optimize.DEFAULT]
        converter.representative_dataset = representative_data_gen
        # 모델의 모든 가중치와 연산을 정수형으로 변환
        converter.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS_INT8]
        # 변환할 수 없는 연산이 있다면 변환을 중단
        converter.inference_input_type = tf.uint8
        converter.inference_output_type = tf.uint8
        
        tflite_quant_model = converter.convert()

        with open(self.tflite_save_path, "wb") as f:
            f.write(tflite_quant_model)
        logger.info(f"----- TFLite 모델 저장 완료 (INT8 양자화 적용): {self.tflite_save_path}")