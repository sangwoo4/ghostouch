import cv2
import numpy as np
import tensorflow as tf
import mediapipe as mp
import json
import logging
import threading
import queue
from data_processor import UnifiedPreprocessingStrategy
from config import Config

logger = logging.getLogger(__name__)

class GesturePredictor:
    # 실시간 제스처 인식을 위한 클래스입니다

    def __init__(self, config: Config):
        self.config = config
        self.strategy = UnifiedPreprocessingStrategy()
        self.interpreter, self.input_details, self.output_details = self._load_model()
        self.index_to_label = self._load_label_map()
        self.hands = self._init_hands()
        
        self.preprocessed_queue = queue.Queue(maxsize=1)
        self.result_queue = queue.Queue(maxsize=1)
        self.inference_thread = self._start_inference_thread()

    def _load_model(self):
        # TFLite 모델을 로드하고 입출력 세부 정보를 반환합니다
        interpreter = tf.lite.Interpreter(model_path=self.config.TFLITE_MODEL_PATH)
        interpreter.allocate_tensors()
        input_details = interpreter.get_input_details()
        output_details = interpreter.get_output_details()
        return interpreter, input_details, output_details

    def _load_label_map(self):
        # 라벨 맵을 로드하고 인덱스를 라벨에 매핑하는 딕셔너리를 반환합니다
        with open(self.config.LABEL_MAP_PATH, 'r') as f:
            label_map = json.load(f)
        return {v: k for k, v in label_map.items()}

    def _init_hands(self):
        # MediaPipe Hands를 초기화합니다
        return mp.solutions.hands.Hands(
            static_image_mode=False,
            max_num_hands=1,
            min_detection_confidence=0.5,
            min_tracking_confidence=0.5
        )

    def _start_inference_thread(self):
        # 모델 추론을 위한 별도의 스레드를 시작합니다
        thread = threading.Thread(target=self._run_inference)
        thread.daemon = True
        thread.start()
        return thread

    def _run_inference(self):
        # 백그라운드에서 지속적으로 추론을 실행합니다
        while True:
            feature_vector = self.preprocessed_queue.get()
            if feature_vector is None:  # 종료 신호
                break

            input_data = np.array([feature_vector], dtype=np.float32)
            input_data = input_data.reshape(self.input_details[0]['shape'])
            
            self.interpreter.set_tensor(self.input_details[0]['index'], input_data)
            self.interpreter.invoke()
            output_data = self.interpreter.get_tensor(self.output_details[0]['index'])
            
            if not self.result_queue.full():
                self.result_queue.put(output_data)

    def process_frame(self, image):
        # 단일 프레임을 처리하고, 손을 감지하여 추론 큐에 넣습니다
        image_rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
        results = self.hands.process(image_rgb)

        if results.multi_hand_landmarks:
            hand_landmarks = results.multi_hand_landmarks[0]
            landmark_points = [[lm.x, lm.y, lm.z] for lm in hand_landmarks.landmark]
            handedness = results.multi_handedness[0].classification[0].label

            feature_vector = self.strategy.preprocess(landmark_points, handedness)

            if feature_vector is not None and self.preprocessed_queue.empty():
                self.preprocessed_queue.put(feature_vector)
        
        return results

    def get_prediction(self):
        # 추론 결과를 반환합니다.
        try:
            output_data = self.result_queue.get_nowait()
            predicted_index = np.argmax(output_data)
            confidence = np.max(output_data)
            predicted_label = self.index_to_label.get(predicted_index, "Unknown")
            return predicted_label, confidence
        except queue.Empty:
            return None, None

    def stop(self):
        # 추론 스레드를 안전하게 종료합니다.
        self.preprocessed_queue.put(None)
        self.inference_thread.join()

def main():
    config = Config()
    predictor = GesturePredictor(config)

    cap = cv2.VideoCapture(0)
    cap.set(cv2.CAP_PROP_FRAME_WIDTH, config.CAM_WIDTH)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, config.CAM_HEIGHT)

    predicted_label = "Unknown"
    confidence = 0.0

    while cap.isOpened():
        success, image = cap.read()
        if not success:
            continue

        image = cv2.flip(image, 1)
        predictor.process_frame(image)
        
        new_label, new_confidence = predictor.get_prediction()
        if new_label is not None:
            predicted_label = new_label
            confidence = new_confidence

        text = f"{predicted_label} ({confidence:.2f})"
        cv2.putText(image, text, (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 255, 0), 2, cv2.LINE_AA)
        cv2.imshow('Live Gesture Recognition', image)

        if cv2.waitKey(5) & 0xFF == 27:  # ESC
            break

    predictor.stop()
    cap.release()
    cv2.destroyAllWindows()

if __name__ == '__main__':
    main()