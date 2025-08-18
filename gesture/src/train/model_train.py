import logging
from typing import Dict, Tuple

import numpy as np
import pandas as pd
import tensorflow as tf

from tensorflow.keras.utils import to_categorical
from tensorflow.keras.callbacks import EarlyStopping, ReduceLROnPlateau
from sklearn.utils.class_weight import compute_class_weight
from sklearn.model_selection import train_test_split
from gesture.src.config.file_config import FileConfig
from gesture.src.config.train_config import TrainConfig
from gesture.src.model.model_architect import ModelBuilder

logger = logging.getLogger(__name__)

class ModelTrainer:
    """
    모델을 학습하고, 평가하며, TFLite로 변환하여 저장하는 클래스
    """

    def __init__(self, model_builder: ModelBuilder, file_config: FileConfig, train_config: TrainConfig, 
                 model_save_path: str | None = None, tflite_save_path: str | None = None, 
                 label_map: Dict[str, int] | None = None, data_path: str | None = None, 
                 is_incremental_learning: bool = False):
        """
        ModelTrainer를 초기화

        Args:
            model_builder (ModelBuilder): 모델 아키텍처를 구축하는 빌더 객체
            file_config (FileConfig): 파일 경로 설정을 담고 있는 FileConfig 객체
            train_config (TrainConfig): 학습 관련 설정을 담고 있는 TrainConfig 객체
            model_save_path (str, optional): Keras 모델을 저장할 경로. 기본값은 None
            tflite_save_path (str, optional): TFLite 모델을 저장할 경로. 기본값은 None
            label_map (Dict[str, int], optional): 라벨 맵 딕셔너리. 기본값은 None
            data_path (str, optional): 학습 데이터를 로드할 NPY 파일 경로. 기본값은 None
            is_incremental_learning (bool, optional): 증분 학습 여부. 기본값은 False
        """
        self.model_builder = model_builder
        self.file_config = file_config
        self.train_config = train_config
        self.model_save_path = model_save_path
        self.tflite_save_path = tflite_save_path
        self.data_path = data_path
        self.is_incremental_learning = is_incremental_learning
        self.label_map = label_map
    

    def train(self):
        """
        모델 학습 프로세스를 실행
        데이터 로드, 모델 구축, 컴파일, 학습, 평가 및 TFLite 변환을 포함
        """
        if self.label_map is None or self.data_path is None:
            logger.error("----- 라벨 맵 또는 데이터 경로가 설정되지 않았습니다. 학습을 시작할 수 없습니다")
            return

        X_train, y_train, X_test, y_test, y_train_labels, y_test_labels = self._load_and_prepare_data()
        num_classes = len(self.label_map)

        # 모델 입력 형태를 (데이터 수, 특징 수, 1)로 변환 (Conv1D를 위함)
        input_shape: Tuple[int, int] = (X_train.shape[1], 1)
        X_train = X_train.reshape(-1, *input_shape)
        X_test = X_test.reshape(-1, *input_shape)

        model = self.model_builder.build(input_shape, num_classes)
        learning_rate = self.train_config.INCREMENTAL_LEARNING_RATE if self.is_incremental_learning else self.train_config.LEARNING_RATE
        
        model.compile(optimizer=tf.keras.optimizers.Adam(learning_rate=learning_rate),
                      loss='categorical_crossentropy',
                      metrics=['accuracy'])

        # 콜백 설정: 조기 종료 및 학습률 동적 조정
        early_stopping = EarlyStopping(
            monitor=self.train_config.ES_MONITOR,
            patience=self.train_config.ES_PATIENCE,
            min_delta=self.train_config.ES_MIN_DELTA,
            restore_best_weights=True,
            verbose=1
        )
        lr_scheduler = ReduceLROnPlateau(
            monitor=self.train_config.LR_SCHEDULER_MONITOR,
            factor=self.train_config.LR_SCHEDULER_FACTOR,
            patience=self.train_config.LR_SCHEDULER_PATIENCE,
            min_lr=self.train_config.LR_SCHEDULER_MIN_LR,
            verbose=1
        )

        # 클래스 불균형 처리를 위한 클래스 가중치 계산
        unique_classes: np.ndarray = pd.unique(y_train_labels).astype(int)
        class_weights: np.ndarray = compute_class_weight(
            class_weight='balanced',
            classes=unique_classes,
            y=y_train_labels.astype(int) # y_train_labels도 정수형으로 명시적 캐스팅
        )
        class_weights_dict: Dict[int, float] = dict(zip(unique_classes, class_weights))
        logger.info("----- 클래스 가중치 적용 (클래스 불균형 처리):")
        reversed_label_map: Dict[int, str] = {v: k for k, v in self.label_map.items()}
        for cls, weight in class_weights_dict.items():
            label_name = reversed_label_map.get(cls, f"Unknown({cls})")
            logger.info(f"----- 라벨 {cls} ({label_name}): 가중치 {weight:.4f}")

        logger.info("----- 모델 학습 시작")
        model.fit(X_train, y_train,
                  validation_data=(X_test, y_test),
                  epochs=self.train_config.EPOCHS,
                  batch_size=self.train_config.BATCH_SIZE,
                  callbacks=[early_stopping, lr_scheduler],
                  class_weight=class_weights_dict)  # 계산된 클래스 가중치 적용
        logger.info("----- 모델 학습 완료")

        if self.model_save_path:
            assert self.model_save_path.endswith(".keras")
            model.save(self.model_save_path)
            logger.info(f"----- Keras 모델 저장 완료: {self.model_save_path}")
        
        loss, acc = model.evaluate(X_test, y_test, verbose=0)
        logger.info(f"----- 테스트 정확도: {acc:.4f}, 손실: {loss:.4f}")

        # TFLite 변환을 위한 대표 데이터셋 준비 (이미 로드된 학습 데이터 사용)
        if self.tflite_save_path:
            self._convert_to_tflite(model, X_train)

    def _convert_to_tflite(self, model: tf.keras.Model, X_train_for_tflite: np.ndarray):
        """
        Keras 모델을 INT8 양자화된 TFLite 모델로 변환하고 저장
        """
        # 1) 대표데이터 형상/채널 가드 (경고/런타임 오류 예방)
        assert X_train_for_tflite.ndim == 3 and X_train_for_tflite.shape[2] == 1

        # 표본 수 안전 가드
        take_n = min(self.train_config.TFLITE_REPRESENTATIVE_DATASET_SAMPLE_SIZE, len(X_train_for_tflite))

        def representative_data_gen():
            # 2) float32 캐스팅 + (1, L, 1) 배치.
            buffer_size = min(len(X_train_for_tflite), self.train_config.TFLITE_SHUFFLE_BUFFER_SIZE)
            dataset = tf.data.Dataset.from_tensor_slices(
                tf.cast(X_train_for_tflite, tf.float32)
            ).shuffle(buffer_size
            ).batch(1
            ).take(take_n
            ).prefetch(tf.data.AUTOTUNE)

            for batch in dataset: yield [batch]

        converter = tf.lite.TFLiteConverter.from_keras_model(model)
        converter.optimizations = [tf.lite.Optimize.DEFAULT]
        converter.representative_dataset = representative_data_gen

        # 3) 완전 정수화(내부 연산 INT8) + I/O=int8 (코드와 로그 일치)
        converter.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS_INT8]
        converter.inference_input_type  = tf.uint8
        converter.inference_output_type = tf.uint8

        tflite_quant_model = converter.convert()

        with open(self.tflite_save_path, "wb") as f:
            f.write(tflite_quant_model)

        logger.info(f"----- TFLite 모델 저장 완료 (FULL INT, I/O=uint8): {self.tflite_save_path}")

    def _load_and_prepare_data(self) -> Tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray, np.ndarray, np.ndarray]:
        """
        Numpy 데이터를 로드하고 라벨을 원-핫 인코딩으로 변환하여 학습 준비

        Returns:
            Tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray, np.ndarray, np.ndarray]: 
            X_train, y_train, X_test, y_test, y_train_labels, y_test_labels 튜플
        """
        if self.data_path is None:
            raise ValueError("----- 데이터 경로(data_path)가 설정되지 않았습니다")

        data = np.load(self.data_path, allow_pickle=True)

        X = data[:, :-1].astype(np.float32)
        y_string_labels = data[:, -1].astype(str)

        if self.label_map is None:
            raise ValueError("----- 라벨 맵(label_map)이 설정되지 않았습니다")
        
        y_numeric_labels = np.array([self.label_map[label] for label in y_string_labels], dtype=int)

        X_train, X_test, y_train_numeric_labels, y_test_numeric_labels = train_test_split(
            X, y_numeric_labels, 
            test_size=self.train_config.TEST_SPLIT_SIZE, 
            random_state=self.train_config.RANDOM_STATE, 
            stratify=y_numeric_labels
        )

        y_train = to_categorical(y_train_numeric_labels, num_classes=len(self.label_map))
        y_test = to_categorical(y_test_numeric_labels, num_classes=len(self.label_map))

        return X_train, y_train, X_test, y_test, y_train_numeric_labels, y_test_numeric_labels