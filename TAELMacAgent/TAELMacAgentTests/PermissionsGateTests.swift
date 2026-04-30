//
//  PermissionsGateTests.swift
//  TAELMacAgentTests
//
//  Verifies the architectural contract:
//
//    1. `withPermission` does NOT invoke the operation when status is
//       not `.granted`. It throws `PermissionError.missing` and routes
//       through `PermissionGatePresenting.showGate`.
//    2. `withPermission` invokes the operation EXACTLY once on
//       `.granted`, and the closure receives a `PermissionGrant`
//       whose `kind` matches the requested kind.
//    3. The grant's `kind` cannot be forged from outside
//       `PermissionsGate.swift`; `PermissionGrant` is declared in
//       that same file with a `fileprivate init`, so even
//       `@testable import` cannot reach the initializer from this
//       test file. Verified at compile time: this test file does not
//       and cannot construct `PermissionGrant` directly.
//

import XCTest
@testable import TAELMacAgent

final class PermissionsGateTests: XCTestCase {

    // MARK: - Test doubles

    private actor StubChecker: PermissionChecking {
        private var statuses: [PermissionKind: PermissionStatus]
        private(set) var queryCount: Int = 0

        init(_ statuses: [PermissionKind: PermissionStatus]) {
            self.statuses = statuses
        }

        func status(for kind: PermissionKind) async -> PermissionStatus {
            queryCount += 1
            return statuses[kind] ?? .notDetermined
        }
    }

    private actor SpyUI: PermissionGatePresenting {
        private(set) var shownKinds: [PermissionKind] = []

        func showGate(for kind: PermissionKind) async {
            shownKinds.append(kind)
        }
    }

    // MARK: - Denied path

    func test_withPermission_whenDenied_throwsAndShowsGate_andDoesNotRunOperation() async {
        let checker = StubChecker([.screenRecording: .denied])
        let ui = SpyUI()
        let gate = PermissionsGate(checker: checker, permissionUI: ui)

        var operationRan = false

        do {
            _ = try await gate.withPermission(.screenRecording) { _ in
                operationRan = true
                return 42
            }
            XCTFail("Expected PermissionError.missing to be thrown.")
        } catch let error as PermissionError {
            XCTAssertEqual(error, .missing(.screenRecording))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertFalse(operationRan, "Operation must not run when permission is denied.")
        let shown = await ui.shownKinds
        XCTAssertEqual(shown, [.screenRecording], "Gate UI must be shown exactly once with the requested kind.")
    }

    // MARK: - Not-determined path

    func test_withPermission_whenNotDetermined_throwsAndShowsGate() async {
        let checker = StubChecker([.screenRecording: .notDetermined])
        let ui = SpyUI()
        let gate = PermissionsGate(checker: checker, permissionUI: ui)

        var operationRan = false

        do {
            _ = try await gate.withPermission(.screenRecording) { _ in
                operationRan = true
                return ()
            }
            XCTFail("Expected throw on .notDetermined.")
        } catch let error as PermissionError {
            XCTAssertEqual(error, .missing(.screenRecording))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertFalse(operationRan)
        let shown = await ui.shownKinds
        XCTAssertEqual(shown, [.screenRecording])
    }

    // MARK: - Granted path

    func test_withPermission_whenGranted_runsOperationOnceWithMatchingGrantKind() async throws {
        let checker = StubChecker([.screenRecording: .granted])
        let ui = SpyUI()
        let gate = PermissionsGate(checker: checker, permissionUI: ui)

        var callCount = 0
        var observedKind: PermissionKind?

        let result: Int = try await gate.withPermission(.screenRecording) { grant in
            callCount += 1
            observedKind = grant.kind
            return 7
        }

        XCTAssertEqual(result, 7)
        XCTAssertEqual(callCount, 1, "Operation must run exactly once.")
        XCTAssertEqual(observedKind, .screenRecording)
        let shown = await ui.shownKinds
        XCTAssertTrue(shown.isEmpty, "Gate UI must NOT appear on a granted path.")
    }

    // MARK: - Operation errors propagate

    func test_withPermission_propagatesOperationErrors_andDoesNotShowGate() async {
        struct Boom: Error, Equatable {}
        let checker = StubChecker([.screenRecording: .granted])
        let ui = SpyUI()
        let gate = PermissionsGate(checker: checker, permissionUI: ui)

        do {
            _ = try await gate.withPermission(.screenRecording) { _ -> Int in
                throw Boom()
            }
            XCTFail("Expected Boom to propagate.")
        } catch is Boom {
            // Expected.
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        let shown = await ui.shownKinds
        XCTAssertTrue(shown.isEmpty, "Gate UI must not appear when the operation itself errors.")
    }

    // MARK: - Unimplemented kind path

    func test_withPermission_whenKindNotImplemented_throwsNotImplemented_andDoesNotShowGate() async {
        let checker = StubChecker([:])  // empty: status() defaults to .notDetermined for any kind
        let ui = SpyUI()
        let gate = PermissionsGate(checker: checker, permissionUI: ui)

        var operationRan = false

        do {
            _ = try await gate.withPermission(.microphone) { _ in
                operationRan = true
                return ()
            }
            XCTFail("Expected PermissionError.notImplemented to be thrown.")
        } catch let error as PermissionError {
            XCTAssertEqual(error, .notImplemented(.microphone))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertFalse(operationRan, "Operation must not run for unimplemented kinds.")
        let shown = await ui.shownKinds
        XCTAssertTrue(shown.isEmpty, "Gate UI must not appear for unimplemented kinds; there is nothing the user can grant.")
    }
}
