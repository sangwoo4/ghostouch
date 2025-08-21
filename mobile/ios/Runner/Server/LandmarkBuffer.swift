// MARK: 100개 좌표 누적
import Foundation

final class LandmarkBuffer {
    let capacity: Int
    private(set) var items: [[Float]] = []
    
    init(capacity: Int = 100) {
        self.capacity = capacity
    }
    
    // 데이터 추가 (100개 초과 시 무시)
    func append(_ features: [Float]) {
        guard items.count < capacity else { return }
        items.append(features)
    }
    
    // 버퍼 초기화
    func reset() {
        items.removeAll(keepingCapacity: false)
    }
}
