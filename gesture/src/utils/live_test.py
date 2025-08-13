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
from typing import Tuple, Dict, Any, Optional, List
from gesture.src.config.file_config import FileConfig
from gesture.src.config.test_config import TestConfig

logger = logging.getLogger(__name__)

class GesturePredictor:
    """
    실시간 제스처 인식을 위한 클래스
    웹캠 프레임을 처리하고, TFLite 모델을 사용하여 제스처를 예측
    추론은 별도의 스레드에서 실행하여 메인 스레드(GUI)의 블로킹을 방지
    """

    def __init__(self, file_config: FileConfig, test_config: TestConfig, model_type: str = 'basic'):
        """
        GesturePredictor를 초기화

        Args:
            file_config (FileConfig): 파일 경로 설정을 담고 있는 FileConfig 객체
            test_config (TestConfig): 테스트 관련 설정을 담고 있는 TestConfig 객체
            model_type (str, optional): 사용할 모델의 타입 (예: 'basic', 'combine'). 기본값은 'basic'
        """
        self.file_config = file_config
        self.test_config = test_config
        self.model_type = model_type
        self.interpreter, self.input_details, self.output_details = self._load_model()
        
        # 양자화 모델을 위한 입출력 스케일 및 제로 포인트 추출
        self.input_scale: np.float32 = self.input_details[0]['quantization'][0]
        self.input_zero_point: int = self.input_details[0]['quantization'][1]
        self.output_scale: np.float32 = self.output_details[0]['quantization'][0]
        self.output_zero_point: int = self.output_details[0]['quantization'][1]
        
        self.index_to_label: Dict[int, str] = self._load_label_map()
        self.hands = self._init_hands()
        
        # 스레드 간 데이터 교환을 위한 큐
        self.preprocessed_queue: queue.Queue = queue.Queue(maxsize=1)
        self.result_queue: queue.Queue = queue.Queue(maxsize=1)
        self.inference_thread: threading.Thread = self._start_inference_thread()

    def _load_model(self) -> Tuple[tf.lite.Interpreter, List[Dict[str, Any]], List[Dict[str, Any]]]:
        """
        TFLite 모델을 로드하고 입출력 세부 정보를 반환

        Returns:
            Tuple[tf.lite.Interpreter, List[Dict[str, Any]], List[Dict[str, Any]]]: 
            인터프리터, 입력 세부 정보, 출력 세부 정보 튜플

        Raises:
            ValueError: 모델 파일을 찾을 수 없거나 지원되지 않는 모델 타입일 경우 발생
        """
        model_path: Optional[str] = self.file_config.TFLITE_MODEL_PATHS.get(self.model_type)
        if not model_path or not os.path.exists(model_path):
            raise ValueError(f"모델 파일을 찾을 수 없거나 지원되지 않는 모델 타입입니다: {self.model_type}")
        
        interpreter = tf.lite.Interpreter(model_path=model_path)
        interpreter.allocate_tensors()
        input_details = interpreter.get_input_details()
        output_details = interpreter.get_output_details()
        return interpreter, input_details, output_details

    def _load_label_map(self) -> Dict[int, str]:
        """
        라벨 맵을 로드하고, 인덱스를 라벨 이름에 매핑하는 딕셔너리를 반환

        Returns:
            Dict[int, str]: 인덱스를 라벨 이름에 매핑하는 딕셔너리

        Raises:
            ValueError: 라벨 맵 파일을 찾을 수 없거나 지원되지 않는 모델 타입일 경우 발생
        """
        label_map_path: Optional[str] = self.file_config.LABEL_MAP_PATHS.get(self.model_type)
        if not label_map_path or not os.path.exists(label_map_path):
            raise ValueError(f"라벨 맵 파일을 찾을 수 없거나 지원되지 않는 모델 타입입니다: {self.model_type}")

        with open(label_map_path, 'r') as f:
            label_map: Dict[str, int] = json.load(f)
        return {v: k for k, v in label_map.items()}  # {index: name} 형태

    def _init_hands(self) -> mp.solutions.hands.Hands:
        """
        MediaPipe Hands 객체를 초기화

        Returns:
            mp.solutions.hands.Hands: 초기화된 MediaPipe Hands 객체
        """
        return mp.solutions.hands.Hands(
            static_image_mode=False,  # 비디오 스트림 모드
            max_num_hands=1,
            min_detection_confidence=self.test_config.MIN_DETECTION_CONFIDENCE,
            min_tracking_confidence=self.test_config.MIN_TRACKING_CONFIDENCE
        )

    def _start_inference_thread(self) -> threading.Thread:
        """
        모델 추론을 위한 별도의 스레드를 시작

        Returns:
            threading.Thread: 시작된 추론 스레드 객체
        """
        thread = threading.Thread(target=self._run_inference)
        thread.daemon = True
        thread.start()
        return thread

    def _run_inference(self):
        """
        백그라운드에서 지속적으로 추론을 실행하는 스레드 타겟 함수
        전처리된 데이터를 큐에서 가져와 모델 추론을 수행하고 결과를 다른 큐에 삽입
        """
        while True:
            feature_vector: Optional[np.ndarray] = self.preprocessed_queue.get()
            if feature_vector is None:  # 종료 신호
                break

            # Float32 입력을 모델이 요구하는 Uint8로 양자화
            input_data: np.ndarray = (feature_vector / self.input_scale) + self.input_zero_point
            input_data = np.array([input_data], dtype=self.input_details[0]['dtype'])
            input_data = input_data.reshape(self.input_details[0]['shape'])
            
            self.interpreter.set_tensor(self.input_details[0]['index'], input_data)
            self.interpreter.invoke()
            output_data: np.ndarray = self.interpreter.get_tensor(self.output_details[0]['index'])
            
            try:
                self.result_queue.put_nowait(output_data)
            except queue.Full:
                # 큐가 가득 찼을 경우, 가장 오래된 데이터를 제거하고 새 데이터를 넣음
                self.result_queue.get_nowait()
                self.result_queue.put_nowait(output_data)

    def process_frame(self, image: np.ndarray) -> Any:
        """
        단일 프레임을 처리하고 손을 감지하여 특징 벡터를 추출한 후 추론 큐에 삽입

        Args:
            image (np.ndarray): 처리할 웹캠 프레임 (BGR 형식)

        Returns:
            Any: MediaPipe Hands 처리 결과 객체
        """
        image_rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
        results = self.hands.process(image_rgb)

        if results.multi_hand_world_landmarks:
            hand_world_landmarks = results.multi_hand_world_landmarks[0]
            handedness = results.multi_handedness[0].classification[0].label

            landmark_points = np.array([[lm.x, lm.y, lm.z] for lm in hand_world_landmarks.landmark], dtype=np.float32).flatten()
            handedness_val = 0 if handedness == "Right" else 1
            feature_vector = np.concatenate([landmark_points, [handedness_val]])

            # 추론 스레드가 작업을 마칠 때까지 기다리지 않도록 큐가 비어있을 때만 데이터를 넣음
            if feature_vector is not None and self.preprocessed_queue.empty():
                self.preprocessed_queue.put(feature_vector)
        
        return results

    def get_prediction(self) -> Tuple[Optional[str], Optional[float]]:
        """
        추론 결과 큐에서 예측 결과를 가져와 해석

        Returns:
            Tuple[Optional[str], Optional[float]]: 예측된 라벨 문자열과 신뢰도 튜플
            새로운 결과가 없으면 (None, None)을 반환
        """
        try:
            output_data: np.ndarray = self.result_queue.get_nowait()
            
            # Uint8 출력을 Float32 확률로 역양자화
            dequantized_output: np.ndarray = (output_data.astype(np.float32) - self.output_zero_point) * self.output_scale

            predicted_index: int = np.argmax(dequantized_output)
            confidence: float = float(np.max(dequantized_output))

            predicted_label: str = self.index_to_label.get(predicted_index, "Unknown")
            if confidence < self.test_config.CONFIDENCE_THRESHOLD:
                return "Unknown", confidence
            return predicted_label, confidence
        except queue.Empty:
            return None, None  # 새로운 결과가 없으면 None 반환

    def stop(self):
        """
        추론 스레드를 안전하게 종료
        """
        self.preprocessed_queue.put(None) # 종료 신호 전송
        self.inference_thread.join() # 스레드 종료 대기

