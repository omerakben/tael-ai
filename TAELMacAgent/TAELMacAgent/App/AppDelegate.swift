import AppKit
import Foundation

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?
    private let hudPanelController = HUDPanelController()
    private let logService = LocalLogService()
    private var hotkeyManager: HotkeyManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        hotkeyManager = HotkeyManager { [weak self] in
            self?.showScaffoldHUD(source: .hotkeyPlaceholder)
        }
        hotkeyManager?.start()

        menuBarController = MenuBarController(
            onShowHUD: { [weak self] in
                self?.showScaffoldHUD(source: .menuBar)
            },
            onQuit: {
                NSApp.terminate(nil)
            }
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyManager?.stop()
    }

    private func showScaffoldHUD(source: InvocationLog.Source) {
        hudPanelController.showPlaceholder()

        let log = InvocationLog(
            source: source,
            occurredAt: Date(),
            permissionStatus: nil,
            message: "Scaffold HUD placeholder shown"
        )

        Task {
            await logService.record(log)
        }
    }
}
