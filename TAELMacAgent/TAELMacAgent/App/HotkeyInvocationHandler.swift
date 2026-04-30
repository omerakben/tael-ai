//
//  HotkeyInvocationHandler.swift
//  TAELMacAgent
//
//  Single invocation of the gate → capture → HUD pipeline.
//  Lives outside `AppDelegate` so it can be unit-tested without a menubar or NSPanel.
//

import Foundation
import os.log

@MainActor
struct HotkeyInvocationHandler {
    let permissionsGate: PermissionsGate
    let screenCaptureService: any DisplayScreenshotCapturing
    let focusedWindowReader: (any FocusedWindowReading)?
    let presentScreenshot: (CapturedScreenshot) -> Void
    let presentContext: ((ContextBundle) -> Void)?
    let presentError: (String) -> Void
    let logService: LocalLogService
    let now: () -> Date
    let kind: PermissionKind

    init(
        permissionsGate: PermissionsGate,
        screenCaptureService: any DisplayScreenshotCapturing,
        focusedWindowReader: (any FocusedWindowReading)? = nil,
        presentScreenshot: @escaping (CapturedScreenshot) -> Void,
        presentContext: ((ContextBundle) -> Void)? = nil,
        presentError: @escaping (String) -> Void = { _ in },
        logService: LocalLogService,
        now: @escaping () -> Date = Date.init,
        kind: PermissionKind = .screenRecording
    ) {
        self.permissionsGate = permissionsGate
        self.screenCaptureService = screenCaptureService
        self.focusedWindowReader = focusedWindowReader
        self.presentScreenshot = presentScreenshot
        self.presentContext = presentContext
        self.presentError = presentError
        self.logService = logService
        self.now = now
        self.kind = kind
    }

    private static let log = Logger(subsystem: "ai.tael.macagent", category: "HotkeyInvocationHandler")

    func run() async {
        let started = now()
        let gateStart = started
        var gateLatencyMs: Double?
        var captureLatencyMs: Double?

        do {
            let screenshot = try await permissionsGate.withPermission(kind) { grant in
                let gateEnd = self.now()
                gateLatencyMs = gateEnd.timeIntervalSince(gateStart) * 1000
                let captureStart = gateEnd
                let result = try await screenCaptureService.captureDisplayScreenshot(grant, target: .week1Default)
                let captureEnd = self.now()
                captureLatencyMs = captureEnd.timeIntervalSince(captureStart) * 1000

                return result
            }

            let focusedWindow = await captureFocusedWindowIfAvailable()
            let bundle = ContextBundle(screenshot: screenshot, focusedWindow: focusedWindow)
            await logService.record(InvocationLog(
                hotkeyTimestamp: started,
                gateOutcome: .granted,
                gateLatencyMs: gateLatencyMs,
                captureLatencyMs: captureLatencyMs,
                targetDescription: bundle.logTargetDescription
            ))

            if let presentContext {
                presentContext(bundle)
            } else {
                presentScreenshot(screenshot)
            }
        } catch let error as PermissionError {
            let outcome: InvocationLog.GateOutcome
            switch error {
            case .missing: outcome = .denied
            case .notImplemented: outcome = .restricted
            }
            await logService.record(InvocationLog(
                hotkeyTimestamp: started,
                gateOutcome: outcome,
                errorDescription: error.localizedDescription
            ))
        } catch {
            await logService.record(InvocationLog(
                hotkeyTimestamp: started,
                gateOutcome: .errored,
                gateLatencyMs: gateLatencyMs,
                errorDescription: String(describing: error)
            ))
            presentError("Screen capture failed: \(error.localizedDescription)")
            Self.log.error("Hotkey invocation failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func captureFocusedWindowIfAvailable() async -> FocusedWindowMetadata? {
        guard let focusedWindowReader else { return nil }

        do {
            return try await permissionsGate.withPermission(.accessibility, showMissingUI: false) { grant in
                try await focusedWindowReader.captureFocusedWindowMetadata(grant)
            }
        } catch let error as PermissionError {
            Self.log.info("Focused-window metadata skipped: \(error.localizedDescription, privacy: .public)")
            return nil
        } catch {
            Self.log.error("Focused-window metadata failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}
