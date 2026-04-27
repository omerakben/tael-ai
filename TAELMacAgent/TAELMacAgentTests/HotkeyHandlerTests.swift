//
//  HotkeyHandlerTests.swift
//  TAELMacAgentTests
//

import XCTest
@testable import TAELMacAgent
import CoreGraphics

@MainActor
final class HotkeyHandlerTests: XCTestCase {

    // MARK: - Test doubles

    private actor StubChecker: PermissionChecking {
        private let status: PermissionStatus
        init(_ status: PermissionStatus) { self.status = status }
        func status(for kind: PermissionKind) async -> PermissionStatus { status }
    }

    private actor SpyUI: PermissionGatePresenting {
        private(set) var shownKinds: [PermissionKind] = []
        func showGate(for kind: PermissionKind) async { shownKinds.append(kind) }
    }

    private actor SpyCapture: DisplayScreenshotCapturing {
        var thrownError: Error?
        var capturedTargets: [ScreenshotTarget] = []
        var stubScreenshot: CapturedScreenshot

        init(stub: CapturedScreenshot) { self.stubScreenshot = stub }

        func setError(_ error: Error?) { self.thrownError = error }
        func observedTargets() -> [ScreenshotTarget] { capturedTargets }

        func captureDisplayScreenshot(
            _ grant: PermissionGrant,
            target: ScreenshotTarget
        ) async throws -> CapturedScreenshot {
            precondition(grant.kind == .screenRecording)
            capturedTargets.append(target)
            if let thrownError { throw thrownError }
            return stubScreenshot
        }
    }

    /// Builds a 1x1 transparent CGImage for tests; no real capture.
    private func makeStubScreenshot() -> CapturedScreenshot {
        let cs = CGColorSpaceCreateDeviceRGB()
        let ctx = CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        let image = ctx.makeImage()!
        return CapturedScreenshot(image: image, target: .displayContainingCursor)
    }

    // MARK: - Granted path

    func test_run_whenGranted_callsCaptureAndPresentsAndLogsGranted() async {
        let checker = StubChecker(.granted)
        let ui = SpyUI()
        let gate = PermissionsGate(checker: checker, permissionUI: ui)
        let capture = SpyCapture(stub: makeStubScreenshot())
        let logService = LocalLogService(capacity: 16)

        var presented: [CapturedScreenshot] = []
        let handler = HotkeyInvocationHandler(
            permissionsGate: gate,
            screenCaptureService: capture,
            presentScreenshot: { presented.append($0) },
            logService: logService
        )

        await handler.run()

        let targets = await capture.observedTargets()
        XCTAssertEqual(targets, [.week1Default])
        XCTAssertEqual(presented.count, 1)

        let logs = await logService.recent(10)
        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(logs.first?.gateOutcome, .granted)
        XCTAssertNotNil(logs.first?.gateLatencyMs)
        XCTAssertNotNil(logs.first?.captureLatencyMs)
    }

    // MARK: - Denied path

    func test_run_whenDenied_doesNotCapture_doesNotPresent_logsDenied() async {
        let checker = StubChecker(.denied)
        let ui = SpyUI()
        let gate = PermissionsGate(checker: checker, permissionUI: ui)
        let capture = SpyCapture(stub: makeStubScreenshot())
        let logService = LocalLogService(capacity: 16)

        var presented: [CapturedScreenshot] = []
        let handler = HotkeyInvocationHandler(
            permissionsGate: gate,
            screenCaptureService: capture,
            presentScreenshot: { presented.append($0) },
            logService: logService
        )

        await handler.run()

        let targets = await capture.observedTargets()
        XCTAssertTrue(targets.isEmpty)
        XCTAssertTrue(presented.isEmpty)

        let logs = await logService.recent(10)
        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(logs.first?.gateOutcome, .denied)
        XCTAssertNil(logs.first?.gateLatencyMs)
        XCTAssertNotNil(logs.first?.errorDescription)

        // The gate still surfaces the UI on missing permission.
        let shown = await ui.shownKinds
        XCTAssertEqual(shown, [.screenRecording])
    }

    // MARK: - Capture failure path

    func test_run_whenCaptureFails_logsErroredOutcome() async {
        let checker = StubChecker(.granted)
        let ui = SpyUI()
        let gate = PermissionsGate(checker: checker, permissionUI: ui)
        let capture = SpyCapture(stub: makeStubScreenshot())
        await capture.setError(ScreenCaptureError.captureFailed("simulated"))

        let logService = LocalLogService(capacity: 16)

        var presented: [CapturedScreenshot] = []
        let handler = HotkeyInvocationHandler(
            permissionsGate: gate,
            screenCaptureService: capture,
            presentScreenshot: { presented.append($0) },
            logService: logService
        )

        await handler.run()

        XCTAssertTrue(presented.isEmpty)
        let logs = await logService.recent(10)
        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(logs.first?.gateOutcome, .errored)
        XCTAssertNotNil(logs.first?.gateLatencyMs)
        XCTAssertEqual(logs.first?.errorDescription, "captureFailed(\"simulated\")")
    }

    // MARK: - Not-implemented kind

    func test_run_whenKindNotImplemented_doesNotCapture_logsRestricted() async {
        // Use a kind whose isImplemented returns false today (Week 1
        // implements only .screenRecording). The gate throws .notImplemented
        // before any capture work runs.
        let checker = StubChecker(.granted)
        let ui = SpyUI()
        let gate = PermissionsGate(checker: checker, permissionUI: ui)
        let capture = SpyCapture(stub: makeStubScreenshot())
        let logService = LocalLogService(capacity: 16)

        var presented: [CapturedScreenshot] = []
        let handler = HotkeyInvocationHandler(
            permissionsGate: gate,
            screenCaptureService: capture,
            presentScreenshot: { presented.append($0) },
            logService: logService,
            kind: .accessibility
        )

        await handler.run()

        let observed = await capture.observedTargets()
        XCTAssertTrue(observed.isEmpty, "Capture must not run when kind is unimplemented")
        XCTAssertTrue(presented.isEmpty)

        let logs = await logService.recent(10)
        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(logs.first?.gateOutcome, .restricted)
        XCTAssertNil(logs.first?.gateLatencyMs, "gate didn't grant; latency must stay nil")
        XCTAssertNotNil(logs.first?.errorDescription)

        // The gate does NOT show UI for .notImplemented (per the existing
        // PermissionsGateTests contract: not-implemented is silent).
        let shown = await ui.shownKinds
        XCTAssertTrue(shown.isEmpty)
    }
}
