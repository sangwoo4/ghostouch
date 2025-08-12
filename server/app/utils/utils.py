import io
import time, uuid

import numpy as np
import pandas as pd

def generate_model_id():
    timestamp = int(time.time())
    uid = uuid.uuid4().hex[:8]
    return f"{timestamp}_{uid}"

def preprocess_landmarks(feature_vector):
    """
    # 1. 64개 데이터에서 좌표 데이터(앞 63개)와 손(left, right) 분리
    """

    feature_vector_np = np.array(feature_vector)
    coords_flat = feature_vector_np[:-1]
    handedness_val = feature_vector_np[-1]

    # 2. 63개의 1차원 좌표 데이터를 (21, 3) 형태의 2차원 배열로 변환합니다.
    landmarks = np.array(coords_flat).reshape(21, 3)

    # 3. 중앙 정렬(0번 기준)
    base_x, base_y, base_z = landmarks[0]
    landmarks[:, 0] -= base_x
    landmarks[:, 1] -= base_y
    landmarks[:, 2] -= base_z

    scale_factor = np.linalg.norm(landmarks[0] - landmarks[9])
    if scale_factor > 0:
        landmarks /= scale_factor

    # 5. 정규화된 좌표를 다시 1차원으로 펴고, 원래의 손 정보를 뒤에 붙입니다.
    normalized_vector = np.concatenate([landmarks.flatten(), [handedness_val]])
    return normalized_vector

def convert_landmarks_to_csv(landmarks: list, incremental_csv_path: str, gesture: str):

    # normalized_landmarks_data = []
    # for feature_vector in landmarks:
    #     normalized_vector = preprocess_landmarks(feature_vector)
    #     normalized_landmarks_data.append(normalized_vector)

    #df = pd.DataFrame(normalized_landmarks_data)
    df = pd.DataFrame(landmarks)
    # 'gesture' 값을 첫 번째 'label' 열에 추가합니다.
    df.insert(0, "label", [gesture] * len(df))

    # CSV 파일로 저장합니다.
    df.to_csv(incremental_csv_path, index=False)
    print(f" CSV 데이터 저장 완료! -> {incremental_csv_path}")