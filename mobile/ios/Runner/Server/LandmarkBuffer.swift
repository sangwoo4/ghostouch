//
//  LandmarkBuffer.swift
//  Runner
//
//  Created by 이상원 on 8/14/25.
//


// MARK: 100개 좌표 누적 후 배치 콜백
import Foundation

final class LandmarkBuffer {
    let capacity: Int
    private(set) var items: [[Float]] = []
    var onBatchReady: (([[Float]]) -> Void)?
    
    init(capacity: Int = 100) {
        self.capacity = capacity
    }
    
    func append(_ features: [Float]) {
        items.append(features)
        
        if items.count >= capacity {
            let batch = items
            items.removeAll(keepingCapacity: false) // <- 질문
            onBatchReady?(batch)
        }
    }
    
    func reset() {items.removeAll(keepingCapacity: false)}
}
