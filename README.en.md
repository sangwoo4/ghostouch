# Gesture Recognition Project

This is a deep learning project that recognizes hand gestures (e.g., 'scissors', 'rock', 'paper') in real-time through a webcam. It extracts hand landmarks using MediaPipe and classifies gestures with a CNN model based on TensorFlow/Keras.

## ✨ Key Features

-   **Real-time Gesture Recognition**: Instantly detects and classifies hand gestures using a webcam.
-   **Data Processing Pipeline**: Automatically generates a training dataset by extracting and normalizing hand landmarks from images.
-   **Model Training and Conversion**: Trains a CNN model and automatically converts it to a TensorFlow Lite (`.tflite`) model optimized for real-time inference.
-   **Modular Structure**: The code is clearly separated by function (configuration, data processing, model training, real-time testing), making it easy to maintain and expand.

## 📂 Project Structure

```
gesture/
├── data/
│   ├── image_data/         # Original images for training (scissors, rock, paper, etc.)
│   └── processed/          # Preprocessed data (landmark.csv, train_data.npy)
├── models/
│   ├── gesture_model.keras # Trained Keras model
│   ├── gesture_model.tflite # Converted TFLite model
│   └── label_map.json      # Gesture label map
└── src/
    ├── main.py             # Executes the data processing and model training pipeline
    ├── live_test.py        # Runs real-time gesture recognition
    ├── config.py           # Manages project configuration
    ├── data_processor.py   # Image preprocessing and landmark extraction
    ├── data_manager.py     # Dataset splitting and saving
    └── model_trainer.py    # Model definition and training
```

## 🚀 Getting Started

### 1. Environment Setup

Install the necessary libraries to run the project.

```bash
pip install -r requirements.txt
```

### 2. Data Preparation

The `gesture/data/image_data/` folder is not included in the Git repository due to copyright and license issues. To run the project, you must prepare your own training image data and save it in this folder.

To add new gestures or augment existing data, create a folder with the gesture name under the `gesture/data/image_data/` directory and add images. For more information on MediaPipe Gesture Recognizer, you can check [here](https://ai.google.dev/edge/mediapipe/solutions/vision/gesture_recognizer?hl=en).

### 3. Model Training

Run `main.py` to execute the entire pipeline from data processing to model training. This process generates `processed` data based on the images in `image_data` and saves a new model in the `models` folder.

```bash
python gesture/src/main.py
```

### 4. Real-time Gesture Recognition

Run `live_test.py` to check the performance of the trained model in real-time through the webcam.

```bash
python gesture/src/live_test.py
```

Press the ESC key to exit the program.

## ⚙️ How It Works

1.  **Data Processing (`data_processor.py`)**:
    -   Reads images from the `image_data` folder.
    -   Extracts 21 hand landmark coordinates (x, y, z) from each image using MediaPipe Hands.
    -   Normalizes the extracted landmarks for **translation, scale, and rotation** to ensure consistent feature learning regardless of the hand's position, size, or orientation.
    -   Saves the processed landmark data and labels to a `hand_landmarks.csv` file.

2.  **Data Management (`data_manager.py`)**:
    -   Loads the `hand_landmarks.csv` file.
    -   Splits the data into training and testing sets and saves them in a NumPy array (`.npy`) format suitable for model training.

3.  **Model Training (`model_trainer.py`)**:
    -   Loads the split `.npy` dataset.
    -   Constructs a Convolutional Neural Network (CNN) model.
    -   Trains the model and saves the best-performing model as `gesture_model.keras`.
    -   Converts the saved Keras model to a lightweight `gesture_model.tflite` file to optimize real-time inference performance.

4.  **Real-time Testing (`live_test.py`)**:
    -   Loads the `gesture_model.tflite` model and `label_map.json`.
    -   Uses OpenCV to capture the webcam feed.
    -   Detects the hand in each frame, extracts landmarks, and normalizes them in the same way as during training.
    -   Predicts the gesture using the TFLite model with the normalized landmarks as input and displays the result on the screen.

## 🛠️ Key Technology Stack

-   **Python**
-   **TensorFlow / Keras**: Model training and inference
-   **MediaPipe**: Hand landmark extraction
-   **OpenCV**: Real-time video processing
-   **NumPy, Pandas**: Data processing
-   **Scikit-learn**: Data splitting
