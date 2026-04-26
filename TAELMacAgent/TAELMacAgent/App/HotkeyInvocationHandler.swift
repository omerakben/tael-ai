//
//  HotkeyInvocationHandler.swift
//  TAELMacAgent
//
//  Single invocation of the Week 1 heartbeat: gate → capture → HUD +
//  log. Extracted from AppDelegate so the wire-up is unit-testable
//  without spinning up a real menubar or NSPanel.
//

import Foundation
import os.log

@MainActor
struct HotkeyInvocationHandler {
    let permissionsGate: PermissionsGate
    let screenCaptureService: any DisplayScreenshotCapturing
    let presentScreenshot: (CapturedScreenshot) -> Void
    let logService: LocalLogService
    let now: () -> Date

    init(
        permissionsGate: PermissionsGate,
        screenCaptureService: any DisplayScreenshotCapturing,
        presentScreenshot: @escaping (CapturedScreenshot) -> Void,
        logService: LocalLogService,
        now: @escaping () -> Date = Date.init
    ) {
        self.permissionsGate = permissionsGate
        self.screenCaptureService = screenCaptureService
        self.presentScreenshot = presentScreenshot
        self.logService = logService
        self.now = now
    }

    private static let log = Logger(subsystem: "ai.tael.macagent", category: "HotkeyInvocationHandler")

    func run() async {
        let started = now()
        let gateStart = started

        do {
            let screenshot = try await permissionsGate.withPermission(.screenRecording) { grant in
                let gateEnd = self.now()
                let captureStart = gateEnd
                let result = try await screenCaptureService.captureDisplayScreenshot(grant, target: .week1Default)
                let captureEnd = self.now()

                await logService.record(InvocationLog(
                    hotkeyTimestamp: started,
                    gateOutcome: .granted,
                    gateLatencyMs: gateEnd.timeIntervalSince(gateStart) * 1000,
                    captureLatencyMs: captureEnd.timeIntervalSince(captureStart) * 1000,
                    targetDescription: "\(result.target) \(result.width)x\(result.height)"
                ))

                return result
            }
            presentScreenshot(screenshot)
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
            // Use case-form so debug-mode log inspection sees
            // `captureFailed("…")` rather than the generic NSError-bridged
            // string that Swift errors get without LocalizedError.
            await logService.record(InvocationLog(
                hotkeyTimestamp: started,
                gateOutcome: .errored,
                errorDescription: String(describing: error)
            ))
            Self.log.error("Hotkey invocation failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
