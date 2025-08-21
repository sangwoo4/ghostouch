
import Foundation
import MediaPipeTasksVision
import UIKit
import TensorFlowLite

// MARK: - 제스처 인식기 (동서남북 전부 인식)
class GestureRecognizer {
    var isCameraMirrored: Bool = true
    
    private var interpreter: Interpreter?
    private var reverseLabelMap: [Int: String] = [:]

    init?(modelPath: String, labelPath: String) {
        print("제스처 인식기 초기화 시도")
        
        // TFLite 모델 로드
        guard let modelPathResult = Bundle.main.path(forResource: modelPath, ofType: "tflite") else {
            print("오류: 앱 번들에서 '\(modelPath).tflite' 모델 파일을 못 찾음")
            return nil
        }

        do {
            interpreter = try Interpreter(modelPath: modelPathResult)
            try interpreter?.allocateTensors()
            print("모델 로드 성공")
        } catch {
            print("오류: 인터프리터 생성 실패 — \(error)")
            return nil
        }
        
        // 레이블 맵 로드 (JSON)
        guard let labelPathResult = Bundle.main.path(forResource: labelPath, ofType: "json") else {
            print("오류: 앱 번들에서 '\(labelPath).json' 레이블 파일을 못 찾음")
            return nil
        }
        
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: labelPathResult))
            let labelDict = try JSONDecoder().decode([String: Int].self, from: data)
            self.reverseLabelMap = Dictionary(uniqueKeysWithValues: labelDict.map { ($0.value, $0.key) })
            print("레이블 맵 로드 완료: \(self.reverseLabelMap)")
        } catch {
            print("오류: '\(labelPath).json'에서 레이블 로드 실패 — \(error)")
            return nil
        }
        
        print("제스처 인식기 초기화 완료")
    }

    init?(modelURL: URL, labelURL: URL) {
        print("제스처 인식기를 URL로 초기화")
        print("모델 경로: \(modelURL.path)")
        print("레이블 경로: \(labelURL.path)")

        // TFLite 모델 로드 (URL)
        do {
            interpreter = try Interpreter(modelPath: modelURL.path)
            try interpreter?.allocateTensors()
            print("모델 로드 성공")
            print(modelURL)
            print(labelURL)
        } catch {
            print("오류: 인터프리터 생성 실패 — \(error)")
            return nil
        }
        
        // 레이블 맵 로드 (URL)
        do {
            let data = try Data(contentsOf: labelURL)
            let labelDict = try JSONDecoder().decode([String: Int].self, from: data)
            self.reverseLabelMap = Dictionary(uniqueKeysWithValues: labelDict.map { ($0.value, $0.key) })
            print("레이블 맵 로드 완료: \(self.reverseLabelMap)")
        } catch {
            print("오류: 레이블 URL 로드 실패 — \(error)")
            return nil
        }
        
        print("제스처 인식기 초기화 완료")
    }
    
    func classifyGesture(handLandmarkerResult: HandLandmarkerResult) -> (label: String?, features: [Float]?) {
        guard let interpreter = interpreter,
              let pts = handLandmarkerResult.worldLandmarks.first, pts.count == 21 else { return (nil, nil) }

        var features: [Float] = pts.flatMap { [$0.x, $0.y, $0.z] }

        let isLeft = (handLandmarkerResult.handedness.first?.first?.categoryName?.lowercased() == "left")
        features.append(isLeft ? 0.0 : 1.0)

        
        do {
            // 입력 텐서 확인 및 양자화 파라미터 적용
            let inTensor = try interpreter.input(at: 0)
            guard inTensor.dataType == .uInt8 else { return (nil, features) }
            guard let iq = inTensor.quantizationParameters else { return (nil, features) }

            let iscale = Float(iq.scale)
            let izero  = Int(iq.zeroPoint)

            // float → uint8 : q = round(v/scale) + zeroPoint
            let inBytes: [UInt8] = features.map { v in
                let qv = Int(lroundf(v / iscale)) + izero
                return UInt8(clamping: qv)
            }
            try interpreter.copy(Data(inBytes), toInputAt: 0)

            // 추론
            try interpreter.invoke()

            // 출력 텐서 디퀀타이즈
            let outTensor = try interpreter.output(at: 0)
            guard outTensor.dataType == .uInt8 else { return (nil, features) }

            let outBytes = outTensor.data.toArray(type: UInt8.self)
            let oq = outTensor.quantizationParameters
            let os = Float(oq?.scale ?? (1.0 / 255.0))
            let oz = Int(oq?.zeroPoint ?? 0)
            let probs: [Float] = outBytes.map { Float(Int($0) - oz) * os }

            // argmax + 임계값
            guard let maxIdx = probs.argmax() else { return ("none", features) }
            let conf = probs[maxIdx]
            if conf < 0.5 { return ("none", features) }

            let label = self.reverseLabelMap[maxIdx] ?? "unknown"
            let resultLabel = "\(label) (\(String(format: "%.0f", conf * 100))%)"
            return (resultLabel, features)

        } catch {
            print("오류: 추론 실패 — \(error)")
            return (nil, features)
        }
    }

    func close() {
        interpreter = nil
    }
    
    public func updateModel(modelURL: URL) -> Bool {
        print("모델을 실시간으로 업데이트. 경로: \(modelURL.path)")
        do {
            let newInterpreter = try Interpreter(modelPath: modelURL.path)
            try newInterpreter.allocateTensors()
            self.interpreter = newInterpreter
            print("모델 업데이트 성공")
            return true
        } catch {
            print("오류: 모델 업데이트 실패 — \(error)")
            return false
        }
    }

    public func updateLabelMap(labelURL: URL) -> Bool {
        print("레이블 맵을 실시간으로 업데이트. 경로: \(labelURL.path)")
        do {
            let data = try Data(contentsOf: labelURL)
            let labelDict = try JSONDecoder().decode([String: Int].self, from: data)
            self.reverseLabelMap = Dictionary(uniqueKeysWithValues: labelDict.map { ($0.value, $0.key) })
            print("레이블 맵 업데이트 성공: \(self.reverseLabelMap)")
            return true
        } catch {
            print("오류: 레이블 맵 업데이트 실패 — \(error)")
            return false
        }
    }
}

// MARK: - 유틸 확장

extension Data {
    func toArray<T>(type: T.Type) -> [T] {
        withUnsafeBytes { (body: UnsafeRawBufferPointer) -> [T] in
            Array(body.bindMemory(to: T.self))
        }
    }
}

extension Array where Element: Comparable {
    func argmax() -> Int? {
        self.enumerated().max(by: { $0.element < $1.element })?.offset
    }
}
