
from abc import ABC, abstractmethod
from typing import Tuple

import tensorflow as tf
from tensorflow.keras import regularizers
from tensorflow.keras.layers import (
    Conv1D,
    Dense,
    Dropout,
    Flatten,
    Input,
    MaxPooling1D,
)
from tensorflow.keras.models import Sequential

class ModelBuilder(ABC):
    """
    모델 생성을 위한 추상 기본 클래스(인터페이스)
    새로운 모델 아키텍처를 쉽게 추가할 수 있도록 빌더 패턴을 사용
    """
    @abstractmethod
    def build(self, input_shape: Tuple[int, ...], num_classes: int) -> tf.keras.Model:
        """
        주어진 입력 형태와 클래스 수에 따라 모델을 구축

        Args:
            input_shape (Tuple[int, ...]): 모델의 입력 형태 (예: (64, 1))
            num_classes (int): 분류할 클래스의 수

        Returns:
            tf.keras.Model: 구축된 Keras 모델
        """
        pass

class BasicCNNBuilder(ModelBuilder):
    """
    1D CNN을 사용하는 기본 제스처 인식 모델을 생성하는 빌더 클래스
    랜드마크 데이터(1차원 벡터) 처리에 적합
    """
    def build(self, input_shape: Tuple[int, ...], num_classes: int) -> tf.keras.Model:
        """
        기본 1D CNN 모델 아키텍처를 구축

        Args:
            input_shape (Tuple[int, ...]): 모델의 입력 형태 (예: (64, 1))
            num_classes (int): 분류할 클래스의 수

        Returns:
            tf.keras.Model: 구축된 Keras 모델
        """
        model = Sequential([
            Input(shape=input_shape), # 예: (64, 1)
            Conv1D(filters=32, kernel_size=3, padding='same', activation='relu'),
            MaxPooling1D(pool_size=2),
            Dropout(0.2),
            Conv1D(filters=64, kernel_size=3, padding='same', activation='relu'),
            MaxPooling1D(pool_size=2),
            Dropout(0.25),
            Flatten(),
            Dense(64, activation='relu', kernel_regularizer=regularizers.l2(1e-4)),
            Dropout(0.35),
            Dense(num_classes, activation='softmax')
        ])
        model.summary()
        return model

class UpdateModelBuilder(ModelBuilder):
    """
    기존에 학습된 모델을 기반으로 증분 학습(Incremental Learning) 모델을 생성하는 빌더 클래스
    기존 모델의 특징 추출기(Feature Extractor)는 재사용하고, 분류기(Classifier)만 새로 학습
    """
    def __init__(self, base_model_path: str, prefix: str = 'combine'):
        """
        UpdateModelBuilder를 초기화

        Args:
            base_model_path (str): 기반 Keras 모델(.keras) 파일의 경로
            prefix (str, optional): 새로운 Dense 레이어의 이름에 사용될 접두사. 기본값은 'combine'
        """
        self.base_model_path = base_model_path
        self.prefix = prefix

    def build(self, input_shape: Tuple[int, ...], num_classes: int) -> tf.keras.Model:
        """
        기존 모델의 특징 추출기를 재사용하고 새로운 분류 레이어를 추가하여 증분 학습 모델을 구축

        Args:
            input_shape (Tuple[int, ...]): 모델의 입력 형태 (예: (None, 64, 1))
            num_classes (int): 분류할 클래스의 수

        Returns:
            tf.keras.Model: 구축된 증분 학습 Keras 모델
        """
        base_model = tf.keras.models.load_model(self.base_model_path)

        # 특징 추출기 생성 (마지막 3개 레이어를 제외)
        feature_extractor = Sequential(base_model.layers[:-3], name="feature_extractor")

        # 새로운 데이터에 맞게 미세 조정(Fine-tuning)하기 위해 특징 추출기 레이어를 학습 가능하게 설정
        feature_extractor.trainable = True

        model = Sequential([
            feature_extractor,
            Flatten(),
            Dense(64, activation='relu', kernel_regularizer=regularizers.l2(1e-4)),
            Dropout(0.35),
            Dense(num_classes, activation='softmax')
        ])
        
        # 새로운 모델의 입력 형태를 확정
        model.build(input_shape=(None, *input_shape))
        model.summary()
        return model
