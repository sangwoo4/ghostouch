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
import com.google.mediapipe.tasks.components.containers.Category
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
    private var isFrontCamera: Boolean = false
    private var rotationDegrees: Int = 0
    private var handednesses: List<List<Category>>? = null

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
            val imageRatio = imageWidth.toFloat() / imageHeight.toFloat()
            val viewRatio = width.toFloat() / height.toFloat()
            var actualScaleFactor = 1f
            var xOffset = 0f
            var yOffset = 0f

            if (viewRatio > imageRatio) {
                // View is wider than image, scale to height
                actualScaleFactor = height.toFloat() / imageHeight
                xOffset = (width - imageWidth * actualScaleFactor) / 2f
            } else {
                // View is taller than image, scale to width
                actualScaleFactor = width.toFloat() / imageWidth
                yOffset = (height - imageHeight * actualScaleFactor) / 2f
            }

            for (landmark in handLandmarkerResult.landmarks()) {
                for (normalizedLandmark in landmark) {
                    var x = normalizedLandmark.x() * imageWidth * actualScaleFactor + xOffset
                    var y = normalizedLandmark.y() * imageHeight * actualScaleFactor + yOffset

                    // Apply mirroring for front camera
                    if (isFrontCamera) {
                        x = width - x // Mirror horizontally
                    }

                    canvas.drawPoint(x, y, pointPaint)
                }

                HandLandmarker.HAND_CONNECTIONS.forEach {
                    val startX = landmark[it.start()].x() * imageWidth * actualScaleFactor + xOffset
                    val startY = landmark[it.start()].y() * imageHeight * actualScaleFactor + yOffset
                    val endX = landmark[it.end()].x() * imageWidth * actualScaleFactor + xOffset
                    val endY = landmark[it.end()].y() * imageHeight * actualScaleFactor + yOffset

                    var transformedStartX = startX
                    var transformedEndX = endX

                    if (isFrontCamera) {
                        transformedStartX = width - startX
                        transformedEndX = width - endX
                    }

                    canvas.drawLine(
                        transformedStartX,
                        startY,
                        transformedEndX,
                        endY,
                        linePaint
                    )
                }

                // Draw handedness (Left/Right hand)
                handednesses?.getOrNull(handLandmarkerResult.landmarks().indexOf(landmark))?.let { handednessList ->
                    val handedness = handednessList[0] // Get the first Category object
                    val handLabel = if (isFrontCamera) {
                        // Invert for front camera
                        if (handedness.categoryName().equals("Left", true)) "Right"
                        else "Left"
                    } else {
                        handedness.categoryName()
                    }
                    val handScore = String.format("%.2f", handedness.score())
                    val handText = "$handLabel ($handScore)"

                    val textX = landmark[0].x() * imageWidth * actualScaleFactor + xOffset
                    val textY = landmark[0].y() * imageHeight * actualScaleFactor + yOffset - 20 // Offset to draw above the hand

                    canvas.drawText(handText, textX, textY, textPaint)
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
        gestureResult: String? = null,
        isFrontCamera: Boolean = false,
        rotationDegrees: Int = 0,
        handednesses: List<List<Category>>? = null
    ) {
        this.results = handLandmarkerResult
        this.gestureResult = gestureResult
        this.isFrontCamera = isFrontCamera
        this.rotationDegrees = rotationDegrees
        this.handednesses = handednesses

        this.imageHeight = imageHeight
        this.imageWidth = imageWidth

        // The scaleFactor is now calculated within the draw method to handle FILL_CENTER logic
        invalidate()
    }

    companion object {
        private const val LANDMARK_STROKE_WIDTH = 8F
    }
}