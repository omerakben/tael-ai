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
        // No `WindowGroup` by design. We are a menubar utility
        // (LSUIElement = YES). The HUD is an NSPanel managed by
        // `HUDPanelController`.
        //
        // SwiftUI requires the `App.body` to return at least one
        // Scene, so we keep an empty `Settings` scene and replace the
        // `appSettings` command group with an empty one — this hides
        // the otherwise-visible Settings menu item and prevents an
        // empty Settings window from being summoned with ⌘,.
        Settings {
            EmptyView()
        }
        .commands {
            CommandGroup(replacing: .appSettings) { }
        }
    }
}
