//
//  FocusedWindowMetadata.swift
//  TAELMacAgent
//
//  Snapshot of the frontmost app's focused window taken alongside
//  the screenshot during a hotkey invocation. All fields are optional
//  because AX availability varies by app, sandbox, and visibility.
//

import Foundation

public struct FocusedWindowMetadata: Equatable, Sendable {
    public let bundleIdentifier: String?
    public let applicationName: String?
    public let windowTitle: String?
    public let windowRole: String?
    public let capturedAt: Date

    public init(
        bundleIdentifier: String?,
        applicationName: String?,
        windowTitle: String?,
        windowRole: String?,
        capturedAt: Date = Date()
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.applicationName = applicationName
        self.windowTitle = windowTitle
        self.windowRole = windowRole
        self.capturedAt = capturedAt
    }

    public var hasAnyData: Bool {
        bundleIdentifier != nil ||
            applicationName != nil ||
            windowTitle != nil ||
            windowRole != nil
    }
}
