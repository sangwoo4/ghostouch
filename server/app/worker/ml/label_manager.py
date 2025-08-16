import numpy as np
import pandas as pd
from app.core import PathConfig


class LabelManager:
    def __init__(self, basic_data, combine_data):
        self.basic_data = basic_data
        self.combine_data = combine_data

        self.basic_data[: -1] = self.basic_data[: -1].astype(str)
        self.combine_data[: -1] = self.combine_data[: -1].astype(str)

    def get_base_labels(self):
        y = self.basic_data[:, -1]
        return list(pd.unique(y)) # np.unique() 변경

    def get_combine_labels(self):
        y = self.combine_data[:, -1]
        # CSV 등장 순서 보존
        return list(pd.unique(y)) # np.unique() 변경

    def build_label_map(self):
        base_labels = self.get_base_labels()
        combine_labels = self.get_combine_labels()

        base_set = set(base_labels)
        new_labels = [l for l in combine_labels if l not in base_set]

        final_label_order = base_labels + new_labels
        label_map = {label: i for i, label in enumerate(final_label_order)}
        return label_map, final_label_order