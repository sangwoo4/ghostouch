// MARK: 버퍼 완료
// 이벤트 수신 → TrainingAPI로 학습 시작 → task_id 저장 → 주기 폴링 → 성공/실패 브로드캐스트

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
    
    init(api: TrainingAPI = TrainingAPI()) {
        self.api = api
    }
    
    // 100 프레임 이상일 때 호출
    func uploadAndTrain(gesture: String, frames: [[Float]]) {
        guard frames.count >= 100 else { return }

        let currentModelCode = TrainingStore.shared.lastModelCode ?? "base_v1"
        
        Task { [weak self] in
            guard let self else { return }
            do {
                let res = try await api.sendTrain(.init(model_code: currentModelCode,
                                                        landmarks: frames,
                                                        gesture: gesture))
                self.currentTaskId = res.task_id
                TrainingStore.shared.lastTaskId = res.task_id
                self.delegate?.trainingDidStart(taskId: res.task_id)
                self.startPolling(taskId: res.task_id)
            } catch {
                self.delegate?.trainingDidFail(taskId: self.currentTaskId ?? "unknown",
                                               errorInfo: error.localizedDescription)
            }
        }
    }
    
    private func startPolling(taskId: String) {
        stopPolling()
        
        pollingTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                if !self.isPollingInFlight {
                    self.isPollingInFlight = true
                    do {
                        let st = try await self.api.getStatus(taskId: taskId)
                        print(st.status)
                        
                        switch st.status.uppercased() {
                        case "PENDING", "PROGRESS":
                            self.delegate?.trainingDidProgress(taskId: taskId, progress: st.progress)
                            
                        case "SUCCESS":
                            let tfliteURL = st.result?.tflite_url
                            let modelCode = st.result?.model_code
                            
                            self.delegate?.trainingDidSucceed(taskId: taskId,
                                                              tfliteURL: tfliteURL,
                                                              modelCode: modelCode)
                            
                            TrainingStore.shared.lastModelCode = modelCode
                            TrainingStore.shared.lastModelURLString = tfliteURL
                            
                            self.isPollingInFlight = false
                            self.stopPolling()
                            
                            if let s = tfliteURL, let url = URL(string: s) {
                                Task { [weak self] in
                                    await self?.downloadAndSaveModel(from: url, modelCode: modelCode)
                                }
                            }
                            return
                            
                        default:
                            self.isPollingInFlight = false
                            self.stopPolling()
                            self.delegate?.trainingDidFail(taskId: taskId, errorInfo: st.error_info)
                            return
                        }
                        
                        self.isPollingInFlight = false
                    } catch {
                        print("폴링 중 오류: \(error)")
                        self.isPollingInFlight = false
                    }
                }
                
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1초 대기
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
            delegate?.trainingDidFail(taskId: currentTaskId ?? "unknown",
                                      errorInfo: "모델 저장 실패: \(error.localizedDescription)")
        }
    }
}
