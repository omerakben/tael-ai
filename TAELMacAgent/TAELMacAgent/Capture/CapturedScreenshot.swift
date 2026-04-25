//
//  CapturedScreenshot.swift
//  TAELMacAgent
//

import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// Value type returned by `ScreenCaptureService`. The image is held in
/// memory only; PR 1 explicitly does NOT persist screenshots to disk.
public struct CapturedScreenshot: Sendable {
    public let image: CGImage
    public let width: Int
    public let height: Int
    public let target: ScreenshotTarget
    public let capturedAt: Date

    public init(
        image: CGImage,
        target: ScreenshotTarget,
        capturedAt: Date = Date()
    ) {
        self.image = image
        self.width = image.width
        self.height = image.height
        self.target = target
        self.capturedAt = capturedAt
    }
}
