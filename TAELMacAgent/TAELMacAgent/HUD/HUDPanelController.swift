import AppKit
import SwiftUI

@MainActor
final class HUDPanelController: PermissionGatePresenting {
    private var panel: NSPanel?

    func showPlaceholder() {
        show(
            HUDView(
                title: "TAEL AI",
                detail: "Menubar scaffold is running."
            )
        )
    }

    func showGate(for kind: PermissionKind) async {
        show(PermissionGateView(kind: kind))
    }

    func close() {
        panel?.orderOut(nil)
    }

    private func show<Content: View>(_ content: Content) {
        let panel = panel ?? makePanel()
        self.panel = panel

        panel.contentView = NSHostingView(rootView: content)
        position(panel)
        panel.orderFrontRegardless()
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 220),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.isMovableByWindowBackground = true
        return panel
    }

    private func position(_ panel: NSPanel) {
        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { screen in
            NSMouseInRect(mouseLocation, screen.frame, false)
        } ?? NSScreen.main

        guard let frame = screen?.visibleFrame else {
            panel.center()
            return
        }

        let panelSize = panel.frame.size
        let origin = NSPoint(
            x: frame.maxX - panelSize.width - 24,
            y: frame.maxY - panelSize.height - 24
        )
        panel.setFrameOrigin(origin)
    }
}
