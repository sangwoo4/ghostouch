//
//  GestureRecognizer.swift
//  HandLandmarker
//
//  Created by 이상원 on 8/6/25.
//

import Foundation
import MediaPipeTasksVision
import UIKit
import TensorFlowLite

// MARK: 이게 기본
class GestureRecognizer {
    var isCameraMirrored: Bool = true
    
    private var interpreter: Interpreter?
    private var reverseLabelMap: [Int: String] = [:]

    init?(modelPath: String, labelPath: String) {
        print("제스처 인식기 초기화를 시도합니다...")
        
        // 1. Load TFLite model
        guard let modelPathResult = Bundle.main.path(forResource: modelPath, ofType: "tflite") else {
            print("오류: 앱 번들에서 '\(modelPath).tflite' 모델 파일을 찾을 수 없습니다.")
            return nil
        }

        do {
            interpreter = try Interpreter(modelPath: modelPathResult)
            try interpreter?.allocateTensors()
            print("모델 로드 성공")
        } catch {
            print("인터프리터 생성 실패: \(error)")
            return nil
        }
        
        // 2. Load label map from JSON
        guard let labelPathResult = Bundle.main.path(forResource: labelPath, ofType: "json") else {
            print("오류: 앱 번들에서 '\(labelPath).json' 레이블 파일을 찾을 수 없습니다.")
            return nil
        }
        
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: labelPathResult))
            let labelDict = try JSONDecoder().decode([String: Int].self, from: data)
            
            // Create reverse map from int to string
            self.reverseLabelMap = Dictionary(uniqueKeysWithValues: labelDict.map { ($0.value, $0.key) })
            
            print("레이블 맵 로드됨: \(self.reverseLabelMap)")
        }
        catch {
            print("'\(labelPath).json'에서 레이블 로드 실패: \(error)")
            return nil
        }
        
        print("제스처 인식기 초기화 성공.")
    }
    
    // Main classification function, mirroring the Kotlin implementation.
    func classifyGesture(handLandmarkerResult: HandLandmarkerResult) -> String? {
        guard let interpreter = interpreter,
              let landmarks = handLandmarkerResult.landmarks.first,
              !landmarks.isEmpty else {
            return nil
        }

        do {
            // 1. Center landmarks around the wrist.
            let wrist = landmarks[0]
            var centeredLandmarks = landmarks.map {
                [$0.x - wrist.x, $0.y - wrist.y, $0.z - wrist.z]
            }

            // 2. Correct for mirrored camera.
            let rawHandedness = handLandmarkerResult.handedness.first?.first?.categoryName?.lowercased() ?? "right"
            let actualHandedness = isCameraMirrored ? (rawHandedness == "right" ? "left" : "right") : rawHandedness

            // 3. Flip x-coordinate for right hand to match the left-hand-based model.
            if actualHandedness == "right" {
                centeredLandmarks = centeredLandmarks.map { [-$0[0], $0[1], $0[2]] }
            }

            // 4. Calculate max dimension for scale normalization.
            let xs = centeredLandmarks.map { $0[0] }
            let ys = centeredLandmarks.map { $0[1] }
            let zs = centeredLandmarks.map { $0[2] }

            guard let minX = xs.min(), let maxX = xs.max(),
                  let minY = ys.min(), let maxY = ys.max(),
                  let minZ = zs.min(), let maxZ = zs.max() else {
                return nil
            }
            
            let maxDim = max(maxX - minX, maxY - minY, maxZ - minZ)
            let scaleFactor = maxDim > 0 ? maxDim : 1.0

            // 5. Create the normalized list of coordinates.
            var floatList = [Float]()
            for landmark in centeredLandmarks {
                floatList.append(landmark[0] / scaleFactor)
                floatList.append(landmark[1] / scaleFactor)
                floatList.append(landmark[2] / scaleFactor)
            }

            // 6. Create the final 64-element input vector.
            while floatList.count < 63 { floatList.append(0.0) }
            let handednessValue: Float = 0.0 // Match Kotlin's 0.0f
            floatList.append(handednessValue)
            
            print("손방향: MediaPipe= \(rawHandedness), 실제= \(actualHandedness) (값:\(handednessValue))")
            print("입력벡터 (\(floatList.count)개 항목): \(floatList)")
            
            // 7. Quantize the float list to a byte array: [-1,1] float -> [0,255] uint8
            let inputData = Data(floatList.map {
                let byteVal = Int(($0 + 1.0) * 127.5)
                return UInt8(clamping: byteVal)
            })
            
            let inputTensor = try interpreter.input(at: 0)
            print("▶️ input shape:", inputTensor.shape, " dataCount:", inputTensor.data.count)
            print("▶️ inputData.count:", inputData.count)
            guard inputTensor.dataType == .uInt8 else {
                print("Input tensor is not UInt8. This implementation assumes a UInt8 model.")
                return nil
            }

            // 8. Run inference.
            try interpreter.copy(inputData, toInputAt: 0)
            try interpreter.invoke()

            // 9. Dequantize the output: uint8 -> float probability
            let outputTensor = try interpreter.output(at: 0)
            let outputBytes = outputTensor.data.toArray(type: UInt8.self)
            let probabilities = outputBytes.map { Float(Int($0)) / 255.0 }

            // 10. Find the gesture with the highest probability.
//            guard let maxIndex = probabilities.argmax(),
//                  maxIndex < reverseLabelMap.count else {
//                return "none"
//            }
            guard let maxIndex = probabilities.argmax() else { return "none" }

            
            let gesture = self.reverseLabelMap[maxIndex] ?? "unknown"
            let confidence = probabilities[maxIndex]

            // 11. Apply confidence threshold.
            if confidence < 0.5 {
                return "none"
            }

            // 12. Return the formatted result string.
            return "\(gesture) (\(String(format: "%.0f", confidence * 100))%)"

        } catch {
            print("Error during gesture classification: \(error)")
            return nil
        }
    }
    
    func close() {
        interpreter = nil
    }
}

