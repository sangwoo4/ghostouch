//
//  TrainingManager.swift
//  Runner
//
//  Created by 이상원 on 8/14/25.
//

// MARK: 버퍼 완료 이벤트 수신 → TrainingAPI로 학습 시작 → task_id 저장 → Timer로 주기 폴링 → SUCCESS/FAIL 브로드캐스트

import Foundation
@MainActor
protocol TrainingManagerDelegate: AnyObject {
    func trainingDidStart(taskId: String)
    func trainingDidProgress(taskId: String, progress: StatusResponse.ProgressPayload?)
    func trainingDidSucceed(taskId: String, tfliteURL: String?, modelCode: String?)
    func trainingDidFail(taskId: String, errorInfo: String?)
    func modelReady(savedURL: URL)
}

@MainActor
final class TrainingManager {
    private let api: TrainingAPI
    private var pollingTask: Task<Void, Never>?
    private var isPollingInFlight = false
    private(set) var currentTaskId: String?
    weak var delegate: TrainingManagerDelegate?
    
    init(api: TrainingAPI = TrainingAPI()) {self.api = api}
    
    // 100 프레임 이상일 때 호출
    func uploadAndTrain(gesture: String, frames: [[Float]]) { // Removed default "base_v1"
        guard frames.count >= 100 else { return }

        // Determine the modelCode to send
        let currentModelCode = TrainingStore.shared.lastModelCode ?? "base_v1"
        
        Task { [weak self] in
            guard let self else { return }
            do {
                let res = try await api.sendTrain(.init(model_code: currentModelCode, landmarks: frames, gesture: gesture))
                self.currentTaskId = res.task_id
                TrainingStore.shared.lastTaskId = res.task_id
                self.delegate?.trainingDidStart(taskId: res.task_id)
                self.startPolling(taskId: res.task_id)
            } catch {
                self.delegate?.trainingDidFail(taskId: self.currentTaskId ?? "unknown", errorInfo: error.localizedDescription)
            }
        }
    }
    
    private func startPolling(taskId: String) {
        stopPolling()

        // 메인액터에서 안전하게 상태 접근
        pollingTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                if !self.isPollingInFlight {
                    self.isPollingInFlight = true
                    do {
                        // async 호출은 반드시 await
                        let st = try await self.api.getStatus(taskId: taskId)
                        print(st.status)
                        switch st.status.uppercased() {
                        case "PENDING", "PROGRESS":
                            self.delegate?.trainingDidProgress(taskId: taskId,
                                                               progress: st.progress)

                        case "SUCCESS":
                            let tfliteURL = st.result?.tflite_url
                            let modelCode = st.result?.model_code
                            
                            // 델리게이트 호출을 먼저 실행
                            self.delegate?.trainingDidSucceed(taskId: taskId,
                                                              tfliteURL: tfliteURL,
                                                              modelCode: modelCode)

                            // 상태 저장
                            TrainingStore.shared.lastModelCode = modelCode
                            TrainingStore.shared.lastModelURLString = tfliteURL
                            
                            // 폴링 중단
                            self.isPollingInFlight = false
                            self.stopPolling()

                            // Task에서 수행하여 폴링 Task의 취소에 영향을 받지 않도록
                            if let s = tfliteURL, let url = URL(string: s) {
                                Task { [weak self] in
                                    await self?.downloadAndSaveModel(from: url, modelCode: modelCode)
                                }
                            }
                            return // 성공 후 루프 종료

                        default:
                            self.isPollingInFlight = false
                            self.stopPolling()
                            self.delegate?.trainingDidFail(taskId: taskId,
                                                           errorInfo: st.error_info)
                            return
                        }

                        // 다음 폴링을 위해 플래그를 리셋합니다.
                        self.isPollingInFlight = false
                    } catch {
                        // 오류를 출력하여 디버깅을 돕습니다.
                        print("🚨 Polling 중 오류 발생: \(error)")
                        self.isPollingInFlight = false
                    }
                }

                // 1초 대기 (정확한 폴링 간격)
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }

    
    
    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
        isPollingInFlight = false
    }
    
    private func downloadAndSaveModel(from url: URL, modelCode: String?) async {
        do {
            let data = try await api.download(url: url)
            let saved = try TrainingStore.shared.saveModelData(data, modelCode: modelCode)
            delegate?.modelReady(savedURL: saved)
        } catch {
            delegate?.trainingDidFail(taskId: currentTaskId ?? "unknown", errorInfo: "Model save failed: \(error.localizedDescription)")
        }
    }
}
