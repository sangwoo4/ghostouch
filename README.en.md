# 👋 Gesture Recognition Project: Incremental Learning and Automated Evaluation Pipeline

<!-- TOC Start -->
- [✨ Key Features](#-key-features)
- [📂 Project Structure](#-project-structure)
- [🚀 Getting Started](#-getting-started)
  - [1. Environment Setup](#1-environment-setup)
  - [2. Data Preparation](#2-data-preparation)
  - [3. Model Training & Evaluation (`main.py`)](#3-model-training--evaluation-mainpy)
  - [4. Real-time Gesture Recognition (`live_test.py`)](#4-real-time-gesture-recognition-live-testpy)
- [💻 System Requirements & Dependencies](#-system-requirements--dependencies)
- [⚙️ How It Works](#-how-it-works)
- [🛠️ Key Technologies Used](#-key-technologies-used)
<!-- TOC End -->

This is a deep learning project that recognizes hand gestures (e.g., 'rock', 'paper', 'scissors') in real-time via webcam. It extracts hand landmarks using MediaPipe, classifies gestures with a CNN model based on TensorFlow/Keras, and automatically evaluates the model performance after training.

**All code and trained models in this project are distributed under the MIT License.**

---

## ✨ Key Features
-   **Real-time Gesture Recognition**: Detects and classifies hand gestures instantly using a webcam.<br><br>
-   **Incremental Learning**: Efficiently adds new gestures to an existing trained model.<br><br>
-   **Integrated Pipeline**: Executes data preprocessing, model training, and performance evaluation with a single command.<br><br>
-   **Automated Model Evaluation**: Automatically generates a performance report with various metrics, including a confusion matrix and ROC/PR curves, immediately after model training.<br><br>
-   **Multiprocessing-based Data Processing**: Extracts hand landmarks from images in parallel, significantly speeding up preprocessing.<br><br>
-   **Automatic Label Map Management**: Dynamically generates label maps based on image folder structure and seamlessly integrates multiple label maps without conflicts.<br><br>
-   **Class Imbalance Handling**: Automatically compensates for class imbalances within the dataset, effectively training on new gestures with limited data.<br><br>
-   **Modular Structure**: Code is clearly separated by function (configuration, data processing, model training, evaluation, testing), making it easy to maintain and extend.<br><br>

---

## 📂 Project Structure

```
gesture/
├── analysis/             # Stores model evaluation results
│   └── results/
│       ├── basic_model_evaluation/
│       └── combine_model_evaluation/
├── data/
│   ├── image_data/         # Original images for basic training
│   ├── new_image_data/     # New gesture images for incremental learning
│   └── processed/          # Processed data (csv, npy, etc.)
├── models/                 # Generated models and data (keras, tflite, json, etc.)
└── src/
    ├── main.py             # Executes the entire training and evaluation pipeline
    ├── config/             # Project configuration management
    │   ├── analysis_config.py
    │   ├── file_config.py
    │   └── train_config.py
    ├── data/               # Data processing related modules
    ├── label/              # Label processing related modules
    ├── model/              # Model architecture definition
    ├── train/              # Model training related modules
    └── utils/              # Utility modules
        ├── duplicate_checker.py    # Logic for preventing data duplication
        ├── evaluation.py           # Model evaluation logic
        └── live_test.py            # Executes real-time gesture recognition
```

---

## 🚀 Getting Started

### 1. Environment Setup

It is recommended to create and activate a Python virtual environment before installing the necessary libraries.

```bash
# Create a virtual environment (venv)
python -m venv venv

# Activate the virtual environment
# Windows
.\venv\Scripts\activate

# macOS/Linux
source venv/bin/activate
```

After activating the virtual environment, upgrade pip and install the required libraries:

```bash
# Upgrade pip
python -m pip install --upgrade pip

# Install libraries
pip install -r requirements.txt
```

### 2. Data Preparation

The `gesture/data/image_data/` folder is not included in the Git repository due to copyright and licensing issues. To run the project, please prepare your own training image data and save it in this folder.

To add new gestures, create a folder with the gesture name under the `gesture/data/new_image_data/` directory and add your images.

For more information on MediaPipe Gesture Recognizer, you can check [here](https://ai.google.dev/edge/mediapipe/solutions/vision/gesture_recognizer?hl=ko).

### 3. Model Training & Evaluation (`main.py`)

`main.py` is an integrated script that runs the entire pipeline from data processing and model training to **performance evaluation**. Use the `--mode` argument to select the execution mode.

*   **Basic Model Training & Evaluation**:
    Trains a model based on images in `gesture/data/image_data/` and immediately performs a performance evaluation upon completion. The evaluation results are saved in the `gesture/analysis/results/basic_model_evaluation/` folder.
    ```bash
    python gesture/src/main.py --mode train
    ```

*   **Combined Model Update & Evaluation (Incremental Learning)**:
    Updates the model using both existing data and new data from `gesture/data/new_image_data/`, and immediately performs a performance evaluation upon completion. The evaluation results are saved in the `gesture/analysis/results/combine_model_evaluation/` folder.
    ```bash
    python gesture/src/main.py --mode update
    ```

### 4. Real-time Gesture Recognition (`live_test.py`)

Run `live_test.py` to check the performance of the trained model in real-time via webcam. You can select the model to use with the `--model_type` argument.

*   **Test with Basic Model**:
    ```bash
    python gesture/src/utils/live_test.py --model_type basic
    ```

*   **Test with Combined Model**:
    ```bash
    python gesture/src/utils/live_test.py --model_type combine
    ```
Press the ESC key to exit the program.

## 💻 System Requirements & Dependencies

This project has been tested in a Python 3.10+ environment. Please refer to the `requirements.txt` file for major library versions.

*   **Python**: 3.10+
*   **TensorFlow**: 2.x
*   **MediaPipe**: 0.x
*   **OpenCV**: 4.x

---

## ⚙️ How It Works

1.  **Data Processing (`data_preprocessor.py`)**:
    -   Reads images from image folders and extracts hand landmarks in parallel using **multiprocessing**.
    -   Normalizes the extracted landmarks for translation, scale, and rotation to ensure consistent features.
    -   Dynamically generates a label map based on the folder structure and saves the processed data to a CSV file.

2.  **Data Management (`data_combiner.py` & `data_converter.py`)**:
    -   Converts the CSV file into NumPy arrays (`.npy`) suitable for model training.
    -   For incremental learning, it merges existing and new data, and combines label maps without conflicts.

3.  **Model Training (`model_train.py`)**:
    -   Loads the `.npy` datasets to train a CNN model.
    -   For **incremental learning**, it loads an existing model and fine-tunes it on the new data, applying `class_weight` to automatically handle data imbalance.
    -   Saves the trained Keras model (`.keras`) and a TFLite model (`.tflite`).

4.  **Model Evaluation (`evaluation.py`)**:
    -   This step is automatically executed at the end of the training pipeline in `main.py`.
    -   The `ModelEvaluator` class loads the saved model and test data.
    -   It generates various quantitative and visual metrics, such as a **performance report (.txt)**, **confusion matrix (.png)**, and **ROC/PR curves (.png)**, and saves them to the `gesture/analysis/results/` folder.

5.  **Real-time Testing (`live_test.py`)**:
    -   Loads the lightweight `.tflite` model and uses OpenCV to apply it to the live webcam feed.
    -   Extracts and normalizes landmarks from each frame in real-time, predicts the gesture, and displays the result.

---

## 🛠️ Key Technologies Used

-   **Python**
-   **TensorFlow / Keras**: Model training and inference
-   **MediaPipe**: Hand landmark extraction
-   **OpenCV**: Real-time video processing
-   **NumPy, Pandas**: Data processing
-   **Scikit-learn**: Data splitting