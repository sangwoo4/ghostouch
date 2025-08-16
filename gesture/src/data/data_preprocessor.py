import logging
import os
import json
import multiprocessing
from typing import Dict, List, Tuple

import cv2
import mediapipe as mp
import numpy as np
import pandas as pd

from gesture.src.config.file_config import FileConfig

logger = logging.getLogger(__name__)

class DataPreprocessor:
    """
    이미지 파일에서 손 랜드마크를 추출하고 전처리하여 CSV 파일로 저장하는 클래스
    MediaPipe를 사용하여 손의 월드 랜드마크를 감지하고 이를 특징 벡터로 변환하며,
    멀티프로세싱을 사용하여 대량의 이미지를 효율적으로 처리
    """

    def __init__(self, config: FileConfig, data_dirs: List[str] = None, output_csv_path: str = None, label_map_path: str = None):
        """
        DataPreprocessor를 초기화

        Args:
            config (FileConfig): 파일 경로 설정을 담고 있는 FileConfig 객체
            data_dirs (List[str], optional): 처리할 이미지 데이터 디렉토리 목록. 기본값은 config.BASIC_IMAGE_DATA_DIR
            output_csv_path (str, optional): 랜드마크 데이터를 저장할 CSV 파일 경로. 기본값은 config.BASIC_LANDMARK_CSV_PATH
            label_map_path (str, optional): 라벨 맵을 저장할 JSON 파일 경로. 기본값은 config.BASIC_LABEL_MAP_PATH
        """
        self.config = config
        self.image_data_dirs: List[str] = data_dirs if data_dirs else [self.config.BASIC_IMAGE_DATA_DIR]
        self.output_csv_path: str = output_csv_path if output_csv_path else self.config.BASIC_LANDMARK_CSV_PATH
        self.label_map_path: str = label_map_path if label_map_path else self.config.LABEL_MAP_PATHS['basic'] # Changed to use LABEL_MAP_PATHS

    @staticmethod
    def _process_image(args: Tuple[str, str]) -> Tuple[np.ndarray, str] | None:
        """
        단일 이미지를 처리하여 손 랜드마크 특징 벡터와 라벨을 반환하는 정적 메서드
        멀티프로세싱의 `pool.map`에서 사용하기 위해 정적 메서드로 구현

        Args:
            args (Tuple[str, str]): (이미지 파일 경로, 라벨 문자열) 튜플

        Returns:
            Tuple[np.ndarray, str] | None: 특징 벡터와 라벨 튜플 또는 처리 실패 시 None
        """
        img_path, label = args
        # 각 프로세스에서 MediaPipe Hands 객체를 새로 생성해야 함
        mp_hands = mp.solutions.hands
        hands = mp_hands.Hands(static_image_mode=True, max_num_hands=1, min_detection_confidence=0.5)

        image = cv2.imread(img_path)
        if image is None:
            logger.warning(f"----- 이미지를 로드할 수 없습니다: {img_path}")
            return None

        image_rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
        results = hands.process(image_rgb)
        hands.close()

        if not results.multi_hand_world_landmarks:
            return None

        hand_world_landmarks = results.multi_hand_world_landmarks[0]
        handedness = results.multi_handedness[0].classification[0].label
        
        # 21개의 3D 월드 랜드마크(x, y, z)를 1차원 배열로 평탄화
        landmark_points = np.array([[lm.x, lm.y, lm.z] for lm in hand_world_landmarks.landmark], dtype=np.float32).flatten()
        # 오른손(Right)은 0, 왼손(Left)은 1로 인코딩
        handedness_val = 0 if handedness == "Right" else 1
        # 랜드마크 벡터와 손 방향 값을 합쳐 최종 특징 벡터 생성
        feature_vector = np.concatenate([landmark_points, [handedness_val]])

        return feature_vector, label

    def process(self) -> Dict[str, int] | None:
        """
        지정된 이미지 디렉토리의 모든 이미지를 순회하며 랜드마크를 추출하고 CSV로 저장
        추출된 라벨 맵을 반환

        Returns:
            Dict[str, int] | None: 라벨 문자열을 정수 인덱스에 매핑하는 딕셔너리 또는 처리 실패 시 None
        """
        all_image_paths_and_labels: List[Tuple[str, str]] = []
        for data_dir in self.image_data_dirs:
            if not os.path.exists(data_dir):
                logger.warning(f"----- 데이터 디렉토리를 찾을 수 없습니다: {data_dir}")
                continue
            
            for folder_name in sorted(os.listdir(data_dir)):
                folder_path = os.path.join(data_dir, folder_name)
                if not os.path.isdir(folder_path):
                    continue

                for img_name in os.listdir(folder_path):
                    img_path = os.path.join(folder_path, img_name)
                    all_image_paths_and_labels.append((img_path, folder_name))
        
        if not all_image_paths_and_labels:
            logger.warning("----- 처리할 이미지가 없습니다.")
            return None

        logger.info(f"----- 총 {len(all_image_paths_and_labels)}개의 이미지 처리 시작 (멀티프로세싱)")
        
        # CPU 코어 수를 최대로 활용하여 병렬 처리
        with multiprocessing.Pool(processes=multiprocessing.cpu_count()) as pool:
            results = pool.map(DataPreprocessor._process_image, all_image_paths_and_labels)

        landmarks_data: List[np.ndarray] = []
        string_labels: List[str] = []

        for result in results:
            if result is not None:
                feature_vector, label = result
                landmarks_data.append(feature_vector)
                string_labels.append(label)
        
        if not landmarks_data:
            logger.error("----- 유효한 랜드마크 데이터가 없습니다. 손이 감지된 이미지가 없거나 처리 중 오류가 발생했습니다.")
            return None

        # 이미지 폴더 이름(문자열 라벨)으로부터 동적으로 라벨 맵(JSON) 생성 및 저장
        unique_string_labels = sorted(list(set(string_labels)))
        label_map: Dict[str, int] = {}
        for i, label_str in enumerate(unique_string_labels):
            label_map[label_str] = i
        
        os.makedirs(os.path.dirname(self.label_map_path), exist_ok=True)
        with open(self.label_map_path, 'w') as f:
            json.dump(label_map, f, indent=4)
        logger.info(f"----- 라벨 맵 저장 완료: {self.label_map_path}")

        df = pd.DataFrame(landmarks_data)
        df.insert(0, "label", string_labels) # 라벨 컬럼을 첫 번째에 삽입
        
        os.makedirs(self.config.PROCESSED_DATA_DIR, exist_ok=True)
        df.to_csv(self.output_csv_path, index=False)
        logger.info(f"----- CSV 데이터 저장 완료! -> {self.output_csv_path}")

        return label_map