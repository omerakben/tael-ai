//
//  FocusedWindowMetadata.swift
//  TAELMacAgent
//
//  Snapshot of the frontmost app's focused window taken alongside
//  the screenshot during a hotkey invocation. All fields optional
//  because AX availability varies by app, sandbox, and visibility.
//

import Foundation

public struct FocusedWindowMetadata: Equatable, Sendable {
    public let appBundleID: String?
    public let appName: String?
    public let windowTitle: String?
    public let windowRole: String?
    public let capturedAt: Date

    public init(
        appBundleID: String?,
        appName: String?,
        windowTitle: String?,
        windowRole: String?,
        capturedAt: Date = Date()
    ) {
        self.appBundleID = appBundleID
        self.appName = appName
        self.windowTitle = windowTitle
        self.windowRole = windowRole
        self.capturedAt = capturedAt
    }

    /// True iff at least one field beyond capturedAt is populated.
    public var hasAnyData: Bool {
        appBundleID != nil || appName != nil || windowTitle != nil || windowRole != nil
    }
}
