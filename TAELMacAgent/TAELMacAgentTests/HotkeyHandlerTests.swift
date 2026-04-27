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

    /// Pops dates from a fixed sequence each time it's read. The handler
    /// reads `now()` exactly three times on the granted path (started, then once
    /// inside the closure for gateEnd which also serves as captureStart,
    /// then once for captureEnd). Built as a class so the closure-captured
    /// state survives across reads.
    private final class StubClock: @unchecked Sendable {
        private var ticks: [Date]
        init(_ ticks: [Date]) { self.ticks = ticks }
        func next() -> Date {
            precondition(!ticks.isEmpty, "StubClock ran out of ticks")
            return ticks.removeFirst()
        }
    }

    // MARK: - Granted path

    func test_run_whenGranted_callsCaptureAndPresentsAndLogsGranted() async throws {
        let checker = StubChecker(.granted)
        let ui = SpyUI()
        let gate = PermissionsGate(checker: checker, permissionUI: ui)
        let capture = SpyCapture(stub: makeStubScreenshot())
        let logService = LocalLogService(capacity: 16)

        // Pin exact latencies: started=0, gateEnd=0.1 (100ms gate),
        // captureEnd=0.3 (200ms capture). The handler reads now() three
        // times on the granted path: started, gateEnd, captureEnd.
        let clock = StubClock([
            Date(timeIntervalSince1970: 0),
            Date(timeIntervalSince1970: 0.1),
            Date(timeIntervalSince1970: 0.3),
        ])

        var presented: [CapturedScreenshot] = []
        var presentedErrors: [String] = []
        let handler = HotkeyInvocationHandler(
            permissionsGate: gate,
            screenCaptureService: capture,
            presentScreenshot: { presented.append($0) },
            presentError: { presentedErrors.append($0) },
            logService: logService,
            now: { clock.next() }
        )

        await handler.run()

        let targets = await capture.observedTargets()
        XCTAssertEqual(targets, [.week1Default])
        XCTAssertEqual(presented.count, 1)
        XCTAssertTrue(presentedErrors.isEmpty, "Granted path must not present an error HUD")

        let logs = await logService.recent(10)
        XCTAssertEqual(logs.count, 1)
        let row = try XCTUnwrap(logs.first)
        XCTAssertEqual(row.gateOutcome, .granted)
        XCTAssertEqual(row.gateLatencyMs ?? -1, 100, accuracy: 0.001,
            "gate took 100ms (0 → 0.1 second), value must be ms not seconds")
        XCTAssertEqual(row.captureLatencyMs ?? -1, 200, accuracy: 0.001,
            "capture took 200ms (0.1 → 0.3 second)")
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

    func test_run_whenCaptureFails_logsErroredOutcome() async throws {
        let checker = StubChecker(.granted)
        let ui = SpyUI()
        let gate = PermissionsGate(checker: checker, permissionUI: ui)
        let capture = SpyCapture(stub: makeStubScreenshot())
        await capture.setError(ScreenCaptureError.captureFailed("simulated"))

        let logService = LocalLogService(capacity: 16)

        // started=0, gateEnd=0.05 (50ms). Capture fails immediately after
        // the gate grants, so only two ticks are needed.
        let clock = StubClock([
            Date(timeIntervalSince1970: 0),
            Date(timeIntervalSince1970: 0.05),
        ])

        var presented: [CapturedScreenshot] = []
        var presentedErrors: [String] = []
        let handler = HotkeyInvocationHandler(
            permissionsGate: gate,
            screenCaptureService: capture,
            presentScreenshot: { presented.append($0) },
            presentError: { presentedErrors.append($0) },
            logService: logService,
            now: { clock.next() }
        )

        await handler.run()

        XCTAssertTrue(presented.isEmpty)
        XCTAssertEqual(presentedErrors.count, 1)
        let msg = try XCTUnwrap(presentedErrors.first)
        XCTAssertTrue(msg.contains("Screen capture failed"),
            "Error HUD message should lead with the user-facing prefix")
        let logs = await logService.recent(10)
        XCTAssertEqual(logs.count, 1)
        let row = try XCTUnwrap(logs.first)
        XCTAssertEqual(row.gateOutcome, .errored)
        XCTAssertEqual(row.errorDescription, "captureFailed(\"simulated\")")
        XCTAssertEqual(row.gateLatencyMs ?? -1, 50, accuracy: 0.001,
            "gate granted in 50ms before capture threw; latency must be retained")
    }

    // MARK: - Not-implemented kind

    func test_run_whenKindNotImplemented_doesNotCapture_logsRestricted() async {
        // Use a kind whose isImplemented returns false today (Week 1 implements
        // .screenRecording, PR 4 implements .accessibility; .microphone,
        // .appleEvents, .inputMonitoring stay placeholders until their
        // milestones).
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
            kind: .microphone
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
