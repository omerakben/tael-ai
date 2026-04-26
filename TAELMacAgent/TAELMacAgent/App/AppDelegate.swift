//
//  AppDelegate.swift
//  TAELMacAgent
//

import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?
    private var hotkeyManager: HotkeyManager?
    private var hudController: HUDPanelController?
    private var permissionsGate: PermissionsGate?
    private var screenCaptureService: ScreenCaptureService?
    private var logService: LocalLogService?

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

        // PR 1: do NOT register a real global hotkey yet. The hotkey
        // package + the hotkey → gate → capture wire-up land in PR 2
        // (Week 1 tickets 6–9). For now, only the placeholder callback
        // exists, so launching the app does not call any protected
        // API.
        hotkeyManager.installPlaceholderBinding()
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyManager?.tearDown()
        hudController?.tearDown()
    }
}
