import logging
from tensorflow.keras.models import Sequential, load_model
from tensorflow.keras.layers import Dense, Dropout
from tensorflow.keras.regularizers import l2

logger = logging.getLogger(__name__)
# 기존 모델을 기반으로 증분 학습 모델을 구축하는 클래스
class ModelBuilder:
    def build(self, input_shape, num_classes):
        raise NotImplementedError("서브클래스에서 build()를 구현해야 합니다.")

class UpdateModelBuilder(ModelBuilder):
    def __init__(self, base_keras_model_path):
        self.base_keras_model_path = base_keras_model_path
        logger.info(f"UpdateModelBuilder 객체 초기화 완료 (기반 모델: {self.base_keras_model_path})")

    # 모델 구축
    def build(self, input_shape, num_classes):
        logger.info(f"증분 학습 모델 구축 시작 (입력 형태: {input_shape}, 클래스 수: {num_classes})")
        logger.info(f"기반 모델 로드: {self.base_keras_model_path}")

        base_model = load_model(self.base_keras_model_path)
        logger.info("기반 모델 로드 완료")

        # 특징 추출기 부분만 사용 (마지막 두 레이어 제외)
        feature_extractor = Sequential(base_model.layers[:-3], name="feature_extractor")
        feature_extractor.trainable = True
        logger.info("특징 추출기 설정 완료")

        # 새로운 분류 레이어를 추가하여 증분 학습 모델 구축
        model = Sequential([
            feature_extractor,
            Dense(64, activation='relu', kernel_regularizer=l2(1e-4)),
            Dropout(0.35),
            Dense(num_classes, activation='softmax')
        ])

        model.build(input_shape=(None, *input_shape))
        logger.info("증분 학습 모델 구축 완료")
        model.summary(print_fn=lambda x: logger.info(x))

        return model