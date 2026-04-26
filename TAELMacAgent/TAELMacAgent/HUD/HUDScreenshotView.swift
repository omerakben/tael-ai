//
//  HUDScreenshotView.swift
//  TAELMacAgent
//
//  Displays a CapturedScreenshot inside the HUD. PR 2: the shot is
//  shown at a fixed maximum size so a full 5K display still fits in a
//  reasonable HUD. Aspect ratio preserved.
//

import SwiftUI
import AppKit

struct HUDScreenshotView: View {
    let screenshot: CapturedScreenshot

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Captured \(screenshot.width)×\(screenshot.height) — \(targetLabel)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Image(decorative: screenshot.image, scale: 1.0, orientation: .up)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 720, maxHeight: 480)
                .background(Color.black.opacity(0.3))
                .cornerRadius(6)

            Text(screenshot.capturedAt.formatted(date: .omitted, time: .standard))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(16)
    }

    private var targetLabel: String {
        switch screenshot.target {
        case .displayContainingCursor: return "cursor display"
        case .mainDisplay: return "main display (fallback)"
        }
    }
}
