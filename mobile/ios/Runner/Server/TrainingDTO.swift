// MARK: 서버와 주고받는 JSON 요청/응답
import Foundation

// POST 요청 바디
struct TrainRequest: Codable {
    let model_code: String
    let landmarks: [[Float]]
    let gesture: String
}

// POST 응답
struct TrainResponse: Codable {
    let task_id: String
}

// GET /status/{task_id} 응답
struct StatusResponse: Codable {
    struct ResultPayload: Codable {
        let tflite_url: String?
        let model_code: String?
    }
    struct ProgressPayload: Codable {
        let current_step: String?
    }
    
    let task_id: String
    let status: String
    let result: ResultPayload?
    let error_info: String?
    let progress: ProgressPayload?
}
