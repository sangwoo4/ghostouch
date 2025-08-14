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
    func trainingDidProgress(taskId: String, step: String?)
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
    func uploadAndTrain(gesture: String, frames: [[Float]], modelCode: String = "base_v1") {
        guard frames.count >= 100 else { return }
        
        Task { [weak self] in
            guard let self else { return }
            do {
                let res = try await api.sendTrain(.init(model_code: modelCode, landmarks: frames, gesture: gesture))
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

                        switch st.status.uppercased() {
                        case "PENDING", "PROGRESS":
                            self.delegate?.trainingDidProgress(taskId: taskId,
                                                               step: st.progress?.current_step)

                        case "SUCCESS":
                            self.isPollingInFlight = false
                            self.stopPolling() // Task 취소
                            let tfliteURL = st.result?.tflite_url
                            let modelCode = st.result?.model_code
                            TrainingStore.shared.lastModelCode = modelCode
                            TrainingStore.shared.lastModelURLString = tfliteURL
                            self.delegate?.trainingDidSucceed(taskId: taskId,
                                                              tfliteURL: tfliteURL,
                                                              modelCode: modelCode)

                            if let s = tfliteURL, let url = URL(string: s) {
                                await self.downloadAndSaveModel(from: url, modelCode: modelCode)
                            }
                            return  // 성공 후 루프 종료

                        default:
                            self.isPollingInFlight = false
                            self.stopPolling()
                            self.delegate?.trainingDidFail(taskId: taskId,
                                                           errorInfo: st.error_info)
                            return
                        }
                    } catch {
                        // 네트워크 흔들림: 다음 사이클에 재시도
                        self.isPollingInFlight = false
                    }
                }

                // 2초 대기 (정확한 폴링 간격)
                try? await Task.sleep(nanoseconds: 2_000_000_000)
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
