import json
import numpy as np
import tensorflow as tf
import logging
from tensorflow.keras.models import Sequential, Model
from tensorflow.keras.layers import Conv2D, MaxPooling2D, Flatten, Dense, Dropout, Input
from tensorflow.keras.utils import to_categorical
from tensorflow.keras.callbacks import EarlyStopping
from abc import ABC, abstractmethod
from config import Config

logger = logging.getLogger(__name__)

class ModelBuilder(ABC):
    # 모델 생성을 위한 빌더 인터페이스입니다
    @abstractmethod
    def build(self, input_shape, num_classes):
        pass

class BasicCNNBuilder(ModelBuilder):
    # 기본 CNN 모델을 생성합니다
    def build(self, input_shape, num_classes):
        model = Sequential([
            Input(shape=input_shape),
            Conv2D(32, (3, 2), padding='same', activation='relu'),
            MaxPooling2D(pool_size=(2, 1)),
            Dropout(0.2),
            Conv2D(64, (3, 2), padding='same', activation='relu'),
            MaxPooling2D(pool_size=(2, 1)),
            Dropout(0.25),
            Flatten(),
            Dense(128, activation='relu'),
            Dropout(0.35),
            Dense(num_classes, activation='softmax')
        ])
        return model

class TransferLearningModelBuilder(ModelBuilder):
    # 전이 학습 모델을 생성합니다
    def __init__(self, base_model_path, prefix='transfer'):
        self.base_model_path = base_model_path
        self.prefix = prefix

    def build(self, input_shape, num_classes):
        base_model = tf.keras.models.load_model(self.base_model_path)
        feature_extractor = Model(inputs=base_model.input, outputs=base_model.layers[-2].output)
        feature_extractor.trainable = False

        model = Sequential([
            feature_extractor,
            Dense(128, activation='relu', name=f"{self.prefix}_dense1"),
            Dropout(0.3),
            Dense(num_classes, activation='softmax', name=f"{self.prefix}_output")
        ])
        return model

class ModelTrainer:
    # 모델을 학습하고 저장합니다
    def __init__(self, model_builder: ModelBuilder, config: Config):
        self.model_builder = model_builder
        self.config = config
        self.label_map = self._load_label_map()

    def _load_label_map(self):
        # 저장된 라벨 맵을 불러옵니다
        try:
            with open(self.config.LABEL_MAP_PATH, 'r') as f:
                return json.load(f)
        except FileNotFoundError:
            logger.error(f"----- 라벨 맵 파일을 찾을 수 없습니다: {self.config.LABEL_MAP_PATH}")
            raise

    def train(self):
        X_train, y_train, X_test, y_test = self._load_and_prepare_data()
        num_classes = len(self.label_map)
        
        input_shape = (X_train.shape[1], 1, 1)
        X_train = X_train.reshape(-1, *input_shape)
        X_test = X_test.reshape(-1, *input_shape)

        model = self.model_builder.build(input_shape, num_classes)
        model.compile(optimizer=tf.keras.optimizers.Adam(learning_rate=self.config.LEARNING_RATE),
                      loss='categorical_crossentropy',
                      metrics=['accuracy'])

        early_stopping = EarlyStopping(monitor='val_loss', patience=20, restore_best_weights=True)

        model.fit(X_train, y_train,
                  validation_data=(X_test, y_test),
                  epochs=self.config.EPOCHS,
                  batch_size=self.config.BATCH_SIZE,
                  callbacks=[early_stopping])

        model.save(self.config.MODEL_PATH)
        logger.info(f"----- 모델 저장 완료: {self.config.MODEL_PATH}")
        
        self._convert_to_tflite(model)

    def _load_and_prepare_data(self):
        # Numpy 데이터를 로드하고 라벨을 원-핫 인코딩으로 변환합니다.
        train_data = np.load(self.config.TRAIN_DATA_PATH, allow_pickle=True)
        test_data = np.load(self.config.TEST_DATA_PATH, allow_pickle=True)

        X_train = train_data[:, :-1].astype(np.float32)
        y_train_labels = train_data[:, -1]
        X_test = test_data[:, :-1].astype(np.float32)
        y_test_labels = test_data[:, -1]

        y_train = to_categorical([self.label_map[label] for label in y_train_labels], num_classes=len(self.label_map))
        y_test = to_categorical([self.label_map[label] for label in y_test_labels], num_classes=len(self.label_map))

        return X_train, y_train, X_test, y_test

    def _convert_to_tflite(self, model):
        # Keras 모델을 TFLite 모델로 변환하고 저장합니다.
        converter = tf.lite.TFLiteConverter.from_keras_model(model)
        converter.optimizations = [tf.lite.Optimize.DEFAULT]
        
        tflite_model = converter.convert()

        with open(self.config.TFLITE_MODEL_PATH, "wb") as f:
            f.write(tflite_model)
        logger.info(f"----- TFLite 모델 저장 완료: {self.config.TFLITE_MODEL_PATH}")