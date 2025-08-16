package com.pentagon.ghostouch

import android.content.Context
import android.util.Log
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarkerResult
import org.json.JSONObject
import org.tensorflow.lite.Interpreter
import java.io.FileInputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.MappedByteBuffer
import java.nio.channels.FileChannel
import kotlin.math.roundToInt

class GestureClassifier(private val context: Context) {

    companion object {
        private const val TAG = "GestureClassifier"
        private const val BASIC_MODEL_NAME = "basic_gesture_model.tflite"
    }

    private var interpreter: Interpreter? = null
    private var reverseLabelMap: Map<Int, String> = emptyMap()

    init {
        loadModel()
        loadLabelMap()
    }

    private fun loadModel() {
        try {
            val modelNameToLoad = TrainingCoordinator.currentModelFileName
            val modelBuffer: MappedByteBuffer

            if (modelNameToLoad != BASIC_MODEL_NAME) {
                val customModelFile = java.io.File(context.filesDir, modelNameToLoad)
                if (customModelFile.exists()) {
                    Log.d(TAG, "커스텀 모델 파일 사용: ${customModelFile.absolutePath}")
                    val inputStream = FileInputStream(customModelFile)
                    val fileChannel = inputStream.channel
                    modelBuffer = fileChannel.map(FileChannel.MapMode.READ_ONLY, 0, fileChannel.size())
                    inputStream.close()
                } else {
                    Log.w(TAG, "커스텀 모델 파일을 찾을 수 없어 기본 모델을 사용합니다: $modelNameToLoad")
                    modelBuffer = loadModelFileFromAssets(BASIC_MODEL_NAME)
                }
            } else {
                Log.d(TAG, "기본 모델 파일 사용: $BASIC_MODEL_NAME")
                modelBuffer = loadModelFileFromAssets(BASIC_MODEL_NAME)
            }

            interpreter = Interpreter(modelBuffer)

            Log.d(TAG, "모델 로드 성공")

            val input = interpreter?.getInputTensor(0)
            val output = interpreter?.getOutputTensor(0)
            Log.d(TAG, "입력 텐서 형태: ${input?.shape()?.contentToString()}, 타입: ${input?.dataType()}")
            Log.d(TAG, "출력 텐서 형태: ${output?.shape()?.contentToString()}, 타입: ${output?.dataType()}")
        } catch (e: Exception) {
            Log.e(TAG, "모델 로드 실패", e)
        }
    }

    private fun loadLabelMap() {
        try {
            val labelMapFile = java.io.File(context.filesDir, TrainingCoordinator.LABEL_MAP_FILE_NAME)
            val jsonString = if (labelMapFile.exists()) {
                Log.d(TAG, "업데이트된 레이블 맵 파일 사용: ${labelMapFile.absolutePath}")
                labelMapFile.readText()
            } else {
                Log.d(TAG, "기본 레이블 맵 파일 사용")
                context.assets.open("basic_label_map.json").bufferedReader().use { it.readText() }
            }
            
            val jsonObject = JSONObject(jsonString)
            val reverseMap = mutableMapOf<Int, String>()

            jsonObject.keys().forEach { key ->
                val value = jsonObject.getInt(key)
                reverseMap[value] = key
            }
            
            reverseLabelMap = reverseMap

            Log.d(TAG, "레이블 맵 로드됨: $reverseLabelMap")
        } catch (e: Exception) {
            Log.e(TAG, "레이블 맵 로드 실패", e)
        }
    }

    private fun loadModelFileFromAssets(filename: String): MappedByteBuffer {
        val fileDescriptor = context.assets.openFd(filename)
        val inputStream = FileInputStream(fileDescriptor.fileDescriptor)
        val fileChannel = inputStream.channel
        return fileChannel.map(FileChannel.MapMode.READ_ONLY, fileDescriptor.startOffset, fileDescriptor.declaredLength)
    }

    fun classifyGesture(handLandmarkerResult: HandLandmarkerResult): String? {
        if (interpreter == null) {
            Log.e(TAG, "Interpreter is not initialized.")
            return null
        }

        if (handLandmarkerResult.worldLandmarks().isEmpty() || handLandmarkerResult.worldLandmarks()[0].size != 21) {
            return null
        }

        try {
            val worldLandmarks = handLandmarkerResult.worldLandmarks()[0]

            val features = worldLandmarks.flatMap { landmark ->
                listOf(landmark.x(), landmark.y(), landmark.z())
            }.toMutableList()

            val detectedHandedness = handLandmarkerResult.handedness().firstOrNull()?.firstOrNull()?.categoryName()?.lowercase() ?: "right"
            val handednessValue = if (detectedHandedness == "left") 0.0f else 1.0f
            features.add(handednessValue)

            val inputTensor = interpreter!!.getInputTensor(0)
            val outputTensor = interpreter!!.getOutputTensor(0)

            if (inputTensor.dataType() != org.tensorflow.lite.DataType.UINT8) {
                Log.e(TAG, "This classifier only supports UINT8 quantized models.")
                return null
            }

            val quantizationParams = inputTensor.quantizationParams()
            val scale = quantizationParams.scale
            val zeroPoint = quantizationParams.zeroPoint

            val inputBuffer = ByteBuffer.allocateDirect(features.size).order(ByteOrder.nativeOrder())
            for (feature in features) {
                val qv = (feature / scale).roundToInt() + zeroPoint
                inputBuffer.put(qv.coerceIn(0, 255).toByte())
            }
            inputBuffer.rewind()

            val outputBuffer = ByteBuffer.allocateDirect(outputTensor.numBytes()).order(ByteOrder.nativeOrder())
            interpreter!!.run(inputBuffer, outputBuffer)
            outputBuffer.rewind()

            val outputQuantParams = outputTensor.quantizationParams()
            val oScale = outputQuantParams.scale
            val oZeroPoint = outputQuantParams.zeroPoint

            val probs = FloatArray(outputTensor.shape()[1])
            for (i in probs.indices) {
                val q = outputBuffer.get(i).toInt() and 0xFF
                probs[i] = (q - oZeroPoint) * oScale
            }

            val maxIdx = probs.indices.maxByOrNull { probs[it] } ?: -1
            val confidence = if(maxIdx != -1) probs[maxIdx] else 0.0f

            val result = if (confidence < 0.5f || maxIdx >= reverseLabelMap.size) {
                "none"
            } else {
                val gesture = reverseLabelMap[maxIdx] ?: "unknown"
                "$gesture (${String.format("%.0f", confidence * 100)}%)"
            }

            Log.d(TAG, "Classification Result: $result")

            return result

        } catch (e: Exception) {
            Log.e(TAG, "Error during gesture classification", e)
            return null
        }
    }

    fun close() {
        interpreter?.close()
    }
}
