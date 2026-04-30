//
//  ContextBundle.swift
//  TAELMacAgent
//
//  One invocation's visible context. Screenshot is the Week 1 heartbeat;
//  focused-window metadata is Week 2 context and must degrade gracefully.
//

import Foundation

public struct ContextBundle: Sendable {
    public let screenshot: CapturedScreenshot?
    public let focusedWindow: FocusedWindowMetadata?
    public let capturedAt: Date

    public init(
        screenshot: CapturedScreenshot?,
        focusedWindow: FocusedWindowMetadata?,
        capturedAt: Date = Date()
    ) {
        self.screenshot = screenshot
        self.focusedWindow = focusedWindow
        self.capturedAt = capturedAt
    }

    public var hasFocusedWindowData: Bool {
        focusedWindow?.hasAnyData == true
    }

    public var logTargetDescription: String? {
        var parts: [String] = []
        if let screenshot {
            parts.append("\(screenshot.target) \(screenshot.width)x\(screenshot.height)")
        }
        if let focusedWindow, focusedWindow.hasAnyData {
            let app = focusedWindow.applicationName ?? focusedWindow.bundleIdentifier ?? "unknown app"
            let title = focusedWindow.windowTitle ?? "untitled window"
            parts.append("\(app): \(title)")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " | ")
    }
}
