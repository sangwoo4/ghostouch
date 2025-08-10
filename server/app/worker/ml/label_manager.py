import numpy as np

from app.core import PathConfig


class LabelManager:
    def __init__(self, basic_data, combine_data):
        self.basic_data = basic_data
        self.combine_data = combine_data

        self.basic_data[: -1] = self.basic_data[: -1].astype(str)
        self.combine_data[: -1] = self.combine_data[: -1].astype(str)

    def get_base_labels(self):
        y = self.basic_data[:, -1]
        return list(np.unique(y))

    def get_combine_labels(self):
        return np.unique(self.combine_data[:, -1])


    def build_label_map(self):
        base_labels = self.get_base_labels()
        combine_labels = self.get_combine_labels()
        new_labels = [label for label in combine_labels if label not in base_labels]
        final_label_order = base_labels + list(new_labels)
        label_map = {label: i for i, label in enumerate(final_label_order)}
        return label_map, final_label_order