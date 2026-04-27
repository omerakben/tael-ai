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
    /// Set by `AppDelegate` to the gate→capture→HUD pipeline. Async so
    /// the manager can await it and clear the in-flight guard only
    /// after the full invocation completes — so re-entrant presses
    /// during a slow capture get dropped instead of stacking.
    var onTrigger: (() async -> Void)?

    private var isInFlight = false

    /// Registers the real global hotkey with KeyboardShortcuts.
    /// Call once during `applicationDidFinishLaunching`.
    func installBinding() {
        KeyboardShortcuts.onKeyDown(for: .toggleTAEL) { [weak self] in
            self?.fireIfFree()
        }
    }

    private func fireIfFree() {
        guard !isInFlight else { return }
        guard let onTrigger else { return }
        isInFlight = true
        Task { @MainActor [weak self] in
            await onTrigger()
            self?.isInFlight = false
        }
    }

    func tearDown() {
        KeyboardShortcuts.disable(.toggleTAEL)
        onTrigger = nil
        isInFlight = false
    }

    /// Test-only entry: simulates a hotkey press without going through
    /// the KeyboardShortcuts package. Exposed via @testable import.
    func simulatePressForTesting() {
        fireIfFree()
    }
}
