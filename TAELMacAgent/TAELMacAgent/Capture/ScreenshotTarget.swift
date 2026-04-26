//
//  ScreenshotTarget.swift
//  TAELMacAgent
//
//  Week 1 capture target. v0.3 §23.2 is explicit:
//
//      "Display containing cursor, fallback to main display."
//
//  This is NOT focused-window capture. Focused-window context is AX
//  work and starts in Week 2.
//

import Foundation

public enum ScreenshotTarget: Sendable, Equatable {
    case displayContainingCursor
    case mainDisplay

    /// Week 1 default. Try `displayContainingCursor` first; the
    /// capture service falls back to `.mainDisplay` if no display
    /// matches the cursor location.
    public static let week1Default: ScreenshotTarget = .displayContainingCursor
}
