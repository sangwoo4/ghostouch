package com.pentagon.ghostouch

import android.content.Context
import android.util.Log
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarkerResult
import org.json.JSONObject
import org.tensorflow.lite.Interpreter
import java.io.FileInputStream
import java.nio.MappedByteBuffer
import java.nio.channels.FileChannel

// 손 제스처를 분류하는 클래스 (TFLite 모델 기반)
class GestureClassifier(private val context: Context) {

    companion object {
        private const val TAG = "GestureClassifier"
        private const val isCameraMirrored = true  // 전면 카메라 사용 시 true → x축 반전 필요
    }

    // TFLite 추론기
    private var interpreter: Interpreter? = null

    // "gesture name" -> "정수 라벨" 매핑
    private var labelMap: Map<String, Int> = emptyMap()

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
            Log.d(TAG, "입력 텐서 형태: ${input?.shape()?.contentToString()}")
            Log.d(TAG, "출력 텐서 형태: ${output?.shape()?.contentToString()}")
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

            val map = mutableMapOf<String, Int>()
            val reverseMap = mutableMapOf<Int, String>()

            // 각 제스처 이름과 인덱스를 맵에 추가
            jsonObject.keys().forEach { key ->
                val value = jsonObject.getInt(key)
                map[key] = value
                reverseMap[value] = key
            }

            labelMap = map
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

    // 제스처 분류 함수
    fun classifyGesture(handLandmarkerResult: HandLandmarkerResult): String? {
        // 모델 또는 입력 데이터가 없으면 리턴
        if (interpreter == null || handLandmarkerResult.landmarks().isEmpty()) {
            Log.d(TAG, "손이 감지되지 않았습니다.")
            return null
        }

        return try {
            // 첫 번째 손의 21개 랜드마크 가져오기
            val landmarks = handLandmarkerResult.landmarks()[0]
            val wrist = landmarks[0]  // 기준점: 손목

            // 1. 손목을 기준으로 랜드마크 중앙 정렬
            val centeredLandmarks = landmarks.map {
                listOf(it.x() - wrist.x(), it.y() - wrist.y(), it.z() - wrist.z())
            }

            // 2. 손 회전 각도 계산 및 랜드마크 정규화 (세로 방향으로)
            val wristCentered = centeredLandmarks[0]
            val middleFingerMCP = centeredLandmarks[9]

            // y축이 이미지 좌표에서 반전되므로 -y 사용
            val angle = Math.atan2(
                (middleFingerMCP[0] - wristCentered[0]).toDouble(),
                -(middleFingerMCP[1] - wristCentered[1]).toDouble()
            )
            val rotationAngle = -angle

            val cosAngle = Math.cos(rotationAngle).toFloat()
            val sinAngle = Math.sin(rotationAngle).toFloat()

            var rotatedLandmarks = centeredLandmarks.map { landmark ->
                val x = landmark[0]
                val y = landmark[1]
                val newX = x * cosAngle - y * sinAngle
                val newY = x * sinAngle + y * cosAngle
                listOf(newX, newY, landmark[2]) // z는 동일하게 유지
            }

            // 3. 미러링된 카메라 보정
            val rawHandedness = handLandmarkerResult.handedness()
                .firstOrNull()?.firstOrNull()?.categoryName()?.lowercase() ?: "right"

            val actualHandedness = if (isCameraMirrored) {
                if (rawHandedness == "right") "left" else "right"
            } else {
                rawHandedness
            }

            // 4. 오른손인 경우, 왼손 기준 모델에 맞추기 위해 x 좌표 반전
            if (actualHandedness == "right") {
                rotatedLandmarks = rotatedLandmarks.map { listOf(-it[0], it[1], it[2]) }
            }

            // 5. 회전된 랜드마크를 사용하여 정규화를 위한 최대 길이 계산
            val xs = rotatedLandmarks.map { it[0] }
            val ys = rotatedLandmarks.map { it[1] }
            val zs = rotatedLandmarks.map { it[2] }

            val maxDim = maxOf(
                xs.maxOrNull()!! - xs.minOrNull()!!,
                ys.maxOrNull()!! - ys.minOrNull()!!,
                zs.maxOrNull()!! - zs.minOrNull()!!
            ).takeIf { it > 0f } ?: 1f  // 0 나누기 방지

            // 6. 정규화된 좌표 리스트 생성
            val floatList = mutableListOf<Float>()
            for (landmark in rotatedLandmarks) {
                floatList.add(landmark[0] / maxDim)
                floatList.add(landmark[1] / maxDim)
                floatList.add(landmark[2] / maxDim)
            }

            // 총 64개의 입력 벡터 만들기 (63개 + handedness)
            while (floatList.size < 63) floatList.add(0.0f)

            val handednessValue = 0.0f  // 오른손 기준 모델
            floatList.add(handednessValue)

            Log.d(TAG, "손 방향: MediaPipe=$rawHandedness -> 실제=$actualHandedness (값=$handednessValue)")
            Log.d(TAG, "입력 벡터 (${floatList.size}개 항목): $floatList")

            // [-1,1] 실수 → [0,255] 정수로 양자화
            val input = Array(1) { Array(64) { ByteArray(1) } }
            for (i in floatList.indices) {
                val byteVal = ((floatList[i] + 1f) * 127.5f).toInt().coerceIn(0, 255)
                input[0][i][0] = byteVal.toByte()
            }

            // 출력: 제스처 클래스 4개에 대한 확률
            val output = Array(1) { ByteArray(4) }
            interpreter?.run(input, output)

            // 확률 출력 (uint8 → float)
            val probs = output[0].map { (it.toInt() and 0xFF) / 255.0f }
            Log.d(TAG, "출력 확률: $probs")

            // 가장 확률 높은 클래스 인덱스 추출
            val maxIdx = probs.indices.maxByOrNull { probs[it] } ?: return "none"
            val gesture = reverseLabelMap[maxIdx] ?: "unknown"
            val confidence = probs[maxIdx]

            // 확률이 낮으면 none 처리
            if (confidence < 0.5f) return "none"

            // 결과 문자열 리턴 (예: "rock (87%)")
            "$gesture (${String.format("%.0f", confidence * 100)}%)"

        } catch (e: Exception) {
            Log.e(TAG, "분류 중 오류 발생", e)
            null
        }
    }

    // 리소스 정리 함수
    fun close() {
        interpreter?.close()
    }
}