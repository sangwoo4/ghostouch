#from app.core import Config
from app.core import celery_app
#from .ml.path_manager import ModelPathManager

import os
import json
import logging
import sys
import numpy as np
import pandas as pd
import tensorflow as tf

from abc import ABC, abstractmethod
from sklearn.model_selection import train_test_split
from sklearn.utils.class_weight import compute_class_weight
from tensorflow.keras.callbacks import EarlyStopping, ReduceLROnPlateau
from tensorflow.keras.layers import Dense, Dropout, Input, Conv1D, MaxPooling1D, Flatten
from tensorflow.keras.models import Sequential, load_model
from tensorflow.keras.utils import to_categorical

@celery_app.task
def archive_other_files_task(files_paths):
    print("Archiving other files")
    return "Archiving Complete"


@celery_app.task
def run_train_and_upload(landmarks, model_id):
    #path_manager = ModelPathManager(model_id)
    print("모델 시작")
    file_paths = "file paths...."
    print("모델 학습 완료")

    print("tflite 업로드 시작.")
    print("tflite 업로드 완료.")

    archive_other_files_task.delay(file_paths)
    tflite_url = "url"
    return tflite_url

