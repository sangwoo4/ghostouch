import Foundation

class LabelMapManager {
    static let shared = LabelMapManager()

    private let fileName = "basic_label_map.json"

    // URL for the original file in the app bundle (read-only)
    private var bundleFileURL: URL? {
        guard let path = Bundle.main.path(forResource: "basic_label_map", ofType: "json") else {
            return nil
        }
        return URL(fileURLWithPath: path)
    }

    // URL for the file in the app's Documents directory (writable)
    var documentsFileURL: URL? {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return documentsDirectory.appendingPathComponent(fileName)
    }

    // Private initializer to perform setup
    private init() {
        setupInitialFile()
    }

    // Checks if the file exists in Documents, if not, copies it from the bundle.
    private func setupInitialFile() {
        guard let destURL = documentsFileURL else {
            print("에러: Documents 디렉토리 URL을 가져올 수 없음.")
            return
        }

        // If file doesn't exist in Documents, copy it from the bundle
        if !FileManager.default.fileExists(atPath: destURL.path) {
            guard let sourceURL = bundleFileURL else {
                print("에러: 번들에서 원본 파일을 찾을 수 없음.")
                return
            }
            do {
                try FileManager.default.copyItem(at: sourceURL, to: destURL)
                print("원본 레이블 맵을 Documents 디렉토리로 복사했음.")
            } catch {
                print("에러: 원본 레이블 맵 복사 실패: \(error)")
            }
        }
    }

    // Reads the label map from the Documents directory.
    func readLabelMap() -> [String: Int]? {
        guard let url = documentsFileURL else {
            print("에러: Documents 디렉토리 URL을 가져올 수 없음.")
            return nil
        }
        
        // Check if file exists before trying to read
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("에러: Documents 디렉토리에 레이블 맵 파일이 없음. setupInitialFile()을 확인해야 함.")
            return nil
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let labelMap = try decoder.decode([String: Int].self, from: data)
            return labelMap
        } catch {
            print("레이블 맵 읽기 또는 디코딩 에러: \(error)")
            // Attempt to fix trailing comma issue
            if let jsonString = try? String(contentsOf: url, encoding: .utf8) {
                let correctedJSONString = jsonString.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",\\s*\\}", with: "}", options: .regularExpression)
                if let data = correctedJSONString.data(using: .utf8) {
                    do {
                        let decoder = JSONDecoder()
                        let labelMap = try decoder.decode([String: Int].self, from: data)
                        return labelMap
                    } catch {
                        print("JSON 수정 후에도 레이블 맵 디코딩 에러: \(error)")
                    }
                }
            }
            return nil
        }
    }

    // Adds a new gesture to the label map and saves it to the Documents directory.
    func addGesture(name: String) {
        guard var labelMap = readLabelMap() else {
            print("레이블 맵을 읽을 수 없어 제스처를 추가할 수 없음.")
            return
        }

        if labelMap[name] != nil {
            print("제스처 '\(name)'은(는) 이미 레이블 맵에 존재함.")
            return
        }

        let maxId = labelMap.values.max() ?? -1
        labelMap[name] = maxId + 1

        saveLabelMap(map: labelMap)
    }

    // Saves the label map dictionary back to the JSON file in the Documents directory.
    private func saveLabelMap(map: [String: Int]) {
        guard let url = documentsFileURL else {
            print("파일 URL이 유효하지 않아 레이블 맵을 저장할 수 없음.")
            return
        }

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(map)
            try data.write(to: url, options: .atomic)
            print("✅ 업데이트된 레이블 맵 저장 완료: \(url.path)")
            if let jsonString = String(data: data, encoding: .utf8) {
                print("새로운 레이블 맵 내용:\n\(jsonString)")
            }
        } catch {
            print("레이블 맵 인코딩 또는 저장 에러: \(error)")
        }
    }

    // 레이블 맵 + 학습 + 모델코드 초기화
    func clearLabelMap() {
        guard let url = documentsFileURL else {
            print("에러: Documents 디렉토리 URL을 가져올 수 없어 레이블 맵을 초기화할 수 없음.")
            return
        }

        do {
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
                print("✅ Documents 디렉토리에서 레이블 맵 파일 삭제 성공.")
            }
            setupInitialFile() // 원본 basic_label_map.json을 다시 복사
            print("✅ 레이블 맵이 초기 상태로 복원되었습니다.")
            if let initialLabelMap = readLabelMap() {
                print("초기화된 레이블 맵: \(initialLabelMap)")
            }

            // GestureRecognitionService에 레이블 맵을 업데이트하도록 알림
            Task { @MainActor in // Ensure this block runs on the MainActor
                // ADDED: Reset lastModelCode in TrainingStore
                TrainingStore.shared.lastModelCode = "base_v1" // Reset model_code to base_v1

                if let gestureRecognizer = GestureRecognitionService.shared.gestureRecognizer {
                    if let labelURL = documentsFileURL { // 초기화 시키도록 업데이트
                        let updateSuccess = gestureRecognizer.updateLabelMap(labelURL: labelURL)
                        if updateSuccess {
                            print("✅ GestureRecognizer의 레이블 맵 업데이트 성공.")
                        } else {
                            print("🚨 GestureRecognizer의 레이블 맵 업데이트 실패.")
                        }
                    } else {
                        print("🚨 Documents 디렉토리의 레이블 맵 URL을 가져올 수 없어 GestureRecognizer를 업데이트할 수 없음.")
                    }

                    // tflite 모델도 기본으로 초기화
                    if let basicModelURL = Bundle.main.url(forResource: "basic_gesture_model", withExtension: "tflite") {
                        let modelUpdateSuccess = gestureRecognizer.updateModel(modelURL: basicModelURL)
                        if modelUpdateSuccess {
                            print("✅ GestureRecognizer의 모델이 기본 모델로 업데이트 성공.")
                        } else {
                            print("🚨 GestureRecognizer의 모델이 기본 모델로 업데이트 실패.")
                        }
                    }
                    else {
                        print("🚨 번들에서 basic_gesture_model.tflite를 찾을 수 없어 모델을 초기화할 수 없음.")
                    }

                } else {
                    print("⚠️ GestureRecognizer 인스턴스를 찾을 수 없어 레이블 맵을 업데이트할 수 없음.")
                }
            }
        } catch {
            print("🚨 레이블 맵 초기화 실패: \(error)")
        }
    }
}
