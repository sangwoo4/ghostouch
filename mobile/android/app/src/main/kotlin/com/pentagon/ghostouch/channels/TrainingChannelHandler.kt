package com.pentagon.ghostouch.channels

import com.pentagon.ghostouch.gesture.training.TrainingCoordinator
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class TrainingChannelHandler(private val trainingCoordinator: TrainingCoordinator) {
    
    fun handleTraining(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startTraining" -> {
                val gestureName = call.argument<String>("gestureName")
                val frames = call.argument<ArrayList<ArrayList<Double>>>("frames")

                if (gestureName != null && frames != null) {
                    trainingCoordinator.uploadAndTrain(gestureName, frames.map { it.map { d -> d.toFloat() } })
                    result.success(null)
                } else {
                    result.error("INVALID_ARGUMENTS", "제스처 이름 또는 프레임이 없습니다.", null)
                }
            }
            else -> result.notImplemented()
        }
    }
}