//
//  LocalLogService.swift
//  TAELMacAgent
//
//  PR 1: in-memory ring buffer of `InvocationLog` rows. No disk I/O.
//  Disk persistence (with size cap and rotation) lands when the
//  executor lands.
//
//  PR-1-cleanup addition: surfaces overflow drops via `droppedCount`
//  and an `os_log(.fault)` on the first drop per session, so a user
//  reporting "TAEL didn't fire" doesn't quietly lose the evidence.
//

import Foundation
import os.log

public actor LocalLogService {
    private let capacity: Int
    private var buffer: [InvocationLog] = []
    public private(set) var droppedCount: Int = 0
    private var hasLoggedOverflow: Bool = false

    private let log = Logger(subsystem: "ai.tael.macagent", category: "LocalLogService")

    public init(capacity: Int = 256) {
        precondition(capacity > 0)
        self.capacity = capacity
    }

    public func record(_ log: InvocationLog) {
        buffer.append(log)
        if buffer.count > capacity {
            let drop = buffer.count - capacity
            buffer.removeFirst(drop)
            droppedCount += drop
            if !hasLoggedOverflow {
                hasLoggedOverflow = true
                self.log.fault("LocalLogService ring buffer overflowed; entries are now being dropped. Capacity=\(self.capacity, privacy: .public). Subsequent drops are tracked in droppedCount.")
            }
        }
    }

    public func recent(_ limit: Int = 50) -> [InvocationLog] {
        let safeLimit = max(0, min(limit, buffer.count))
        return Array(buffer.suffix(safeLimit))
    }

    public func clear() {
        buffer.removeAll(keepingCapacity: true)
        // droppedCount intentionally NOT reset - it's a session metric.
    }
}
