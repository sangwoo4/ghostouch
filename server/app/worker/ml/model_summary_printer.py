from tensorflow.keras.models import load_model

# 로그 관리 클래스
class ModelSummaryPrinter:
    @staticmethod
    def print_summaries(path_configs):
        m_basic = load_model(path_configs.base_keras_model_path)
        m_basic.summary()

        m_combine = load_model(path_configs.combined_keras_model_path)
        m_combine.summary()