import numpy as np
import json

# 라벨맵 로드
with open('gesture/models/transfer_label_map.json', 'r') as f:
    label_map = json.load(f)

# 데이터 로드
data = np.load('gesture/data/processed/transfer_train_data.npy')
labels = data[:, -1].astype(int)
unique_labels, counts = np.unique(labels, return_counts=True)

print("transfer_train_data.npy의 라벨별 데이터 개수:")
for label_val, count in zip(unique_labels, counts):
    # 라벨맵에서 정수 라벨에 해당하는 문자열 라벨 찾기
    label_str = [k for k, v in label_map.items() if v == label_val]
    print(f"  라벨 {label_val} ({label_str[0] if label_str else 'N/A'}): {count}개")
