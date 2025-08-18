//
//  TrainingDTO.swift
//  Runner
//
//  Created by 이상원 on 8/14/25.
//

// MARK: 서버와 주고받는 JSON 요청/응답 
import Foundation

// Post 바디
struct TrainRequest: Codable {
    let model_code: String
    let landmarks: [[Float]]
    let gesture: String
}

// Post 응답
struct TrainResponse: Codable {
    let task_id: String
}

/// GET / Status / task_id
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
