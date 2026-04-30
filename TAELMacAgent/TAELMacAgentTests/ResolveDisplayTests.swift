//
//  ResolveDisplayTests.swift
//  TAELMacAgentTests
//
//  Pins the v0.3 §23.2 cursor → main → first-available resolution
//  rule. Uses plain structs as display candidates so the test does
//  not need SCShareableContent or NSEvent.mouseLocation.
//

import XCTest
import CoreGraphics
@testable import TAELMacAgent

final class ResolveDisplayTests: XCTestCase {
    private struct StubDisplay: Equatable {
        let id: CGDirectDisplayID
        let label: String
    }

    private static let cursorID: CGDirectDisplayID = 100
    private static let mainID: CGDirectDisplayID = 1
    private static let otherID: CGDirectDisplayID = 200

    private let cursor = StubDisplay(id: cursorID, label: "cursor")
    private let main = StubDisplay(id: mainID, label: "main")
    private let other = StubDisplay(id: otherID, label: "other")

    private func resolve(
        candidates: [StubDisplay],
        cursorDisplayID: CGDirectDisplayID?,
        requested: ScreenshotTarget = .displayContainingCursor
    ) -> DisplayResolution<StubDisplay>? {
        resolveDisplay(
            candidates: candidates,
            displayID: { $0.id },
            cursorDisplayID: cursorDisplayID,
            mainDisplayID: Self.mainID,
            requested: requested
        )
    }

    func test_returnsCursorDisplay_whenRequestedAndAvailable() throws {
        let resolution = try XCTUnwrap(resolve(
            candidates: [main, cursor, other],
            cursorDisplayID: Self.cursorID
        ))
        XCTAssertEqual(resolution.display, cursor)
        XCTAssertEqual(resolution.resolved, .displayContainingCursor)
    }

    func test_fallsBackToMain_whenCursorDisplayMissingFromCandidates() throws {
        let resolution = try XCTUnwrap(resolve(
            candidates: [main, other],
            cursorDisplayID: Self.cursorID
        ))
        XCTAssertEqual(resolution.display, main)
        XCTAssertEqual(resolution.resolved, .mainDisplay,
            "When cursor display has been disconnected, the resolved target must report .mainDisplay so the HUD can label it as a fallback.")
    }

    func test_fallsBackToMain_whenCursorDisplayIDIsNil() throws {
        let resolution = try XCTUnwrap(resolve(
            candidates: [main, other],
            cursorDisplayID: nil
        ))
        XCTAssertEqual(resolution.display, main)
        XCTAssertEqual(resolution.resolved, .mainDisplay)
    }

    func test_fallsBackToFirstAvailable_whenMainAndCursorBothMissing() throws {
        let resolution = try XCTUnwrap(resolve(
            candidates: [other],
            cursorDisplayID: Self.cursorID
        ))
        XCTAssertEqual(resolution.display, other)
        XCTAssertEqual(resolution.resolved, .mainDisplay,
            "Best-effort fallback still reports .mainDisplay; we never claim cursor when we did not actually find it.")
    }

    func test_returnsNil_whenNoCandidates() {
        XCTAssertNil(resolve(candidates: [], cursorDisplayID: Self.cursorID))
    }

    func test_skipsCursorPath_whenRequestedIsMainDisplay() throws {
        let resolution = try XCTUnwrap(resolve(
            candidates: [main, cursor],
            cursorDisplayID: Self.cursorID,
            requested: .mainDisplay
        ))
        XCTAssertEqual(resolution.display, main,
            "An explicit .mainDisplay request must not be silently upgraded to cursor even if the cursor display is in the candidate list.")
        XCTAssertEqual(resolution.resolved, .mainDisplay)
    }
}
