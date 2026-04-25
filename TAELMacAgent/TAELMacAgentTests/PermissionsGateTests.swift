import XCTest
@testable import TAELMacAgent

final class PermissionsGateTests: XCTestCase {
    @MainActor
    func testWithPermissionIssuesGrantWhenGranted() async throws {
        let presenter = StubPresenter()
        let gate = PermissionsGate(
            checker: StubChecker(status: .granted),
            permissionUI: presenter
        )

        let result = try await gate.withPermission(.screenRecording) { grant in
            XCTAssertEqual(grant.kind, .screenRecording)
            return "ok"
        }

        XCTAssertEqual(result, "ok")
        XCTAssertEqual(presenter.shownKinds, [])
    }

    @MainActor
    func testWithPermissionShowsGateAndThrowsWhenMissing() async {
        let presenter = StubPresenter()
        let gate = PermissionsGate(
            checker: StubChecker(status: .notDetermined),
            permissionUI: presenter
        )

        do {
            _ = try await gate.withPermission(.screenRecording) { _ in
                XCTFail("Operation should not run without permission.")
                return "unexpected"
            }
            XCTFail("Gate should throw when permission is missing.")
        } catch PermissionError.missing(let kind) {
            XCTAssertEqual(kind, .screenRecording)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertEqual(presenter.shownKinds, [.screenRecording])
    }
}

private final class StubChecker: PermissionChecking {
    private let statusToReturn: PermissionStatus

    init(status: PermissionStatus) {
        statusToReturn = status
    }

    func status(for kind: PermissionKind) async -> PermissionStatus {
        statusToReturn
    }
}

@MainActor
private final class StubPresenter: PermissionGatePresenting {
    private(set) var shownKinds: [PermissionKind] = []

    func showGate(for kind: PermissionKind) async {
        shownKinds.append(kind)
    }
}
