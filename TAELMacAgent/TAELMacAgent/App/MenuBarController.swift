import AppKit

@MainActor
final class MenuBarController {
    private let statusItem: NSStatusItem

    init(onShowHUD: @escaping () -> Void, onQuit: @escaping () -> Void) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: "TAEL AI")
            button.imagePosition = .imageOnly
        }

        let menu = NSMenu()
        menu.addItem(MenuActionItem(title: "Show HUD placeholder", actionHandler: onShowHUD))
        menu.addItem(.separator())
        menu.addItem(MenuActionItem(title: "Quit TAEL AI", actionHandler: onQuit))
        statusItem.menu = menu
    }
}

private final class MenuActionItem: NSMenuItem {
    private let actionHandler: () -> Void

    init(title: String, actionHandler: @escaping () -> Void) {
        self.actionHandler = actionHandler
        super.init(title: title, action: #selector(runAction), keyEquivalent: "")
        target = self
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func runAction() {
        actionHandler()
    }
}
