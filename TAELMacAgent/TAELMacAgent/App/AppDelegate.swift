//
//  AppDelegate.swift
//  TAELMacAgent
//

import AppKit
import Foundation
import os.log

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let log = Logger(subsystem: "ai.tael.macagent", category: "AppDelegate")

    private var menuBarController: MenuBarController?
    private var hotkeyManager: HotkeyManager?
    private var hudController: HUDPanelController?
    private var permissionsGate: PermissionsGate?
    private var screenCaptureService: DisplayScreenshotCapturing?
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

        // Hotkey closure: gate → capture → HUD + log. Runs on the main
        // actor (the `@MainActor` class isolation already covers it).
        hotkeyManager.onTrigger = { [weak self] in
            guard let self,
                  let permissionsGate = self.permissionsGate,
                  let screenCaptureService = self.screenCaptureService,
                  let hudController = self.hudController,
                  let logService = self.logService else {
                AppDelegate.log.error("Hotkey fired but app state unavailable; ignoring")
                return
            }
            let handler = HotkeyInvocationHandler(
                permissionsGate: permissionsGate,
                screenCaptureService: screenCaptureService,
                presentScreenshot: { shot in hudController.present(screenshot: shot) },
                logService: logService
            )
            await handler.run()
        }
        hotkeyManager.installBinding()
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyManager?.tearDown()
        hudController?.tearDown()
    }
}
