//
//  HotkeyManagerTests.swift
//  TAELMacAgentTests
//

import XCTest
@testable import TAELMacAgent

@MainActor
final class HotkeyManagerTests: XCTestCase {

    func test_simulatePress_invokesTriggerOnce_evenIfFiredTwiceConcurrently() async {
        let manager = HotkeyManager()
        let counter = Counter()

        manager.onTrigger = {
            await counter.increment()
            // Hold the in-flight gate open long enough for a second press
            // to race in. Sleep yields the Task and lets the second
            // simulatePress run while we're still flagged in-flight.
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
        }

        manager.simulatePressForTesting()
        manager.simulatePressForTesting()

        // Wait for the in-flight Task to complete.
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms

        let count = await counter.value
        XCTAssertEqual(count, 1, "Re-entrant press during in-flight invocation must be dropped")
    }

    func test_simulatePress_afterPreviousCompletes_invokesTriggerAgain() async {
        let manager = HotkeyManager()
        let counter = Counter()

        manager.onTrigger = {
            await counter.increment()
        }

        manager.simulatePressForTesting()
        try? await Task.sleep(nanoseconds: 20_000_000)
        manager.simulatePressForTesting()
        try? await Task.sleep(nanoseconds: 20_000_000)

        let count = await counter.value
        XCTAssertEqual(count, 2, "Sequential presses must each fire once")
    }

    func test_tearDown_clearsOnTrigger() {
        let manager = HotkeyManager()
        manager.onTrigger = { /* no-op */ }
        manager.tearDown()
        XCTAssertNil(manager.onTrigger)
    }

    private actor Counter {
        private(set) var value = 0
        func increment() { value += 1 }
    }
}
