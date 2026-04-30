//
//  HUDScreenshotView.swift
//  TAELMacAgent
//
//  Caps screenshots at 720x480 so a full 5K display still fits in the HUD.
//

import SwiftUI
import AppKit

struct HUDScreenshotView: View {
    let screenshot: CapturedScreenshot

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Captured \(screenshot.width)x\(screenshot.height) - \(targetLabel)")
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
