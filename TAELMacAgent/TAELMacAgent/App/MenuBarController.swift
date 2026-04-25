//
//  MenuBarController.swift
//  TAELMacAgent
//
//  Owns the NSStatusItem and its menu. PR 1 ships two menu items:
//  "Show HUD" (placeholder) and "Quit". Real invocation happens via
//  the global hotkey path, not the menu.
//

import AppKit

@MainActor
final class MenuBarController {
    private let onShowHUD: () -> Void
    private let onQuit: () -> Void

    private var statusItem: NSStatusItem?

    init(onShowHUD: @escaping () -> Void, onQuit: @escaping () -> Void) {
        self.onShowHUD = onShowHUD
        self.onQuit = onQuit
    }

    func install() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "TAEL"
        item.button?.toolTip = "TAEL AI"
        item.menu = makeMenu()
        statusItem = item
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu(title: "TAEL")

        let show = NSMenuItem(
            title: "Show HUD (placeholder)",
            action: #selector(showHUDAction),
            keyEquivalent: ""
        )
        show.target = self
        menu.addItem(show)

        menu.addItem(.separator())

        let quit = NSMenuItem(
            title: "Quit TAEL",
            action: #selector(quitAction),
            keyEquivalent: "q"
        )
        quit.target = self
        menu.addItem(quit)

        return menu
    }

    @objc private func showHUDAction() {
        onShowHUD()
    }

    @objc private func quitAction() {
        onQuit()
    }
}
