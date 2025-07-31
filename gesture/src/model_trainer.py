import json
import numpy as np
import tensorflow as tf
import logging
from tensorflow.keras.models import Sequential
from tensorflow.keras.layers import Dense, Dropout, Input, Conv1D, MaxPooling1D, Flatten
from tensorflow.keras.utils import to_categorical
from tensorflow.keras.callbacks import EarlyStopping, ReduceLROnPlateau
from sklearn.utils.class_weight import compute_class_weight
from abc import ABC, abstractmethod
from config import Config

logger = logging.getLogger(__name__)

class ModelBuilder(ABC):
    # 모델 생성을 위한 추상 기본 클래스(인터페이스).
    # 새로운 모델 아키텍처를 쉽게 추가할 수 있도록 빌더 패턴을 사용합니다.
    
    @abstractmethod
    def build(self, input_shape, num_classes):
        pass

class BasicCNNBuilder(ModelBuilder):
    # 1D CNN을 사용하는 기본 제스처 인식 모델을 생성합니다.
    # 랜드마크 데이터(1차원 벡터) 처리에 적합합니다.
    
    def build(self, input_shape, num_classes):
        model = Sequential([
            Input(shape=input_shape),  # 입력 형태 지정
            Conv1D(filters=32, kernel_size=3, padding='same', activation='relu'),
            MaxPooling1D(pool_size=2),
            Dropout(0.25),
            Conv1D(filters=64, kernel_size=3, padding='same', activation='relu'),
            MaxPooling1D(pool_size=2),
            Dropout(0.3),
            Flatten(),
            Dense(128, activation='relu'),
            Dropout(0.35),
            Dense(num_classes, activation='softmax')
        ])
        return model

class UpdateModelBuilder(ModelBuilder):
    # 기존에 학습된 모델을 기반으로 증분 학습(Incremental Learning) 모델을 생성합니다.
    # 기존 모델의 특징 추출기(Feature Extractor)는 재사용하고, 분류기(Classifier)만 새로 학습합니다.
    
    def __init__(self, base_model_path, prefix='combine'):
        self.base_model_path = base_model_path
        self.prefix = prefix

    def build(self, input_shape, num_classes):
        base_model = tf.keras.models.load_model(self.base_model_path)

        # 특징 추출기 생성 (마지막 두 Dense 레이어를 제외)
        feature_extractor = Sequential(base_model.layers[:-2], name="feature_extractor")
        # 새로운 데이터에 맞게 미세 조정(Fine-tuning)하기 위해 특징 추출기 레이어를 학습 가능하게 설정
        feature_extractor.trainable = True

        model = Sequential([
            feature_extractor,
            Dense(128, activation='relu', name=f"{self.prefix}_dense1"),
            Dropout(0.3),
            Dense(num_classes, activation='softmax', name=f"{self.prefix}_output")
        ])
        
        # 새로운 모델의 입력 형태를 확정
        model.build(input_shape=(None, *input_shape))
        return model

