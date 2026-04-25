//
//  HUDView.swift
//  TAELMacAgent
//
//  Placeholder HUD content. Intentionally ugly. Real screenshot
//  rendering lands in PR 2.
//

import SwiftUI

struct HUDView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TAEL HUD (placeholder)")
                .font(.headline)
            Text("PR 1 ships only the menubar shell and the permissions boundary.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Press the global hotkey in PR 2 to capture a screenshot.")
                .font(.footnote)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
