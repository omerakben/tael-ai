//
//  HotkeyManager.swift
//  TAELMacAgent
//
//  Owns the global hotkey registration via the KeyboardShortcuts
//  package. The actual work (gate → capture → HUD) is the closure
//  assigned to `onTrigger` by `AppDelegate`.
//

import Foundation
import KeyboardShortcuts

@MainActor
final class HotkeyManager {
    /// Set by `AppDelegate` to the gate→capture→HUD closure.
    /// Read inside the KeyboardShortcuts callback.
    var onTrigger: (() -> Void)?

    /// Registers the real global hotkey with KeyboardShortcuts.
    /// Call once during `applicationDidFinishLaunching`.
    func installBinding() {
        KeyboardShortcuts.onKeyDown(for: .toggleTAEL) { [weak self] in
            self?.onTrigger?()
        }
    }

    /// Backwards-compatible alias for the PR 1 call site. Removed in
    /// the same commit that updates `AppDelegate` to call
    /// `installBinding()` directly (Task 6).
    @available(*, deprecated, renamed: "installBinding")
    func installPlaceholderBinding() {
        installBinding()
    }

    func tearDown() {
        KeyboardShortcuts.disable(.toggleTAEL)
        onTrigger = nil
    }
}
