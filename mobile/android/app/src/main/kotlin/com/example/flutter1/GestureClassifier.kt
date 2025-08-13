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

// 손 제스처를 분류하는 클래스 (TFLite 모델 기반)
class GestureClassifier(private val context: Context) {

    companion object {
        private const val TAG = "GestureClassifier"
    }

    // TFLite 추론기
    private var interpreter: Interpreter? = null

    // "정수 라벨" -> "gesture name" 역매핑
    private var reverseLabelMap: Map<Int, String> = emptyMap()

    init {
        // 모델과 레이블맵 초기화
        loadModel()
        loadLabelMap()
    }

    // TFLite 모델 로드 함수
    private fun loadModel() {
        try {
            val modelBuffer = loadModelFile("basic_gesture_model.tflite")
            interpreter = Interpreter(modelBuffer)

            Log.d(TAG, "모델 로드 성공")

            // 입력/출력 텐서 형태 확인
            val input = interpreter?.getInputTensor(0)
            val output = interpreter?.getOutputTensor(0)
            Log.d(TAG, "입력 텐서 형태: ${input?.shape()?.contentToString()}, 타입: ${input?.dataType()}")
            Log.d(TAG, "출력 텐서 형태: ${output?.shape()?.contentToString()}, 타입: ${output?.dataType()}")
        } catch (e: Exception) {
            Log.e(TAG, "모델 로드 실패", e)
        }
    }

    // JSON 파일로부터 레이블 맵 로드
    private fun loadLabelMap() {
        try {
            // 자산 폴더에서 basic_label_map.json 읽기
            val jsonString = context.assets.open("basic_label_map.json").bufferedReader().use { it.readText() }
            val jsonObject = JSONObject(jsonString)

            val reverseMap = mutableMapOf<Int, String>()

            // 각 제스처 이름과 인덱스를 맵에 추가
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

    // 모델 파일을 메모리 매핑 방식으로 로드
    private fun loadModelFile(filename: String): MappedByteBuffer {
        val fileDescriptor = context.assets.openFd(filename)
        val inputStream = FileInputStream(fileDescriptor.fileDescriptor)
        val fileChannel = inputStream.channel
        return fileChannel.map(FileChannel.MapMode.READ_ONLY, fileDescriptor.startOffset, fileDescriptor.declaredLength)
    }

    // 제스처 분류 함수 (worldLandmarks 사용)
    fun classifyGesture(handLandmarkerResult: HandLandmarkerResult): String? {
        if (interpreter == null) {
            Log.e(TAG, "Interpreter is not initialized.")
            return null
        }

        // 1. worldLandmarks를 사용하고, 랜드마크가 21개인지 확인
        if (handLandmarkerResult.worldLandmarks().isEmpty() || handLandmarkerResult.worldLandmarks()[0].size != 21) {
            return null // 손 감지 안됨
        }

        try {
            val worldLandmarks = handLandmarkerResult.worldLandmarks()[0]

            // 2. 랜드마크를 1차원 Float 리스트로 변환 (21 * 3 = 63)
            val features = worldLandmarks.flatMap { landmark ->
                listOf(landmark.x(), landmark.y(), landmark.z())
            }.toMutableList()

            // 3. 손 방향(handedness) 정보 추가 - 보정 없이 감지된 값 그대로 사용해보기
            val detectedHandedness = handLandmarkerResult.handedness().firstOrNull()?.firstOrNull()?.categoryName()?.lowercase() ?: "right"
            Log.d(TAG, "Handedness -> Detected: $detectedHandedness (using as-is for testing)")

            val handednessValue = if (detectedHandedness == "left") 0.0f else 1.0f
            features.add(handednessValue)

            // --- 로깅 추가 (Swift 코드 스타일) ---
            // 매 프레임의 입력 벡터를 상세히 출력
            val formattedFeatures = features.joinToString(separator = ", ") { String.format("%.15f", it.toDouble()) }
            Log.d(TAG, "Input Vector (64): [$formattedFeatures]")
            // --- 로깅 끝 ---

            // 4. 입력 텐서 준비 및 양자화
            val inputTensor = interpreter!!.getInputTensor(0)
            val outputTensor = interpreter!!.getOutputTensor(0)

            // 현재는 UINT8 양자화 모델만 지원
            if (inputTensor.dataType() != org.tensorflow.lite.DataType.UINT8) {
                Log.e(TAG, "This classifier only supports UINT8 quantized models.")
                return null
            }

            val quantizationParams = inputTensor.quantizationParams()
            val scale = quantizationParams.scale
            val zeroPoint = quantizationParams.zeroPoint

            val inputBuffer = ByteBuffer.allocateDirect(features.size).order(ByteOrder.nativeOrder())
            for (feature in features) {
                // q = round(v/scale) + zeroPoint
                val qv = (feature / scale).roundToInt() + zeroPoint
                inputBuffer.put(qv.coerceIn(0, 255).toByte())
            }
            inputBuffer.rewind()

            // 5. 추론 실행
            val outputBuffer = ByteBuffer.allocateDirect(outputTensor.numBytes()).order(ByteOrder.nativeOrder())
            interpreter!!.run(inputBuffer, outputBuffer)
            outputBuffer.rewind()

            // 6. 출력 디양자화 및 결과 처리
            val outputQuantParams = outputTensor.quantizationParams()
            val oScale = outputQuantParams.scale
            val oZeroPoint = outputQuantParams.zeroPoint

            val probs = FloatArray(outputTensor.shape()[1])
            for (i in probs.indices) {
                // p = (q - zeroPoint) * scale
                val q = outputBuffer.get(i).toInt() and 0xFF
                probs[i] = (q - oZeroPoint) * oScale
            }

            // 가장 확률 높은 클래스 인덱스 추출
            val maxIdx = probs.indices.maxByOrNull { probs[it] } ?: -1
            val confidence = if(maxIdx != -1) probs[maxIdx] else 0.0f

            val result = if (confidence < 0.5f || maxIdx >= reverseLabelMap.size) {
                "none"
            } else {
                val gesture = reverseLabelMap[maxIdx] ?: "unknown"
                "$gesture (${String.format("%.0f", confidence * 100)}%)"
            }

            // --- 기존 결과 로깅 유지 ---
            Log.d(TAG, "Classification Result: $result")
            Log.d(TAG, "Max Index: $maxIdx, Confidence: $confidence")
            Log.d(TAG, "Probabilities: ${probs.mapIndexed { idx, prob -> "$idx:${String.format("%.3f", prob)}" }.joinToString()}")
            Log.d(TAG, "Label Map: $reverseLabelMap")
            // ---

            return result

        } catch (e: Exception) {
            Log.e(TAG, "Error during gesture classification", e)
            return null
        }
    }

    // 리소스 정리 함수
    fun close() {
        interpreter?.close()
    }
}