import os
from app.core import Config

class ModelPathManager:
    def __init__(self, model_id: str):
        config = Config()
        self.model_id = model_id