def main():
    """
    실시간 제스처 인식 테스트를 실행하는 메인 함수
    웹캠을 통해 영상을 받아 제스처를 인식하고 화면에 표시
    """
    parser = argparse.ArgumentParser(description="실시간 제스처 인식 테스트")
    parser.add_argument('--model_type', type=str, default='basic', choices=['basic', 'combine'],
                        help="사용할 모델 타입을 선택합니다: 'basic'(기본) 또는 'combine'(업데이트된 모델).")
    args = parser.parse_args()

    file_config = FileConfig()
    test_config = TestConfig()
    try:
        predictor = GesturePredictor(file_config, test_config, model_type=args.model_type)
    except ValueError as e:
        logger.error(f"초기화 오류: {e}")
        return

    cap = cv2.VideoCapture(0)
    if not cap.isOpened():
        logger.error("웹캠을 열 수 없습니다. 카메라가 연결되어 있는지 확인하세요")
        return

    cap.set(cv2.CAP_PROP_FRAME_WIDTH, test_config.CAM_WIDTH)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, test_config.CAM_HEIGHT)

    predicted_label: str = "Unknown"
    confidence: float = 0.0

    while cap.isOpened():
        success, image = cap.read()
        if not success:
            logger.warning("프레임을 읽을 수 없습니다. 웹캠 연결을 확인하세요")
            break

        image = cv2.flip(image, 1)  # 좌우 반전
        predictor.process_frame(image)
        
        # 최신 예측 결과 가져오기
        new_label, new_confidence = predictor.get_prediction()
        if new_label is not None:
            predicted_label = new_label
            confidence = new_confidence
        else: # 예측 결과가 없으면 (손이 감지되지 않았거나 큐가 비어있음)
            predicted_label = "Unknown"
            confidence = 0.0

        # 화면에 예측 결과 표시
        text = f"{predicted_label} ({confidence:.2f})"
        cv2.putText(image, text, (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 255, 0), 2, cv2.LINE_AA)
        cv2.imshow('Live Gesture Recognition', image)

        if cv2.waitKey(5) & 0xFF == 27:  # ESC 키로 종료
            break

    predictor.stop()
    cap.release()
    cv2.destroyAllWindows()

if __name__ == '__main__':
    main()