import Foundation

class LabelMapManager {
    static let shared = LabelMapManager()

    private let fileName = "basic_label_map.json"

    // 앱 번들에 있는 원본 파일 URL (읽기 전용)
    private var bundleFileURL: URL? {
        guard let path = Bundle.main.path(forResource: "basic_label_map", ofType: "json") else {
            return nil
        }
        return URL(fileURLWithPath: path)
    }

    // 앱 Documents 디렉터리의 파일 URL (쓰기 가능)
    var documentsFileURL: URL? {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return documentsDirectory.appendingPathComponent(fileName)
    }

    // 생성 시 기본 파일 세팅
    private init() {
        setupInitialFile()
    }

    // Documents에 파일이 없으면 번들에서 복사
    private func setupInitialFile() {
        guard let destURL = documentsFileURL else {
            print("오류: Documents 디렉터리 URL을 못 가져옴")
            return
        }

        if !FileManager.default.fileExists(atPath: destURL.path) {
            guard let sourceURL = bundleFileURL else {
                print("오류: 번들에서 원본 파일을 못 찾음")
                return
            }
            do {
                try FileManager.default.copyItem(at: sourceURL, to: destURL)
                print("원본 레이블 맵을 Documents 디렉터리로 복사")
            } catch {
                print("오류: 원본 레이블 맵 복사 실패 — \(error)")
            }
        }
    }

    // Documents에서 레이블 맵 읽기
    func readLabelMap() -> [String: Int]? {
        guard let url = documentsFileURL else {
            print("오류: Documents 디렉터리 URL을 못 가져옴")
            return nil
        }
        
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("오류: Documents에 레이블 맵 파일이 없음. setupInitialFile() 확인필요")
            return nil
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let labelMap = try decoder.decode([String: Int].self, from: data)
            return labelMap
        } catch {
            print("오류: 레이블 맵 읽기/디코딩 실패 — \(error)")
            // 트레일링 콤마 보정 시도
            if let jsonString = try? String(contentsOf: url, encoding: .utf8) {
                let correctedJSONString = jsonString
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: ",\\s*\\}", with: "}", options: .regularExpression)
                if let data = correctedJSONString.data(using: .utf8) {
                    do {
                        let decoder = JSONDecoder()
                        let labelMap = try decoder.decode([String: Int].self, from: data)
                        return labelMap
                    } catch {
                        print("오류: JSON 보정 후에도 디코딩 실패 — \(error)")
                    }
                }
            }
            return nil
        }
    }

    // 새 제스처를 레이블 맵에 추가 후 저장
    func addGesture(name: String) {
        guard var labelMap = readLabelMap() else {
            print("레이블 맵을 못 읽어서 제스처를 추가 못 함")
            return
        }

        if labelMap[name] != nil {
            print("제스처 '\(name)'은(는) 이미 있음")
            return
        }

        let maxId = labelMap.values.max() ?? -1
        labelMap[name] = maxId + 1

        saveLabelMap(map: labelMap)
    }

    // 레이블 맵을 Documents의 JSON 파일로 저장
    private func saveLabelMap(map: [String: Int]) {
        guard let url = documentsFileURL else {
            print("오류: 파일 URL이 유효하지 않아서 레이블 맵을 저장 못 함")
            return
        }

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(map)
            try data.write(to: url, options: .atomic)
            print("업데이트된 레이블 맵 저장 완료: \(url.path)")
            if let jsonString = String(data: data, encoding: .utf8) {
                print("새 레이블 맵 내용:\n\(jsonString)")
            }
        } catch {
            print("오류: 레이블 맵 인코딩/저장 실패 — \(error)")
        }
    }

    // 레이블 맵 + 학습 상태 + 모델 코드 초기화
    func clearLabelMap() {
        guard let url = documentsFileURL else {
            print("오류: Documents 디렉터리 URL을 못 가져와서 레이블 맵을 초기화 못 함")
            return
        }

        do {
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
                print("Documents 디렉터리에서 레이블 맵 파일 삭제")
            }
            setupInitialFile() // 기본 basic_label_map.json 다시 복사
            print("레이블 맵을 초기 상태로 복원")
            if let initialLabelMap = readLabelMap() {
                print("초기화된 레이블 맵: \(initialLabelMap)")
            }

            // 초기화 완료 알림 방송
            NotificationCenter.default.post(name: .didResetAllGestures, object: nil)
            
        } catch {
            print("오류: 레이블 맵 초기화 실패 — \(error)")
        }
    }
}
