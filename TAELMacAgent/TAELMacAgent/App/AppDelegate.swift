//
//  AppDelegate.swift
//  TAELMacAgent
//

import AppKit
import Foundation
import os.log
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?
    private var hotkeyManager: HotkeyManager?
    private var hudController: HUDPanelController?
    private var permissionsGate: PermissionsGate?
    private var screenCaptureService: DisplayScreenshotCapturing?
    private var logService: LocalLogService?
    private let log = Logger(subsystem: "ai.tael.macagent", category: "AppDelegate")

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Belt and braces: even though `LSUIElement = YES`, force
        // accessory mode at runtime so the app never gets a Dock icon.
        NSApp.setActivationPolicy(.accessory)

        let logService = LocalLogService()
        let hudController = HUDPanelController()
        let permissionsGate = PermissionsGate(
            checker: PermissionsChecker(),
            permissionUI: hudController
        )
        let screenCaptureService = ScreenCaptureService()
        let hotkeyManager = HotkeyManager()
        let menuBarController = MenuBarController(
            onShowHUD: { [weak hudController] in
                hudController?.showPlaceholder()
            },
            onQuit: {
                NSApp.terminate(nil)
            }
        )

        self.logService = logService
        self.hudController = hudController
        self.permissionsGate = permissionsGate
        self.screenCaptureService = screenCaptureService
        self.hotkeyManager = hotkeyManager
        self.menuBarController = menuBarController

        menuBarController.install()

        // Hotkey closure: gate → capture → HUD + log. Runs on the main
        // actor (the `@MainActor` class isolation already covers it).
        hotkeyManager.onTrigger = { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                await self.handleHotkeyInvocation()
            }
        }
        hotkeyManager.installBinding()
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyManager?.tearDown()
        hudController?.tearDown()
    }

    /// One invocation of the Week 1 heartbeat. Captures latency,
    /// outcome, and target metadata into a LocalLogService row.
    private func handleHotkeyInvocation() async {
        guard let permissionsGate, let screenCaptureService, let hudController, let logService else {
            log.fault("Hotkey fired before AppDelegate finished launch wiring; ignoring.")
            return
        }

        let started = Date()
        let gateStart = started

        do {
            let screenshot = try await permissionsGate.withPermission(.screenRecording) { grant in
                let gateEnd = Date()
                let captureStart = gateEnd
                let result = try await screenCaptureService.captureDisplayScreenshot(grant, target: .week1Default)
                let captureEnd = Date()

                await logService.record(InvocationLog(
                    hotkeyTimestamp: started,
                    gateOutcome: .granted,
                    gateLatencyMs: gateEnd.timeIntervalSince(gateStart) * 1000,
                    captureLatencyMs: captureEnd.timeIntervalSince(captureStart) * 1000,
                    targetDescription: "\(result.target) \(result.width)x\(result.height)"
                ))

                return result
            }
            hudController.present(screenshot: screenshot)
        } catch let error as PermissionError {
            // PermissionsGate already invoked permissionUI.showGate.
            // Log the outcome and stop.
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
                errorDescription: error.localizedDescription
            ))
            log.error("Hotkey invocation failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
