//
//  HUDContextBundleView.swift
//  TAELMacAgent
//
//  Renders the Week 1 screenshot plus Week 2 focused-window metadata.
//

import AppKit
import SwiftUI

struct HUDContextBundleView: View {
    let context: ContextBundle

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            if let screenshot = context.screenshot {
                Image(decorative: screenshot.image, scale: 1.0, orientation: .up)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 720, maxHeight: 440)
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(6)
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text("Focused window")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                if let focusedWindow = context.focusedWindow, focusedWindow.hasAnyData {
                    Text(focusedWindow.applicationName ?? focusedWindow.bundleIdentifier ?? "Unknown app")
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)

                    Text(focusedWindow.windowTitle ?? "No focused window title")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)

                    if let role = focusedWindow.windowRole {
                        Text(role)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                } else {
                    Text("Accessibility metadata unavailable")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(16)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            if let screenshot = context.screenshot {
                Text("Captured \(screenshot.width)x\(screenshot.height)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(targetLabel(for: screenshot))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            } else {
                Text("No screenshot captured")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(context.capturedAt.formatted(date: .omitted, time: .standard))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private func targetLabel(for screenshot: CapturedScreenshot) -> String {
        switch screenshot.target {
        case .displayContainingCursor: return "cursor display"
        case .mainDisplay: return "main display fallback"
        }
    }
}
