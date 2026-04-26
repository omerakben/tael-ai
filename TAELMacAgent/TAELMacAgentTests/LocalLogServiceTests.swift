//
//  LocalLogServiceTests.swift
//  TAELMacAgentTests
//
//  Verifies the ring buffer's overflow accounting. PR-1-cleanup
//  addition: previously the service silently dropped entries past
//  capacity with no signal.
//

import XCTest
@testable import TAELMacAgent

final class LocalLogServiceTests: XCTestCase {

    private func makeLog(_ id: Int) -> InvocationLog {
        InvocationLog(
            id: UUID(),
            hotkeyTimestamp: Date(timeIntervalSince1970: TimeInterval(id)),
            gateOutcome: .granted
        )
    }

    func test_recordingUpToCapacity_doesNotDrop() async {
        let log = LocalLogService(capacity: 3)
        for i in 0..<3 { await log.record(makeLog(i)) }
        let dropped = await log.droppedCount
        XCTAssertEqual(dropped, 0)
        let recent = await log.recent(10)
        XCTAssertEqual(recent.count, 3)
    }

    func test_recordingPastCapacity_dropsOldestAndCountsDrops() async {
        let log = LocalLogService(capacity: 3)
        for i in 0..<5 { await log.record(makeLog(i)) }
        let dropped = await log.droppedCount
        XCTAssertEqual(dropped, 2, "Two entries should have been dropped to keep capacity at 3.")
        let recent = await log.recent(10)
        XCTAssertEqual(recent.count, 3)
        XCTAssertEqual(recent.map(\.hotkeyTimestamp.timeIntervalSince1970), [2, 3, 4])
    }

    func test_clear_resetsBufferButPreservesDroppedCount() async {
        let log = LocalLogService(capacity: 2)
        for i in 0..<5 { await log.record(makeLog(i)) }
        let droppedBefore = await log.droppedCount
        XCTAssertEqual(droppedBefore, 3)

        await log.clear()
        let recent = await log.recent(10)
        XCTAssertTrue(recent.isEmpty)

        // droppedCount intentionally survives clear() - it's a session metric, not a buffer count.
        let droppedAfter = await log.droppedCount
        XCTAssertEqual(droppedAfter, 3)
    }
}
