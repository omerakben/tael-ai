//
//  HotkeyName.swift
//  TAELMacAgent
//
//  Declares the global hotkey name used by KeyboardShortcuts.
//  Default chord: ⌘⇧T ("T" for TAEL). User can rebind via Settings
//  later (post-PR 2).
//

import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// Primary "summon TAEL" hotkey. v0.3 §1: this triggers the full
    /// hotkey → gate → capture → HUD pipeline.
    static let toggleTAEL = Self(
        "toggleTAEL",
        default: .init(.t, modifiers: [.command, .shift])
    )
}
