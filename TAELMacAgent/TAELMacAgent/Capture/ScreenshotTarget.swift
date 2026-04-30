//
//  ScreenshotTarget.swift
//  TAELMacAgent
//
//  Default capture target. v0.3 §23.2 is explicit:
//
//      "Display containing cursor, fallback to main display."
//
//  This is NOT focused-window capture. Focused-window AX context lives
//  alongside the screenshot in `ContextBundle` (Week 2).
//

import Foundation

public enum ScreenshotTarget: Sendable, Equatable {
    case displayContainingCursor
    case mainDisplay

    /// Default capture target. Try `displayContainingCursor` first;
    /// the capture service falls back to `.mainDisplay` if no display
    /// matches the cursor location.
    public static let defaultTarget: ScreenshotTarget = .displayContainingCursor
}
