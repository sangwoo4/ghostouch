import os
import cv2
import mediapipe as mp
import numpy as np
import pandas as pd
import logging
import json
from config import Config

logger = logging.getLogger(__name__)

class DataProcessor:
    # 이미지에서 월드 랜드마크를 추출하고 전처리
    def __init__(self, config: Config, data_dirs: list = None, output_csv_path: str = None, label_map_path: str = None):
        self.config = config
        self.mp_hands = mp.solutions.hands
        self.hands = self.mp_hands.Hands(static_image_mode=True, max_num_hands=1, min_detection_confidence=0.5)
        self.image_data_dirs = data_dirs if data_dirs else [self.config.BASIC_IMAGE_DATA_DIR]
        self.output_csv_path = output_csv_path if output_csv_path else self.config.LANDMARK_CSV_PATH
        self.label_map_path = label_map_path if label_map_path else self.config.BASIC_LABEL_MAP_PATH

    def create_label_map(self):
        # 이미지 데이터 디렉토리에서 라벨 맵을 생성하고 저장
        all_folder_names = set()
        for data_dir in self.image_data_dirs:
            if os.path.exists(data_dir):
                for f in os.listdir(data_dir):
                    if os.path.isdir(os.path.join(data_dir, f)):
                        all_folder_names.add(f)
        label_map = {"none": 0}
        current_index = 1
        for label in sorted(list(all_folder_names)):
            if label.lower() != "none":
                label_map[label] = current_index
                current_index += 1
        with open(self.label_map_path, 'w') as f:
            json.dump(label_map, f, indent=4)
        logging.info(f"----- 라벨 맵 저장 완료: {self.label_map_path}")

    def process(self):
        landmarks_data = []
        labels = []

        # 여러 데이터 디렉토리에서 이미지를 처리
        for data_dir in self.image_data_dirs:
            if not os.path.exists(data_dir):
                logger.warning(f"----- 데이터 디렉토리를 찾을 수 없습니다: {data_dir}")
                continue
            
            folder_names = sorted([f for f in os.listdir(data_dir) if os.path.isdir(os.path.join(data_dir, f))])

            for folder in folder_names:
                folder_path = os.path.join(data_dir, folder)
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

                    if not results.multi_hand_world_landmarks:
                        logger.warning(f"----- 손을 감지하지 못했습니다: {img_path}")
                        continue

                    hand_world_landmarks = results.multi_hand_world_landmarks[0]
                    handedness = results.multi_handedness[0].classification[0].label
                    
                    # 월드 랜드마크를 직접 사용하고 평탄화
                    landmark_points = np.array([[lm.x, lm.y, lm.z] for lm in hand_world_landmarks.landmark], dtype=np.float32).flatten()
                    
                    # 오른손: 0, 왼손: 1
                    handedness_val = 0 if handedness == "Right" else 1
                    
                    feature_vector = np.concatenate([landmark_points, [handedness_val]])

                    landmarks_data.append(feature_vector)
                    labels.append(folder) # 라벨로 폴더 이름 사용
                    logger.info(f"----- 처리 완료: {img_path} (라벨: {folder})")

        df = pd.DataFrame(landmarks_data)
        df.insert(0, "label", labels)
        
        os.makedirs(self.config.PROCESSED_DATA_DIR, exist_ok=True)
        df.to_csv(self.output_csv_path, index=False)
        logger.info(f"----- CSV 데이터 저장 완료! -> {self.output_csv_path}")

    