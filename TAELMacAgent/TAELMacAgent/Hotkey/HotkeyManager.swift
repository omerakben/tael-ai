//
//  HotkeyManager.swift
//  TAELMacAgent
//
//  Global hotkey owner. PR 1 contains only a placeholder binding hook
//  (no real registration), so the app can launch without pulling in a
//  third-party package and without calling any protected API.
//
//  PR 2 (Week 1 ticket 6) adds the `KeyboardShortcuts` SPM package and
//  registers a real shortcut that calls `onTrigger`.
//

import Foundation

@MainActor
final class HotkeyManager {
    /// Set by the wiring code in `AppDelegate` once the gate, capture
    /// service, and HUD exist. PR 1 leaves this nil-by-default; PR 2
    /// will assign a closure that runs:
    ///
    ///     try await permissionsGate.withPermission(.screenRecording) { grant in
    ///         let shot = try await screenCaptureService
    ///             .captureDisplayScreenshot(grant)
    ///         hudController.present(shot)
    ///     }
    var onTrigger: (() -> Void)?

    /// PR 1 no-op binding. Exists so the call site in `AppDelegate`
    /// can be wired now and the PR 2 change is purely additive.
    func installPlaceholderBinding() {
        // Intentionally empty.
    }

    func tearDown() {
        onTrigger = nil
    }
}
