//
//  HotkeyName.swift
//  TAELMacAgent
//
//  Declares the global hotkey name used by KeyboardShortcuts.
//  Default chord: ⌘⇧T ("T" for TAEL). User-rebindable when Settings ships.
//

import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// Primary "summon TAEL" hotkey (v0.3 §1).
    static let toggleTAEL = Self(
        "toggleTAEL",
        default: .init(.t, modifiers: [.command, .shift])
    )
}
