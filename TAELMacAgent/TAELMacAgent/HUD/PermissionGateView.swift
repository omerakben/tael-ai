//
//  PermissionGateView.swift
//  TAELMacAgent
//
//  Single source of UI for "TAEL needs permission X". Routed through
//  by `PermissionsGate` whenever a protected operation is requested
//  while the OS reports anything other than `.granted`.
//
//  See docs/ProtectedAPICallPolicy.md.
//

import AppKit
import SwiftUI

struct PermissionGateView: View {
    let kind: PermissionKind
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("TAEL needs \(kind.displayName) permission")
                .font(.headline)

            Text(explanation)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack {
                Button("Open System Settings") {
                    openSettings()
                }
                .keyboardShortcut(.defaultAction)

                Button("Cancel") {
                    onCancel()
                }
            }

            Text("After granting, quit and relaunch TAEL.")
                .font(.footnote)
                .foregroundStyle(.tertiary)

            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var explanation: String {
        switch kind {
        case .screenRecording:
            return "Used to capture the display containing the cursor when you invoke TAEL. Screenshots are not saved to disk."
        case .accessibility:
            return "Used to read the focused window's UI tree (title, role, content text) so TAEL can scope context to what you're looking at. Read-only — TAEL does not synthesize keyboard or mouse events."
        case .microphone:
            return "Used to capture your voice for the active invocation. Not yet implemented."
        case .appleEvents:
            return "Used to send actions to other apps. Not yet implemented."
        case .inputMonitoring:
            return "Used to capture the global hotkey. Not yet implemented."
        }
    }

    private func openSettings() {
        let urlString: String
        switch kind {
        case .screenRecording:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
        case .accessibility:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        case .microphone:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
        case .appleEvents:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation"
        case .inputMonitoring:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
        }
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}