// MARK: 이건 동서남북 다 인식
//class GestureRecognizer {
//    var isCameraMirrored: Bool = true
//    
//    private var interpreter: Interpreter?
//    private var reverseLabelMap: [Int: String] = [:]
//
//    init?(modelPath: String, labelPath: String) {
//        print("제스처 인식기 초기화를 시도합니다...")
//        
//        // 1. Load TFLite model
//        guard let modelPathResult = Bundle.main.path(forResource: modelPath, ofType: "tflite") else {
//            print("오류: 앱 번들에서 '\(modelPath).tflite' 모델 파일을 찾을 수 없습니다.")
//            return nil
//        }
//
//        do {
//            interpreter = try Interpreter(modelPath: modelPathResult)
//            try interpreter?.allocateTensors()
//            print("모델 로드 성공")
//        } catch {
//            print("인터프리터 생성 실패: \(error)")
//            return nil
//        }
//        
//        // 2. Load label map from JSON
//        guard let labelPathResult = Bundle.main.path(forResource: labelPath, ofType: "json") else {
//            print("오류: 앱 번들에서 '\(labelPath).json' 레이블 파일을 찾을 수 없습니다.")
//            return nil
//        }
//        
//        do {
//            let data = try Data(contentsOf: URL(fileURLWithPath: labelPathResult))
//            let labelDict = try JSONDecoder().decode([String: Int].self, from: data)
//            
//            // Create reverse map from int to string
//            self.reverseLabelMap = Dictionary(uniqueKeysWithValues: labelDict.map { ($0.value, $0.key) })
//            
//            print("레이블 맵 로드됨: \(self.reverseLabelMap)")
//        }
//        catch {
//            print("'\(labelPath).json'에서 레이블 로드 실패: \(error)")
//            return nil
//        }
//        
//        print("제스처 인식기 초기화 성공.")
//    }
//    
//    // Main classification function, mirroring the Kotlin implementation.
//    func classifyGesture(handLandmarkerResult: HandLandmarkerResult) -> String? {
//        guard let interpreter = interpreter,
//              let landmarks = handLandmarkerResult.landmarks.first,
//              landmarks.count > 9 else { // Ensure we have enough landmarks for rotation calculation
//            return nil
//        }
//
//        do {
//            // 1. Center landmarks around the wrist.
//            let wrist = landmarks[0]
//            var centeredLandmarks = landmarks.map {
//                [$0.x - wrist.x, $0.y - wrist.y, $0.z - wrist.z]
//            }
//
//            // 2. Calculate hand rotation and normalize landmarks to be upright.
//            let wristCentered = centeredLandmarks[0]
//            let middleFingerMCP = centeredLandmarks[9]
//            
//            // Calculate the angle of the hand relative to the vertical axis.
//            // The y-axis is typically inverted in image coordinates, so we use -y.
//            let angle = atan2(middleFingerMCP[0] - wristCentered[0], -(middleFingerMCP[1] - wristCentered[1]))
//            
//            // The rotation needed is the opposite of the calculated angle.
//            let rotationAngle = -angle
//            
//            let cosAngle = cos(rotationAngle)
//            let sinAngle = sin(rotationAngle)
//            
//            var rotatedLandmarks = centeredLandmarks.map { landmark -> [Float] in
//                let x = landmark[0]
//                let y = landmark[1]
//                let newX = x * cosAngle - y * sinAngle
//                let newY = x * sinAngle + y * cosAngle
//                return [newX, newY, landmark[2]] // Keep z the same
//            }
//
//            // 3. Correct for mirrored camera.
//            let rawHandedness = handLandmarkerResult.handedness.first?.first?.categoryName?.lowercased() ?? "right"
//            let actualHandedness = isCameraMirrored ? (rawHandedness == "right" ? "left" : "right") : rawHandedness
//
//            // 4. Flip x-coordinate for right hand to match the left-hand-based model.
//            if actualHandedness == "right" {
//                rotatedLandmarks = rotatedLandmarks.map { [-$0[0], $0[1], $0[2]] }
//            }
//
//            // 5. Calculate max dimension for scale normalization using rotated landmarks.
//            let xs = rotatedLandmarks.map { $0[0] }
//            let ys = rotatedLandmarks.map { $0[1] }
//            let zs = rotatedLandmarks.map { $0[2] }
//
//            guard let minX = xs.min(), let maxX = xs.max(),
//                  let minY = ys.min(), let maxY = ys.max(),
//                  let minZ = zs.min(), let maxZ = zs.max() else {
//                return nil
//            }
//            
//            let maxDim = max(maxX - minX, maxY - minY, maxZ - minZ)
//            let scaleFactor = maxDim > 0 ? maxDim : 1.0
//
//            // 6. Create the normalized list of coordinates.
//            var floatList = [Float]()
//            for landmark in rotatedLandmarks {
//                floatList.append(landmark[0] / scaleFactor)
//                floatList.append(landmark[1] / scaleFactor)
//                floatList.append(landmark[2] / scaleFactor)
//            }
//
//            // 7. Create the final 64-element input vector.
//            while floatList.count < 63 { floatList.append(0.0) }
//            let handednessValue: Float = 0.0 // Match Kotlin's 0.0f
//            floatList.append(handednessValue)
//            
//            // 8. Quantize the float list to a byte array: [-1,1] float -> [0,255] uint8
//            let inputData = Data(floatList.map {
//                let byteVal = Int(($0 + 1.0) * 127.5)
//                return UInt8(clamping: byteVal)
//            })
//            
//            let inputTensor = try interpreter.input(at: 0)
//            guard inputTensor.dataType == .uInt8 else {
//                print("Input tensor is not UInt8. This implementation assumes a UInt8 model.")
//                return nil
//            }
//
//            // 9. Run inference.
//            try interpreter.copy(inputData, toInputAt: 0)
//            try interpreter.invoke()
//
//            // 10. Dequantize the output: uint8 -> float probability
//            let outputTensor = try interpreter.output(at: 0)
//            let outputBytes = outputTensor.data.toArray(type: UInt8.self)
//            let probabilities = outputBytes.map { Float(Int($0)) / 255.0 }
//
//            // 11. Find the gesture with the highest probability.
//            guard let maxIndex = probabilities.argmax() else { return "none" }
//            
//            let gesture = self.reverseLabelMap[maxIndex] ?? "unknown"
//            let confidence = probabilities[maxIndex]
//
//            // 12. Apply confidence threshold.
//            if confidence < 0.5 {
//                return "none"
//            }
//
//            // 13. Return the formatted result string.
//            return "\(gesture) (\(String(format: "%.0f", confidence * 100))%)"
//
//        } catch {
//            print("Error during gesture classification: \(error)")
//            return nil
//        }
//    }
//    
//    func close() {
//        interpreter = nil
//    }
//}

// MARK: - Utility Extensions

extension Data {
    func toArray<T>(type: T.Type) -> [T] {
        return withUnsafeBytes { (body: UnsafeRawBufferPointer) -> [T] in
            Array(body.bindMemory(to: T.self))
        }
    }
}

extension Array where Element: Comparable {
    func argmax() -> Int? {
        return self.enumerated().max(by: { $0.element < $1.element })?.offset
    }
}
