//
//  HUDPanelController.swift
//  TAELMacAgent
//
//  Owns the non-activating NSPanel that hosts the HUD. Implements
//  `PermissionGatePresenting` so `PermissionsGate` can route missing-
//  permission states through the same surface as the placeholder content.
//
//  PR 1 ships an intentionally ugly placeholder. Real screenshot
//  rendering lands in PR 2 (Week 1 ticket 10).
//

import AppKit
import SwiftUI

@MainActor
final class HUDPanelController: NSObject, PermissionGatePresenting {
    private var panel: NSPanel?

    override init() {
        super.init()
    }

    /// Show a placeholder HUD with the SwiftUI view. Used by the
    /// "Show HUD (placeholder)" menubar item in PR 1.
    func showPlaceholder() {
        presentNew(content: HUDView())
    }

    func present(screenshot: CapturedScreenshot) {
        // Task 7 fills this in. Stub so Task 6's AppDelegate wiring
        // compiles in its own commit.
        showPlaceholder()
    }

    /// `PermissionGatePresenting` implementation: show a sheet-like HUD that
    /// explains the missing permission and links to System Settings.
    /// `nonisolated` so it satisfies the non-isolated protocol
    /// requirement; the body hops to `@MainActor` explicitly.
    nonisolated func showGate(for kind: PermissionKind) async {
        await MainActor.run {
            self.presentNew(content: PermissionGateView(kind: kind) { [weak self] in
                self?.tearDown()
            })
        }
    }

    func tearDown() {
        panel?.orderOut(nil)
        panel = nil
    }

    // MARK: - Internals

    /// Close any currently-presented panel and present a fresh one with
    /// `content`. Avoids both the multi-panel leak and the "stale rootView"
    /// bug from reusing a panel that was created for a different surface
    /// (gate vs placeholder).
    private func presentNew<Content: View>(content: Content) {
        panel?.orderOut(nil)
        panel = nil
        let next = makePanel(content: content)
        panel = next
        present(next)
    }

    private func makePanel<Content: View>(content: Content) -> NSPanel {
        let host = NSHostingController(rootView: AnyView(content))
        host.view.frame = NSRect(x: 0, y: 0, width: 480, height: 280)

        // v0.3 §23.11 defaults. Borderless + non-activating gives the
        // overlay-on-top-of-the-user's-app feel; transient prevents
        // the panel from showing in the app switcher. Explicit
        // isReleasedWhenClosed = false because the controller owns
        // the lifecycle via tearDown().
        let panel = NSPanel(
            contentRect: host.view.frame,
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.contentViewController = host
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        return panel
    }

    private func present(_ panel: NSPanel) {
        // `.orderFrontRegardless` shows without activating the app.
        // We deliberately do NOT call `NSApp.activate(...)` — Week 1
        // requires the HUD to appear without stealing focus from the
        // user's current app (Terminal, VS Code, Cursor, etc.).
        panel.center()
        panel.orderFrontRegardless()
    }
}
