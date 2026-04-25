//
//  LocalLogService.swift
//  TAELMacAgent
//
//  PR 1: in-memory ring buffer of `InvocationLog` rows. No disk I/O.
//  Disk persistence (with size cap and rotation) lands when the
//  executor lands.
//

import Foundation

public actor LocalLogService {
    private let capacity: Int
    private var buffer: [InvocationLog] = []

    public init(capacity: Int = 256) {
        precondition(capacity > 0)
        self.capacity = capacity
    }

    public func record(_ log: InvocationLog) {
        buffer.append(log)
        if buffer.count > capacity {
            buffer.removeFirst(buffer.count - capacity)
        }
    }

    public func recent(_ limit: Int = 50) -> [InvocationLog] {
        let safeLimit = max(0, min(limit, buffer.count))
        return Array(buffer.suffix(safeLimit))
    }

    public func clear() {
        buffer.removeAll(keepingCapacity: true)
    }
}
