//
//  ScreenCaptureService.swift
//  TAELMacAgent
//
//  Protected service. Only callable with a `PermissionGrant` minted by
//  `PermissionsGate.withPermission(.screenRecording)`.
//
//  PR 1: this is a typed stub. The real ScreenCaptureKit path lands in
//  PR 2 (Week 1 ticket 8) using:
//
//      SCShareableContent
//      SCContentFilter
//      SCStreamConfiguration
//      SCScreenshotManager.captureImage(contentFilter:configuration:)
//
//  Do NOT use `SCScreenshotManager.captureImage(in:)` — that overload
//  is macOS 15.2+, and our deployment target is macOS 14.0+
//  (v0.3 §1.1, §23.1).
//

import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

public enum ScreenCaptureError: Error, Equatable {
    /// PR 1 placeholder. Removed when ScreenCaptureKit lands in PR 2.
    case notImplemented
    /// `SCShareableContent` returned no displays.
    case noDisplaysAvailable
    /// Underlying ScreenCaptureKit error. Wrapped to keep call sites
    /// independent of the framework.
    case captureFailed(String)
}

/// Minimal protocol the hotkey/wiring layer depends on. Lets tests
/// inject a mock that returns a synthetic `CapturedScreenshot` without
/// pulling in ScreenCaptureKit or requiring a real TCC grant.
public protocol DisplayScreenshotCapturing: Sendable {
    func captureDisplayScreenshot(
        _ grant: PermissionGrant,
        target: ScreenshotTarget
    ) async throws -> CapturedScreenshot
}

public extension DisplayScreenshotCapturing {
    func captureDisplayScreenshot(_ grant: PermissionGrant) async throws -> CapturedScreenshot {
        try await captureDisplayScreenshot(grant, target: .week1Default)
    }
}

public final class ScreenCaptureService: DisplayScreenshotCapturing {
    public init() {}

    /// Capture a screenshot of `target`, falling back to `.mainDisplay`
    /// if `displayContainingCursor` cannot be resolved.
    ///
    /// PR 1 throws `ScreenCaptureError.notImplemented`. The signature
    /// is the contract that PR 2 will fill in.
    public func captureDisplayScreenshot(
        _ grant: PermissionGrant,
        target: ScreenshotTarget
    ) async throws -> CapturedScreenshot {
        precondition(
            grant.kind == .screenRecording,
            "ScreenCaptureService requires a .screenRecording grant"
        )

        // PR 2 implementation outline (do not enable in PR 1):
        //
        //   let content = try await SCShareableContent.current
        //   let display = resolveTargetDisplay(content, target: target)
        //   let filter = SCContentFilter(display: display, excludingWindows: [])
        //   let cfg = SCStreamConfiguration()
        //   cfg.width  = display.width  * Int(display.backingScaleFactor)
        //   cfg.height = display.height * Int(display.backingScaleFactor)
        //   cfg.showsCursor = true
        //   let cgImage = try await SCScreenshotManager.captureImage(
        //       contentFilter: filter, configuration: cfg
        //   )
        //   return CapturedScreenshot(image: cgImage, target: resolvedTarget)

        throw ScreenCaptureError.notImplemented
    }
}
