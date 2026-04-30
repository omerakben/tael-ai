//
//  HUDPanelController.swift
//  TAELMacAgent
//
//  Owns the non-activating NSPanel that hosts the HUD. Implements
//  `PermissionGatePresenting` so `PermissionsGate` can route missing-
//  permission states through the same surface as the placeholder content.
//
//  Hosts placeholder, screenshot, context bundle, permission, and error HUDs.
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
        presentNew(content: HUDScreenshotView(screenshot: screenshot), size: NSSize(width: 760, height: 560))
    }

    func present(context: ContextBundle) {
        presentNew(content: HUDContextBundleView(context: context), size: NSSize(width: 760, height: 620))
    }

    func present(error message: String) {
        presentNew(content: HUDErrorView(message: message))
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
    private func presentNew<Content: View>(
        content: Content,
        size: NSSize = NSSize(width: 480, height: 280)
    ) {
        panel?.orderOut(nil)
        panel = nil
        let next = makePanel(content: content, size: size)
        panel = next
        present(next)
    }

    private func makePanel<Content: View>(content: Content, size: NSSize) -> NSPanel {
        let host = NSHostingController(rootView: AnyView(content))
        host.view.frame = NSRect(origin: .zero, size: size)

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
