# 👋 Gesture Recognition Project

This is a deep learning project that recognizes hand gestures (e.g., 'rock', 'paper', 'scissors') in real-time via webcam. It extracts hand landmarks using MediaPipe and classifies gestures with a CNN model based on TensorFlow/Keras.

**All code and trained models in this project are distributed under the MIT License.**

--- 

## ✨ Key Features

-   **Real-time Gesture Recognition**: Detects and classifies hand gestures instantly using a webcam.
-   **Incremental Learning**: Efficiently adds new gestures to an existing trained model.
-   **Multiprocessing-based Data Processing**: Extracts hand landmarks from images in parallel, significantly speeding up preprocessing.
-   **Automatic Label Map Management**: Dynamically generates label maps based on image folder structure and seamlessly integrates multiple label maps without conflicts.
-   **Class Imbalance Handling**: Automatically compensates for class imbalances within the dataset, effectively training on new gestures with limited data.
-   **Model Training and Conversion**: Trains a CNN model and automatically converts it into a TensorFlow Lite (`.tflite`) model optimized for real-time inference.
-   **Modular Structure**: Code is clearly separated by function (configuration, data processing, model training, real-time testing), making it easy to maintain and extend.

--- 

## 📂 Project Structure

```
gesture/
├── data/
│   ├── image_data/         # Original images for basic training (rock, paper, scissors)
│   ├── new_image_data/     # New gesture images for incremental learning (e.g., 'one')
│   └── processed/          # Processed data (csv, npy, etc.)
├── models/
│   ├── basic_gesture_model.keras # Basic trained Keras model
│   ├── basic_gesture_model.tflite# Basic trained TFLite model
│   ├── basic_label_map.json      # Basic gesture label map
│   ├── combine_gesture_model.keras # Incremental learning updated combined Keras model
│   ├── combine_gesture_model.tflite# Incremental learning updated combined TFLite model
│   └── combine_label_map.json      # Combined gesture label map
└── src/
    ├── main.py             # Executes data processing and model training pipeline
    ├── live_test.py        # Executes real-time gesture recognition
    ├── config.py           # Manages project configurations
    ├── data_processor.py   # Image preprocessing and landmark extraction
    ├── data_manager.py     # Dataset splitting, merging, and label management
    └── model_trainer.py    # Model definition and training
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

After activating the virtual environment, install the required libraries:

```bash
pip install -r requirements.txt
```

### 2. Data Preparation

The `gesture/data/image_data/` folder is not included in the Git repository due to copyright and licensing issues. To run the project, please prepare your own training image data and save it in this folder.

To add new gestures or augment existing data, create a folder with the gesture name under the `gesture/data/image_data/` directory and add images.

**Data for Incremental Learning**: For the `gesture/data/new_image_data/` folder, please add **new gesture images captured directly with a camera**. This data will be used for incremental learning along with the existing `image_data`.

For more information on MediaPipe Gesture Recognizer, you can check [here](https://ai.google.dev/edge/mediapipe/solutions/vision/gesture_recognizer?hl=ko).

### 3. Model Training (`main.py`)

Run `main.py` to execute the entire pipeline from data processing to model training. You can select the training mode using the `--mode` argument.

*   **Basic Model Training**:
    Based on images in `gesture/data/image_data/`, it generates `basic_hand_landmarks.csv`, `basic_train_data.npy`, `basic_test_data.npy`, and saves `basic_gesture_model.keras`, `basic_gesture_model.tflite`, `basic_label_map.json` in the `models` folder.
    ```bash
    python gesture/src/main.py --mode train
    ```

*   **Update Combined Model (Incremental Learning)**:
    Uses existing data from `gesture/data/image_data/` and new data from `gesture/data/new_image_data/` to form a combined dataset. It performs incremental learning based on the existing `basic_gesture_model.keras`, saving `combine_gesture_model.keras`, `combine_gesture_model.tflite`, `combine_label_map.json` in the `models` folder. You can specify the path to the base model using the `--base_model_path` argument; if not specified, `basic_gesture_model.keras` will be used by default.
    ```bash
    python gesture/src/main.py --mode update [--base_model_path gesture/models/basic_gesture_model.keras]
    ```

### 4. Real-time Gesture Recognition (`live_test.py`)

Run `live_test.py` to check the performance of the trained model in real-time via webcam. You can select the model to use with the `--model_type` argument.

*   **Test with Basic Model**:
    Performs real-time recognition using `basic_gesture_model.tflite` and `basic_label_map.json`.
    ```bash
    python gesture/src/live_test.py --model_type basic
    ```
    (Or, since `--model_type basic` is the default, you can simply run `python gesture/src/live_test.py`.)

*   **Test with Combined Model**:
    Performs real-time recognition using `combine_gesture_model.tflite` and `combine_label_map.json`.
    ```bash
    python gesture/src/live_test.py --model_type combine
    ```
Press the ESC key to exit the program. If no hand is detected, "none" will be displayed.

--- 

## ⚙️ How It Works

1.  **Data Processing (`data_processor.py`)**:
    -   Reads images from the `image_data` or `new_image_data` folders.
    -   **Multiprocessing** is used with MediaPipe Hands to extract 21 hand landmark coordinates (x, y, z) from each image in parallel.
    -   Normalizes the extracted landmarks for **translation, scale, and rotation** to ensure consistent features regardless of hand position, size, or orientation.
    -   Dynamically generates a label map based on the image folder structure and saves the processed landmark data and integer labels to `basic_hand_landmarks.csv` or `transfer_hand_landmarks.csv` files.

2.  **Data Management (`data_manager.py`)**:
    -   Loads the generated landmark CSV files.
    -   Splits the data into training and testing sets and saves them as NumPy arrays (`.npy`) suitable for model training.
    -   Merges `basic` and `transfer` label maps to create `combine_label_map.json`. It prioritizes `basic` labels' indices and adds only new labels sequentially, **preventing label conflicts**.
    -   When merging `basic` and `transfer` data, it **re-maps** the labels of each dataset based on the combined label map to form an accurate integrated dataset.

3.  **Model Training (`model_trainer.py`)**:
    -   Loads the split `.npy` datasets.
    -   **Basic Training**: Constructs and trains a new CNN (Convolutional Neural Network) model. The best performing model is saved as `basic_gesture_model.keras` and converted to a lightweight `basic_gesture_model.tflite` file.
    -   **Incremental Training**: Loads the existing `basic_gesture_model.keras` as a feature extractor, adds new classification layers, and performs fine-tuning. It **applies `class_weight`** to automatically compensate for class imbalances within the dataset. The trained model is saved as `combine_gesture_model.keras` and converted to `combine_gesture_model.tflite`.

4.  **Real-time Testing (`live_test.py`)**:
    -   Loads the selected model (`basic_gesture_model.tflite` or `combine_gesture_model.tflite`) and its corresponding label map.
    -   Uses OpenCV to get the webcam feed.
    -   Detects hands and extracts landmarks from each frame, then normalizes them in the same way as during training.
    -   Predicts gestures using the TFLite model with the normalized landmarks as input, and displays the results on the screen if the prediction confidence is above `CONFIDENCE_THRESHOLD` (0.8).
    -   The logic has been improved to display "none" if no hand is detected.

--- 

## 🛠️ Key Technologies Used

-   **Python**
-   **TensorFlow / Keras**: Model training and inference
-   **MediaPipe**: Hand landmark extraction
-   **OpenCV**: Real-time video processing
-   **NumPy, Pandas**: Data processing
-   **Scikit-learn**: Data splitting