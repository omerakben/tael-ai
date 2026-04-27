//
//  HUDErrorView.swift
//  TAELMacAgent
//
//  Shown when a hotkey invocation reaches the capture stage and fails.
//  Mirrors HUDScreenshotView's layout for visual consistency.
//

import SwiftUI

struct HUDErrorView: View {
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Capture failed", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(.orange)

            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 480, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
    }
}
