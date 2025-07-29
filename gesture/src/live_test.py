import cv2
import os
import mediapipe as mp
import numpy as np
import tensorflow as tf
import json
import argparse
import logging
import threading
import queue
from config import Config

logger = logging.getLogger(__name__)

class GesturePredictor:
    # 실시간 제스처 인식을 위한 클래스

    def __init__(self, config: Config, model_type: str = 'basic'):
        self.config = config
        self.model_type = model_type
        self.interpreter, self.input_details, self.output_details = self._load_model()
        
        # 양자화 모델을 위한 입출력 스케일 및 제로 포인트 추출
        self.input_scale, self.input_zero_point = self.input_details[0]['quantization']
        self.output_scale, self.output_zero_point = self.output_details[0]['quantization']
        
        self.index_to_label = self._load_label_map()
        self.hands = self._init_hands()
        
        self.preprocessed_queue = queue.Queue(maxsize=1)
        self.result_queue = queue.Queue(maxsize=1)
        self.inference_thread = self._start_inference_thread()

    def _load_model(self):
        # TFLite 모델을 로드하고 입출력 세부 정보를 반환
        model_path = self.config.TFLITE_MODEL_PATHS.get(self.model_type)
        if not model_path or not os.path.exists(model_path):
            raise ValueError(f"모델 파일을 찾을 수 없거나 지원되지 않는 모델 타입입니다: {self.model_type}")
        
        interpreter = tf.lite.Interpreter(model_path=model_path)
        interpreter.allocate_tensors()
        input_details = interpreter.get_input_details()
        output_details = interpreter.get_output_details()
        return interpreter, input_details, output_details

    def _load_label_map(self):
        # 라벨 맵을 로드하고 인덱스를 라벨에 매핑하는 딕셔너리를 반환
        label_map_path = self.config.LABEL_MAP_PATHS.get(self.model_type)
        if not label_map_path or not os.path.exists(label_map_path):
            raise ValueError(f"라벨 맵 파일을 찾을 수 없거나 지원되지 않는 모델 타입입니다: {self.model_type}")

        with open(label_map_path, 'r') as f:
            label_map = json.load(f)
        return {v: k for k, v in label_map.items()}

    def _init_hands(self):
        # MediaPipe Hands를 초기화
        return mp.solutions.hands.Hands(
            static_image_mode=False,
            max_num_hands=1,
            min_detection_confidence=self.config.MIN_DETECTION_CONFIDENCE,
            min_tracking_confidence=self.config.MIN_TRACKING_CONFIDENCE
        )

    def _start_inference_thread(self):
        # 모델 추론을 위한 별도의 스레드를 시작
        thread = threading.Thread(target=self._run_inference)
        thread.daemon = True
        thread.start()
        return thread

    def _run_inference(self):
        # 백그라운드에서 지속적으로 추론을 실행
        while True:
            feature_vector = self.preprocessed_queue.get()
            if feature_vector is None:  # 종료 신호
                break

            # Float32 입력을 모델이 요구하는 Uint8로 양자화
            input_data = (feature_vector / self.input_scale) + self.input_zero_point
            input_data = np.array([input_data], dtype=self.input_details[0]['dtype'])
            input_data = input_data.reshape(self.input_details[0]['shape'])
            
            self.interpreter.set_tensor(self.input_details[0]['index'], input_data)
            self.interpreter.invoke()
            output_data = self.interpreter.get_tensor(self.output_details[0]['index'])
            
            if not self.result_queue.full():
                self.result_queue.put(output_data)

    def process_frame(self, image):
        # 단일 프레임을 처리하고, 손을 감지하여 추론 큐에 삽입
        image_rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
        results = self.hands.process(image_rgb)

        if results.multi_hand_world_landmarks:
            hand_world_landmarks = results.multi_hand_world_landmarks[0]
            handedness = results.multi_handedness[0].classification[0].label

            # 월드 랜드마크를 직접 사용하고 평탄화
            landmark_points = np.array([[lm.x, lm.y, lm.z] for lm in hand_world_landmarks.landmark], dtype=np.float32).flatten()
            handedness_val = 0 if handedness == "Right" else 1
            feature_vector = np.concatenate([landmark_points, [handedness_val]])

            if feature_vector is not None and self.preprocessed_queue.empty():
                self.preprocessed_queue.put(feature_vector)
        
        return results

    def get_prediction(self):
        # 추론 결과를 반환
        try:
            output_data = self.result_queue.get_nowait()
            
            # Uint8 출력을 Float32 확률로 역양자화
            dequantized_output = (output_data.astype(np.float32) - self.output_zero_point) * self.output_scale

            predicted_index = np.argmax(dequantized_output)
            confidence = np.max(dequantized_output)

            if confidence < self.config.CONFIDENCE_THRESHOLD:
                return "none", confidence # 임계값보다 낮으면 Unknown으로 처리

            predicted_label = self.index_to_label.get(predicted_index, "none")
            return predicted_label, confidence
        except queue.Empty:
            return None, None

    def stop(self):
        # 추론 스레드를 안전하게 종료
        self.preprocessed_queue.put(None)
        self.inference_thread.join()

def main():
    parser = argparse.ArgumentParser(description="실시간 테스트")
    parser.add_argument('--model_type', type=str, default='basic', choices=['basic', 'combine'],
                        help="Type of model to use: 'basic' (기본) or 'combine' (업데이트된 모델).")
    args = parser.parse_args()

    config = Config()
    predictor = GesturePredictor(config, model_type=args.model_type)

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
        else:
            # 손이 감지되지 않으면 'none'으로 처리
            predicted_label = "none"
            confidence = 0.0

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
