//
//  LandmarkBuffer.swift
//  Runner
//
//  Created by 이상원 on 8/14/25.
//


// MARK: 100개 좌표 누적
import Foundation

final class LandmarkBuffer {
    let capacity: Int
    private(set) var items: [[Float]] = []
    
    init(capacity: Int = 100) {
        self.capacity = capacity
    }
    
    // 이제 append는 데이터를 추가만 하고, 100개가 찼는지 여부는 외부에서 확인
    func append(_ features: [Float]) {
        guard items.count < capacity else { return }
        items.append(features)
    }
    
    func reset() {
        items.removeAll(keepingCapacity: false)
    }
}
