package com.pentagon.ghostouch

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.util.AttributeSet
import android.view.View
import androidx.core.content.ContextCompat
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarker
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarkerResult
import kotlin.math.max
import kotlin.math.min

class OverlayView(context: Context?, attrs: AttributeSet?) :
    View(context, attrs) {

    private var results: HandLandmarkerResult? = null
    private var linePaint = Paint()
    private var pointPaint = Paint()
    private var textPaint = Paint()
    private var gesturePaint = Paint()

    private var scaleFactor: Float = 1f
    private var imageWidth: Int = 1
    private var imageHeight: Int = 1
    private var gestureResult: String? = null

    init {
        initPaints()
    }

    fun clear() {
        results = null
        linePaint.reset()
        pointPaint.reset()
        textPaint.reset()
        gesturePaint.reset()
        gestureResult = null
        invalidate()
        initPaints()
    }

    private fun initPaints() {
        linePaint.color = Color.BLUE
        linePaint.strokeWidth = LANDMARK_STROKE_WIDTH
        linePaint.style = Paint.Style.STROKE

        pointPaint.color = Color.YELLOW
        pointPaint.strokeWidth = LANDMARK_STROKE_WIDTH
        pointPaint.style = Paint.Style.FILL

        textPaint.color = Color.WHITE
        textPaint.textSize = 24f
        textPaint.isAntiAlias = true
        textPaint.style = Paint.Style.FILL

        gesturePaint.color = Color.BLACK
        gesturePaint.textSize = 80f
        gesturePaint.isAntiAlias = true
        gesturePaint.style = Paint.Style.FILL
        gesturePaint.strokeWidth = 2f
    }

    override fun draw(canvas: Canvas) {
        super.draw(canvas)
        results?.let { handLandmarkerResult ->
            for (landmark in handLandmarkerResult.landmarks()) {
                for (normalizedLandmark in landmark) {
                    canvas.drawPoint(
                        normalizedLandmark.x() * imageWidth * scaleFactor,
                        normalizedLandmark.y() * imageHeight * scaleFactor,
                        pointPaint
                    )
                }

                HandLandmarker.HAND_CONNECTIONS.forEach {
                    canvas.drawLine(
                        handLandmarkerResult.landmarks()[0][it.start()].x() * imageWidth * scaleFactor,
                        handLandmarkerResult.landmarks()[0][it.start()].y() * imageHeight * scaleFactor,
                        handLandmarkerResult.landmarks()[0][it.end()].x() * imageWidth * scaleFactor,
                        handLandmarkerResult.landmarks()[0][it.end()].y() * imageHeight * scaleFactor,
                        linePaint
                    )
                }
            }
        }

        // Draw gesture result at bottom center with background
        val displayText = gestureResult ?: "No Gesture"
        val textWidth = gesturePaint.measureText(displayText)
        val centerX = width / 2f - textWidth / 2f
        val textY = height - 200f

        // 반투명 배경 그리기
        val backgroundPaint = Paint().apply {
            color = Color.WHITE
            alpha = 220
            style = Paint.Style.FILL
        }

        canvas.drawRect(
            centerX - 30f,
            textY - 90f,
            centerX + textWidth + 30f,
            textY + 30f,
            backgroundPaint
        )

        // 검은색 테두리 그리기
        val borderPaint = Paint().apply {
            color = Color.BLACK
            style = Paint.Style.STROKE
            strokeWidth = 3f
        }

        canvas.drawRect(
            centerX - 30f,
            textY - 90f,
            centerX + textWidth + 30f,
            textY + 30f,
            borderPaint
        )

        // 검은색 텍스트 그리기
        canvas.drawText(
            displayText,
            centerX,
            textY,
            gesturePaint
        )
    }

    fun setResults(
        handLandmarkerResult: HandLandmarkerResult,
        imageHeight: Int,
        imageWidth: Int,
        runningMode: RunningMode = RunningMode.IMAGE,
        gestureResult: String? = null
    ) {
        this.results = handLandmarkerResult
        this.gestureResult = gestureResult

        this.imageHeight = imageHeight
        this.imageWidth = imageWidth

        scaleFactor = when (runningMode) {
            RunningMode.IMAGE,
            RunningMode.VIDEO -> {
                min(width * 1f / imageWidth, height * 1f / imageHeight)
            }
            RunningMode.LIVE_STREAM -> {
                max(width * 1f / imageWidth, height * 1f / imageHeight)
            }
        }
        invalidate()
    }

    companion object {
        private const val LANDMARK_STROKE_WIDTH = 8F
    }
}