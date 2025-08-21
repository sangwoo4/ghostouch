
// MARK: task_id, model_code, tflite_url 등 저장
import Foundation

// 상태/파일 저장소
final class TrainingStore {
    static let shared = TrainingStore()
    private init() {}
    
    private let userDefaults = UserDefaults.standard
    
    // 최근 task / model 정보
    var lastTaskId: String? {
        get { userDefaults.string(forKey: "train.lastTaskId") }
        set { userDefaults.setValue(newValue, forKey: "train.lastTaskId") }
    }
    var lastModelCode: String? {
        get { userDefaults.string(forKey: "train.lastModelCode") }
        set { userDefaults.setValue(newValue, forKey: "train.lastModelCode") }
    }
    var lastModelURLString: String? {
        get { userDefaults.string(forKey: "train.lastModelURL") }
        set { userDefaults.setValue(newValue, forKey: "train.lastModelURL") }
    }
    
    // 파일 경로
    func modelFileURL(modelCode: String?) -> URL {
        let fileName = modelCode.map { "custom_model_\($0).tflite" } ?? "custom_model.tflite"
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return dir.appendingPathComponent(fileName)
    }

    func labelMapFileURL(modelCode: String?) -> URL {
        let fileName = modelCode.map { "custom_model_\($0).json" } ?? "custom_model.json"
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return dir.appendingPathComponent(fileName)
    }

    // 모델 저장
    func saveModelData(_ data: Data, modelCode: String?) throws -> URL {
        let url = modelFileURL(modelCode: modelCode)
        try data.write(to: url, options: .atomic)
        return url
    }

    // 다운로드된 파일 삭제
    func clearDownloadedFiles() {
        let fileManager = FileManager.default
        if let modelCode = lastModelCode {
            let modelUrl = modelFileURL(modelCode: modelCode)
            let labelUrl = labelMapFileURL(modelCode: modelCode)

            do {
                if fileManager.fileExists(atPath: modelUrl.path) {
                    try fileManager.removeItem(at: modelUrl)
                    print("모델 파일 삭제: \(modelUrl.lastPathComponent)")
                }
                if fileManager.fileExists(atPath: labelUrl.path) {
                    try fileManager.removeItem(at: labelUrl)
                    print("레이블 맵 파일 삭제: \(labelUrl.lastPathComponent)")
                }
            } catch {
                print("파일 삭제 실패: \(error.localizedDescription)")
            }
        }
    }
}
