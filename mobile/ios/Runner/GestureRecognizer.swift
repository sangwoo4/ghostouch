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

// MARK: 이건 동서남북 다 인식
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
    
    func classifyGesture(handLandmarkerResult: HandLandmarkerResult) -> (label: String?, features: [Float]?) {
        guard let interpreter = interpreter,
              let pts = handLandmarkerResult.worldLandmarks.first, pts.count == 21 else { return (nil, nil) }

        var features : [Float] = pts.flatMap { [$0.x, $0.y, $0.z] }

        let isLeft = (handLandmarkerResult.handedness.first?.first?.categoryName?.lowercased() == "left")
        features.append(isLeft ? 0.0 : 1.0)
            
        //print(features)
        let formatted = features.map { String(format: "%.15f", Double($0)) }
        print("[\(formatted.joined(separator: ", "))]")
        
        
        do {
            // 입력: UInt8 가정
            let inTensor = try interpreter.input(at: 0)
            guard inTensor.dataType == .uInt8 else { return (nil, features) }
            guard let iq = inTensor.quantizationParameters else { return (nil, features) }
            let iscale = Float(iq.scale)        // 보통 1/255 또는 모델 정의값
            let izero  = Int(iq.zeroPoint)

            // float → uint8 : q = round(v/scale) + zeroPoint
            let inBytes: [UInt8] = features.map { v in
                let qv = Int(lroundf(v / iscale)) + izero
                return UInt8(clamping: qv)
            }
            try interpreter.copy(Data(inBytes), toInputAt: 0)

            // 추론
            try interpreter.invoke()

            // 출력: UInt8 확률(소프트맥스 포함) 가정
            let outTensor = try interpreter.output(at: 0)
            guard outTensor.dataType == .uInt8 else { return (nil, features) }
            let outBytes = outTensor.data.toArray(type: UInt8.self)

            // dequantize: p = (q - zeroPoint) * scale  (보통 0~1 근처)
            let oq = outTensor.quantizationParameters
            let os = Float(oq?.scale ?? (1.0 / 255.0))
            let oz = Int(oq?.zeroPoint ?? 0)
            let probs: [Float] = outBytes.map { (Float(Int($0) - oz) * os) }

            // Argmax + 임계값
            guard let maxIdx = probs.argmax() else { return ("none", features) }
            let conf = probs[maxIdx]
            if conf < 0.5 { return ("none", features) }

            let label = self.reverseLabelMap[maxIdx] ?? "unknown"
            let resultLabel = "\(label) (\(String(format: "%.0f", conf * 100))%)"
            
            return (resultLabel, features)

        } catch {
            print("inference error: \(error)")
            return (nil, features)
        }
    }
    
    //기존
//    func classifyGesture(handLandmarkerResult: HandLandmarkerResult) -> String? {
//        guard let interpreter = interpreter,
//              let landmarks = handLandmarkerResult.landmarks.first, // landmarks -> worldLandmarks
//              landmarks.count > 9 else { // 회전 계산을 위한 충분한 랜드마크가 있는지 체크
//            return nil
//        }
//
//        do {
//            // 1. 손목 주변의 랜드마크를 중앙 배치
//            let wrist = landmarks[0]
//            var centeredLandmarks = landmarks.map {
//                [$0.x - wrist.x, $0.y - wrist.y, $0.z - wrist.z]
//            }
//
//            // 2. 손의 회전 계산 + 랜드마크를 수직으로 정규화
//            let wristCentered = centeredLandmarks[0]
//            let middleFingerMCP = centeredLandmarks[9]
//            
//            // 수직축에 대한 손의 각도를 계산
//            // y축 -> -y를 사용 (이미지 좌표에서 반전되니까)
//            let angle = atan2(middleFingerMCP[0] - wristCentered[0], -(middleFingerMCP[1] - wristCentered[1]))
//            
//            // 계산된 각도의 반대
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
//                return [newX, newY, landmark[2]]
//            }
//
//            // 3. 미러링된 카메라
//            let rawHandedness = handLandmarkerResult.handedness.first?.first?.categoryName?.lowercased() ?? "right"
//            let actualHandedness = isCameraMirrored ? (rawHandedness == "right" ? "left" : "right") : rawHandedness
//
//            // 4. 오른손의 x 좌표를 뒤집어 왼손 기반 모델에 맞춤
//            if actualHandedness == "right" {
//                rotatedLandmarks = rotatedLandmarks.map { [-$0[0], $0[1], $0[2]] }
//            }
//
//            // 5. 회전된 랜드마크를 사용해서 스케일 정규화를 위한 최대 차원을 계산
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
//            // 6. 정규화된 좌표 목록
//            var floatList = [Float]()
//            for landmark in rotatedLandmarks {
//                floatList.append(landmark[0] / scaleFactor)
//                floatList.append(landmark[1] / scaleFactor)
//                floatList.append(landmark[2] / scaleFactor)
//            }
//
//            // 7. 64개 요소의 입력 벡터를 생성
//            while floatList.count < 63 { floatList.append(0.0) }
//            let handednessValue: Float = (actualHandedness == "right") ? 0.0 : 1.0
//            floatList.append(handednessValue)
//            print("정규화된 64개 좌표: \(floatList)")
//            
//            // 100개 정규화 좌표
//            self.collectedFloatLists.append(floatList)
//            if self.collectedFloatLists.count >= 100 {
//                print("수집된 100개의 정규화된 좌표 배열: \(self.collectedFloatLists)")
//                self.collectedFloatLists.removeAll()
//            }
//            
//            // 8. float 목록을 바이트 배열로 양자화: [-1,1] float -> [0,255] uint8
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
//            // 9. 추론 실행
//            try interpreter.copy(inputData, toInputAt: 0)
//            try interpreter.invoke()
//
//            // 10. 출력 양자화 해제: uint8 -> float 확률
//            let outputTensor = try interpreter.output(at: 0)
//            let outputBytes = outputTensor.data.toArray(type: UInt8.self)
//            let probabilities = outputBytes.map { Float(Int($0)) / 255.0 }
//
//            // 11. 가장 높은 확률을 갖는 제스처 확인
//            guard let maxIndex = probabilities.argmax() else { return "none" }
//            
//            let gesture = self.reverseLabelMap[maxIndex] ?? "unknown"
//            let confidence = probabilities[maxIndex]
//
//            // 12. 임계값 설정
//            if confidence < 0.5 {
//                return "none"
//            }
//
//            // 13. 문자열로 변환
//            return "\(gesture) (\(String(format: "%.0f", confidence * 100))%)"
//
//        } catch {
//            print("Error during gesture classification: \(error)")
//            return nil
//        }
//    }
    
    func close() {
        interpreter = nil
    }
}

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
