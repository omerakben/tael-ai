//
//  PermissionsCheckerTests.swift
//  TAELMacAgentTests
//

import XCTest
@testable import TAELMacAgent

@MainActor
final class PermissionsCheckerTests: XCTestCase {

    // MARK: - Accessibility

    func test_status_forAccessibility_returnsGrantedOrNotDetermined() async {
        let checker = PermissionsChecker()
        let status = await checker.status(for: .accessibility)
        XCTAssertTrue(
            status == .granted || status == .notDetermined,
            "Accessibility status must be either .granted or .notDetermined; got \(status). The checker must never return .denied or .restricted for AX since AXIsProcessTrusted only distinguishes trusted/not-trusted."
        )
    }
}
