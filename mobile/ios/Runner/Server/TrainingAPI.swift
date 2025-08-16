//
//  TrainingAPI.swift
//  Runner
//
//  Created by 이상원 on 8/14/25.
//

// MARK: POST /train, GET /status/{taskId} 네트워킹 레이어 (URLSession)
import Foundation

private enum Config {
    static var baseURL: URL {
        guard let ip = Bundle.main.object(forInfoDictionaryKey: "ServerIP") as? String else {
            print("WARNING: 'ServerIP' not found in Info.plist. Defaulting to localhost.")
            // 로컬 개발 환경을 위해 localhost를 기본값으로 사용합니다.
            return URL(string: "http://127.0.0.1:8000/")!
        }
        let port = Bundle.main.object(forInfoDictionaryKey: "ServerPort") as? String ?? "8000"
        
        guard let url = URL(string: "http://\(ip):\(port)/") else {
            fatalError("Could not construct a valid URL from ip: \(ip) and port: \(port)")
        }
        return url
    }
}

final class TrainingAPI {
    private let baseURL: URL
    private let session: URLSession
    
    init(baseURL: URL = Config.baseURL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }
    
    // /train
    func sendTrain(_ body: TrainRequest) async throws -> TrainResponse {
        var request = URLRequest(url: baseURL.appendingPathComponent("train"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let jsonData = try JSONEncoder().encode(body)
        request.httpBody = jsonData
        
        // 디버깅을 위해 이 코드를 추가합니다.
        if let jsonString = String(data: jsonData, encoding: .utf8) {
            print("✅ [Request JSON]: \(jsonString)")
        }

        let (data, resp) = try await session.data(for: request)
        guard let http = resp as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(TrainResponse.self, from: data)
    }
    
    // /status /taskID
    func getStatus(taskId: String) async throws -> StatusResponse {
        let url = baseURL.appendingPathComponent("status").appendingPathComponent(taskId)
        let (data, resp) = try await session.data(from: url)
        guard let http = resp as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(StatusResponse.self, from: data)
    }
    
    // 파일 다운로드
    func download(url: URL) async throws -> Data {
        let (data, resp) = try await session.data(from: url)
        guard let http = resp as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw URLError(.badServerResponse)
        }
        return data
    }
}
