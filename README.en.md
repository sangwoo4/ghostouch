# 👋 Gesture Recognition Project

This is a deep learning project that recognizes hand gestures (e.g., 'rock', 'paper', 'scissors') in real-time via webcam. It extracts hand landmarks using MediaPipe and classifies gestures with a CNN model based on TensorFlow/Keras.

**All code and trained models in this project are distributed under the MIT License.**

--- 

## ✨ Key Features

-   **Real-time Gesture Recognition**: Detects and classifies hand gestures instantly using a webcam.
-   **Data Processing Pipeline**: Automatically generates a dataset for training by extracting and normalizing hand landmarks from images.
-   **Model Training and Conversion**: Trains a CNN model and automatically converts it into a TensorFlow Lite (`.tflite`) model optimized for real-time inference.
-   **Modular Structure**: Code is clearly separated by function (configuration, data processing, model training, real-time testing), making it easy to maintain and extend.
-   **Basic and Transfer Learning Support**: Supports both basic gesture training and transfer learning for adding new gestures.

--- 

## 📂 Project Structure

```
gesture/
├── data/
│   ├── image_data/         # Original images for basic training (rock, paper, scissors, etc.)
│   ├── new_image_data/     # New gesture images for transfer learning
│   └── processed/          # Processed data (basic_hand_landmarks.csv, transfer_hand_landmarks.csv, etc.)
├── models/
│   ├── basic_gesture_model.keras # Basic trained Keras model
│   ├── basic_gesture_model.tflite# Basic trained TFLite model
│   ├── basic_label_map.json      # Basic gesture label map
│   ├── transfer_gesture_model.keras # Transfer trained Keras model
│   ├── transfer_gesture_model.tflite# Transfer trained TFLite model
│   └── transfer_label_map.json      # Transfer trained gesture label map
└── src/
    ├── main.py             # Executes data processing and model training pipeline
    ├── live_test.py        # Executes real-time gesture recognition
    ├── config.py           # Manages project configurations
    ├── data_processor.py   # Image preprocessing and landmark extraction
    ├── data_manager.py     # Dataset splitting and saving
    └── model_trainer.py    # Model definition and training
```

--- 

## 🚀 Getting Started

### 1. Environment Setup

Install the necessary libraries to run the project.

```bash
pip install -r requirements.txt
```

### 2. Data Preparation

The `gesture/data/image_data/` folder is not included in the Git repository due to copyright and licensing issues. To run the project, please prepare your own training image data and save it in this folder.

To add new gestures or augment existing data, create a folder with the gesture name under the `gesture/data/image_data/` directory and add images.

**Data for Transfer Learning**: For the `gesture/data/new_image_data/` folder, please add **new gesture images captured directly with a camera**. This data will be used for transfer learning along with the existing `image_data`.

For more information on MediaPipe Gesture Recognizer, you can check [here](https://ai.google.dev/edge/mediapipe/solutions/vision/gesture_recognizer?hl=ko).

### 3. Model Training (`main.py`)

Run `main.py` to execute the entire pipeline from data processing to model training. You can select the training mode using the `--mode` argument.

*   **Basic Model Training**:
    Based on images in `gesture/data/image_data/`, it generates `basic_hand_landmarks.csv`, `basic_train_data.npy`, `basic_test_data.npy`, and saves `basic_gesture_model.keras`, `basic_gesture_model.tflite`, `basic_label_map.json` in the `models` folder.
    ```bash
    python gesture/src/main.py --mode train
    ```

*   **Transfer Model Training**:
    Uses all data from `gesture/data/image_data/` and `gesture/data/new_image_data/` to create `transfer_hand_landmarks.csv`, `transfer_train_data.npy`, `transfer_test_data.npy`. It performs transfer learning based on the existing `basic_gesture_model.keras`, saving `transfer_gesture_model.keras`, `transfer_gesture_model.tflite`, `transfer_label_map.json` in the `models` folder. You must specify the path to the base model using the `--base_model_path` argument.
    ```bash
    python gesture/src/main.py --mode transfer --base_model_path gesture/models/basic_gesture_model.keras
    ```

### 4. Real-time Gesture Recognition (`live_test.py`)

Run `live_test.py` to check the performance of the trained model in real-time via webcam. You can select the model to use with the `--model_type` argument.

*   **Test with Basic Model**:
    Performs real-time recognition using `basic_gesture_model.tflite` and `basic_label_map.json`.
    ```bash
    python gesture/src/live_test.py --model_type basic
    ```
    (Or, since `--model_type basic` is the default, you can simply run `python gesture/src/live_test.py`.)

*   **Test with Transfer Model**:
    Performs real-time recognition using `transfer_gesture_model.tflite` and `transfer_label_map.json`.
    ```bash
    python gesture/src/live_test.py --model_type transfer
    ```
Press the ESC key to exit the program. If no hand is detected, "none" will be displayed.

--- 

## ⚙️ How It Works

1.  **Data Processing (`data_processor.py`)**:
    -   Reads images from the `image_data` or `new_image_data` folders.
    -   Extracts 21 hand landmark coordinates (x, y, z) from each image using MediaPipe Hands.
    -   Normalizes the extracted landmarks for **translation, scale, and rotation** to ensure consistent features regardless of hand position, size, or orientation.
    -   Saves the processed landmark data and labels to `basic_hand_landmarks.csv` or `transfer_hand_landmarks.csv` files.

2.  **Data Management (`data_manager.py`)**:
    -   Loads the generated landmark CSV files.
    -   Splits the data into training and testing sets and saves them as NumPy arrays (`.npy`) suitable for model training. (e.g., `basic_train_data.npy`, `transfer_test_data.npy`)

3.  **Model Training (`model_trainer.py`)**:
    -   Loads the split `.npy` datasets.
    -   **Basic Training**: Constructs and trains a new CNN (Convolutional Neural Network) model. The best performing model is saved as `basic_gesture_model.keras` and converted to a lightweight `basic_gesture_model.tflite` file.
    -   **Transfer Training**: Loads the existing `basic_gesture_model.keras` as a feature extractor, adds new classification layers, and performs transfer learning. The trained model is saved as `transfer_gesture_model.keras` and converted to `transfer_gesture_model.tflite`.
    -   Generates and saves the appropriate label map (`basic_label_map.json` or `transfer_label_map.json`) for each training mode.

4.  **Real-time Testing (`live_test.py`)**:
    -   Loads the selected model (`basic_gesture_model.tflite` or `transfer_gesture_model.tflite`) and its corresponding label map.
    -   Uses OpenCV to get the webcam feed.
    -   Detects hands and extracts landmarks from each frame, then normalizes them in the same way as during training.
    -   Predicts gestures using the TFLite model with the normalized landmarks as input and displays the results on the screen.
    -   The logic has been improved to display "none" if no hand is detected.

--- 

## 🛠️ Key Technologies Used

-   **Python**
-   **TensorFlow / Keras**: Model training and inference
-   **MediaPipe**: Hand landmark extraction
-   **OpenCV**: Real-time video processing
-   **NumPy, Pandas**: Data processing
-   **Scikit-learn**: Data splitting