import AppKit
import SwiftUI

struct PermissionGateView: View {
    let kind: PermissionKind

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("\(kind.displayName) required")
                .font(.headline)
            Text("Grant permission in System Settings, then retry the invocation.")
                .foregroundStyle(.secondary)
            Button("Open System Settings") {
                openSettings()
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .shadow(radius: 18)
    }

    private func openSettings() {
        guard kind == .screenRecording,
              let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
        else {
            return
        }

        NSWorkspace.shared.open(url)
    }
}