class ModelTrainer:
    # 모델을 학습하고, 평가하며, TFLite로 변환하여 저장하는 클래스.
    
    def __init__(self, model_builder: ModelBuilder, config: Config, model_save_path: str = None, tflite_save_path: str = None, label_map_path: str = None, train_data_path: str = None, test_data_path: str = None, is_incremental_learning: bool = False):
        self.model_builder = model_builder
        self.config = config
        self.model_save_path = model_save_path
        self.tflite_save_path = tflite_save_path
        self.label_map_path = label_map_path
        self.train_data_path = train_data_path
        self.test_data_path = test_data_path
        self.is_incremental_learning = is_incremental_learning
        self.label_map = self._load_label_map()

    def _load_label_map(self):
        # 저장된 라벨 맵(JSON)을 로드합니다.

        try:
            with open(self.label_map_path, 'r') as f:
                return json.load(f)
        except FileNotFoundError:
            logger.error(f"----- 라벨 맵 파일을 찾을 수 없습니다: {self.label_map_path}")
            raise

    def train(self):
        # 모델 학습의 전체 과정을 수행합니다.

        X_train, y_train, X_test, y_test, y_train_labels, _ = self._load_and_prepare_data()
        num_classes = len(self.label_map)
        
        # 모델 입력 형태를 (데이터 수, 특징 수, 1)로 변환 (Conv1D를 위함)

        input_shape = (X_train.shape[1], 1)
        X_train = X_train.reshape(-1, *input_shape)
        X_test = X_test.reshape(-1, *input_shape)

        model = self.model_builder.build(input_shape, num_classes)
        learning_rate = self.config.INCREMENTAL_LEARNING_RATE if self.is_incremental_learning else self.config.LEARNING_RATE
        
        model.compile(optimizer=tf.keras.optimizers.Adam(learning_rate=learning_rate),
                      loss='categorical_crossentropy',
                      metrics=['accuracy'])

        # 콜백 설정: 조기 종료 및 학습률 동적 조정

        early_stopping = EarlyStopping(monitor='val_loss', patience=10, min_delta=0.0001, restore_best_weights=True)
        lr_scheduler = ReduceLROnPlateau(monitor='val_loss', factor=0.5, patience=5, min_lr=1e-6)

        # 클래스 불균형 처리를 위한 클래스 가중치 계산

        unique_classes = np.unique(y_train_labels)
        class_weights = compute_class_weight(
            class_weight='balanced',
            classes=unique_classes,
            y=y_train_labels
        )
        class_weights_dict = dict(zip(unique_classes, class_weights))
        logger.info("----- 클래스 가중치 적용 (클래스 불균형 처리):")
        reversed_label_map = {v: k for k, v in self.label_map.items()}
        for cls, weight in class_weights_dict.items():
            label_name = reversed_label_map.get(cls, f"Unknown({cls})")
            logger.info(f"        라벨 {cls} ({label_name}): 가중치 {weight:.4f}")

        model.fit(X_train, y_train,
                  validation_data=(X_test, y_test),
                  epochs=self.config.EPOCHS,
                  batch_size=self.config.BATCH_SIZE,
                  callbacks=[early_stopping, lr_scheduler],
                  class_weight=class_weights_dict)  # 계산된 클래스 가중치 적용

        model.save(self.model_save_path)
        logger.info(f"----- Keras 모델 저장 완료: {self.model_save_path}")
        
        loss, acc = model.evaluate(X_test, y_test, verbose=0)
        logger.info(f"----- 테스트 정확도: {acc:.4f}, 손실: {loss:.4f}")

        # TFLite 변환을 위한 대표 데이터셋 준비 (이미 로드된 학습 데이터 사용)

        self._convert_to_tflite(model, X_train)

    def _load_and_prepare_data(self):
        # Numpy 데이터를 로드하고 라벨을 원-핫 인코딩으로 변환합니다.

        train_data = np.load(self.train_data_path, allow_pickle=True)
        test_data = np.load(self.test_data_path, allow_pickle=True)

        X_train = train_data[:, :-1].astype(np.float32)
        y_train_labels = train_data[:, -1]  # 원-핫 인코딩 전의 정수 라벨
        X_test = test_data[:, :-1].astype(np.float32)
        y_test_labels = test_data[:, -1]

        y_train = to_categorical(y_train_labels, num_classes=len(self.label_map))
        y_test = to_categorical(y_test_labels, num_classes=len(self.label_map))

        return X_train, y_train, X_test, y_test, y_train_labels, y_test_labels

    def _convert_to_tflite(self, model, X_train_for_tflite):
        # Keras 모델을 INT8 양자화된 TFLite 모델로 변환하고 저장합니다.
        # 양자화는 모델 크기를 줄이고 추론 속도를 높여 모바일/임베디드 환경에 최적화합니다.
        
        input_shape = (X_train_for_tflite.shape[1], 1)
        
        def representative_data_gen():
            # 양자화를 위해 모델에 입력될 데이터의 분포를 알려주는 대표 데이터셋 생성
            # 데이터셋을 무작위로 섞어(shuffle) 100개의 샘플을 추출하여 편향을 방지
            dataset = tf.data.Dataset.from_tensor_slices(X_train_for_tflite)
            for input_value in dataset.shuffle(buffer_size=len(X_train_for_tflite)).batch(1).take(100):
                yield [tf.reshape(input_value, (1, *input_shape))]

        converter = tf.lite.TFLiteConverter.from_keras_model(model)
        converter.optimizations = [tf.lite.Optimize.DEFAULT]  # 기본 최적화 (양자화 포함)
        converter.representative_dataset = representative_data_gen
        # 연산자를 INT8로 제한하여 양자화 강제
        converter.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS_INT8]
        # 모델의 최종 입출력 타입도 정수형으로 설정
        converter.inference_input_type = tf.uint8
        converter.inference_output_type = tf.uint8
        
        tflite_quant_model = converter.convert()

        with open(self.tflite_save_path, "wb") as f:
            f.write(tflite_quant_model)
        logger.info(f"----- TFLite 모델 저장 완료 (INT8 양자화 적용): {self.tflite_save_path}")
