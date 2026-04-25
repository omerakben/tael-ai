//
//  TAELMacAgentApp.swift
//  TAELMacAgent
//
//  SwiftUI App entry point. Lifecycle and menubar wiring live in
//  `AppDelegate`; this file is intentionally tiny.
//

import SwiftUI

@main
struct TAELMacAgentApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // No `WindowGroup` and no `Settings` scene by design. We are a
        // menubar utility (LSUIElement = YES). The HUD is an NSPanel
        // managed by `HUDPanelController`.
        Settings {
            EmptyView()
        }
    }
}
