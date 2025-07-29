import numpy as np
data = np.load('gesture/data/processed/combine_train_data.npy')
labels = data[:, -1].astype(int)
unique_labels, counts = np.unique(labels, return_counts=True)
print("라벨별 데이터 개수:")
for label, count in zip(unique_labels, counts):
    print(f"  라벨 {label}: {count}개")
