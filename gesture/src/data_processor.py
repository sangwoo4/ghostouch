import os
import cv2
import mediapipe as mp
import numpy as np
import pandas as pd
import json
from abc import ABC, abstractmethod
import logging
from config import Config

logger = logging.getLogger(__name__)

class PreprocessingStrategy(ABC):
    # 전처리 전략에 대한 인터페이스
    @abstractmethod
    def preprocess(self, landmark_points, handedness=None):
        pass

class UnifiedPreprocessingStrategy(PreprocessingStrategy):
    # 랜드마크 정규화를 위한 통합 전략

    def preprocess(self, landmark_points, handedness=None):
        
        # 주어진 랜드마크에 대해 정규화 파이프라인을 실행합니다.

        # Args:
            # landmark_points (list): 21개의 랜드마크 좌표 리스트.
            # handedness (str): 감지된 손의 방향 ('Right' 또는 'Left').

        # Returns:
        # np.ndarray: 정규화 및 평탄화된 랜드마크 벡터. 유효하지 않으면 None.
        
        landmarks = np.array(landmark_points, dtype=np.float32)
        if landmarks.shape != (21, 3):
            return None

        # 정규화 파이프라인
        translated_landmarks = self._normalize_translation(landmarks)
        scaled_landmarks = self._normalize_scale(translated_landmarks)
        if scaled_landmarks is None:
            return None
        
        rotated_landmarks = self._normalize_rotation(scaled_landmarks)

        # 특징 벡터 생성
        flattened_landmarks = rotated_landmarks.flatten()
        handedness_val = 0 if handedness == "Right" else 1  # 오른손: 0, 왼손: 1
        
        return np.concatenate([flattened_landmarks, [handedness_val]])

    def _normalize_translation(self, landmarks):
        # 손목(0번 랜드마크)을 기준으로 모든 랜드마크를 이동시켜 원점을 맞춥니다
        base = landmarks[0]
        return landmarks - base

    def _normalize_scale(self, landmarks):
        # 손목과 중지 손허리뼈(9번) 사이의 거리를 기준으로 크기를 정규화
        scale_factor = np.linalg.norm(landmarks[9])
        if scale_factor < 1e-6 or np.isnan(scale_factor):
            return None
        return landmarks / scale_factor

    def _normalize_rotation(self, landmarks):
        # 손목-중지 손허리뼈 벡터를 X축에 정렬하도록 2D 회전하여 방향을 정규화
        x_vec = landmarks[9, :2]  # X, Y 좌표만 사용
        angle = np.arctan2(x_vec[1], x_vec[0])
        
        cos_angle = np.cos(-angle)
        sin_angle = np.sin(-angle)
        rot_mat = np.array([[cos_angle, -sin_angle],
                            [sin_angle,  cos_angle]])

        # 2D 회전 적용 (Z축은 변경하지 않음)
        rotated_landmarks = landmarks.copy()
        rotated_landmarks[:, :2] = rotated_landmarks[:, :2] @ rot_mat.T
        return rotated_landmarks

class DataProcessor:
    # 이미지에서 랜드마크를 추출하고 전처리하며, 라벨 맵을 생성
    def __init__(self, config: Config, strategy: PreprocessingStrategy):
        self.config = config
        self.strategy = strategy
        self.mp_hands = mp.solutions.hands
        self.hands = self.mp_hands.Hands(static_image_mode=True, max_num_hands=1, min_detection_confidence=0.5)

    def process(self):
        landmarks_data = []
        labels = []

        folder_names = sorted([f for f in os.listdir(self.config.IMAGE_DATA_DIR) if os.path.isdir(os.path.join(self.config.IMAGE_DATA_DIR, f))])
        
        self._create_and_save_label_map(folder_names)

        for folder in folder_names:
            folder_path = os.path.join(self.config.IMAGE_DATA_DIR, folder)
            if not os.path.isdir(folder_path):
                continue

            for img_name in os.listdir(folder_path):
                img_path = os.path.join(folder_path, img_name)
                image = cv2.imread(img_path)
                if image is None:
                    logger.warning(f"----- 이미지를 로드할 수 없습니다: {img_path}")
                    continue

                image_rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
                results = self.hands.process(image_rgb)

                if not results.multi_hand_landmarks:
                    logger.warning(f"----- 손을 감지하지 못했습니다: {img_path}")
                    continue

                hand_landmarks = results.multi_hand_landmarks[0]
                handedness = results.multi_handedness[0].classification[0].label
                landmark_points = [[lm.x, lm.y, lm.z] for lm in hand_landmarks.landmark]
                
                feature_vector = self.strategy.preprocess(landmark_points, handedness)

                if feature_vector is None:
                    logger.warning(f"----- 정규화 실패: {img_path}")
                    continue

                landmarks_data.append(feature_vector)
                labels.append(folder) # 라벨로 폴더 이름 사용
                logger.info(f"----- 처리 완료: {img_path} (라벨: {folder})")

        df = pd.DataFrame(landmarks_data)
        df.insert(0, "label", labels)
        
        os.makedirs(self.config.PROCESSED_DATA_DIR, exist_ok=True)
        df.to_csv(self.config.LANDMARK_CSV_PATH, index=False)
        logger.info(f"----- CSV 데이터 저장 완료! -> {self.config.LANDMARK_CSV_PATH}")

    def _create_and_save_label_map(self, folder_names):
        # 폴더 이름으로부터 라벨 맵을 생성하고 JSON 파일로 저장
        label_map = {"none": 0} # 'none'을 0번 인덱스로 고정
        current_index = 1
        for label in sorted(folder_names):
            if label.lower() != "none":
                label_map[label] = current_index
                current_index += 1
        
        with open(self.config.LABEL_MAP_PATH, 'w') as f:
            json.dump(label_map, f, indent=4)
        logger.info(f"----- 라벨 맵 저장 완료: {self.config.LABEL_MAP_PATH}")