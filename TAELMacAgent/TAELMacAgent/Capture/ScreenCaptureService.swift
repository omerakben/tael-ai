//
//  ScreenCaptureService.swift
//  TAELMacAgent
//
//  Protected service. Only callable with a `PermissionGrant` minted by
//  `PermissionsGate.withPermission(.screenRecording)`.
//
//  Real ScreenCaptureKit capture: SCShareableContent → SCContentFilter
//  → SCStreamConfiguration → SCScreenshotManager.captureImage. Cursor
//  display first, mainDisplay fallback (v0.3 §23.2). Width/height are
//  multiplied by the NSScreen backingScaleFactor — explicit per
//  v0.3 §23.10 (the cfg defaults give the wrong dimensions).
//
//  Do NOT use `SCScreenshotManager.captureImage(in:)` — that overload
//  is macOS 15.2+, and our deployment target is macOS 14.0+
//  (v0.3 §1.1, §23.1).
//

import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
#if canImport(ScreenCaptureKit)
import ScreenCaptureKit
#endif
#if canImport(AppKit)
import AppKit
#endif

public enum ScreenCaptureError: Error, Equatable {
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
        try await captureDisplayScreenshot(grant, target: .defaultTarget)
    }
}

/// Resolves the target display per v0.3 §23.2: cursor display first,
/// fallback to main display, fallback to the first available display.
/// Returns the resolved `(SCDisplay, ScreenshotTarget)` so the caller
/// knows whether it got the cursor display or fell back.
@available(macOS 14.0, *)
private func resolveTargetDisplay(
    in content: SCShareableContent,
    requested: ScreenshotTarget
) -> (display: SCDisplay, resolved: ScreenshotTarget)? {
    guard !content.displays.isEmpty else { return nil }

    let mainDisplayID = CGMainDisplayID()

    if requested == .displayContainingCursor {
        let cursorPoint = NSEvent.mouseLocation
        if let nsScreen = NSScreen.screens.first(where: { $0.frame.contains(cursorPoint) }),
           let screenNumber = nsScreen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID,
           let display = content.displays.first(where: { $0.displayID == screenNumber })
        {
            return (display, .displayContainingCursor)
        }
    }

    // Fallback path: main display, then first available.
    if let main = content.displays.first(where: { $0.displayID == mainDisplayID }) {
        return (main, .mainDisplay)
    }
    if let first = content.displays.first {
        return (first, .mainDisplay)
    }
    return nil
}

public final class ScreenCaptureService: DisplayScreenshotCapturing {
    public init() {}

    /// Capture a screenshot of `target`, falling back to `.mainDisplay`
    /// if `displayContainingCursor` cannot be resolved.
    public func captureDisplayScreenshot(
        _ grant: PermissionGrant,
        target: ScreenshotTarget
    ) async throws -> CapturedScreenshot {
        precondition(
            grant.kind == .screenRecording,
            "ScreenCaptureService requires a .screenRecording grant"
        )

        let content: SCShareableContent
        do {
            content = try await SCShareableContent.current
        } catch {
            throw ScreenCaptureError.captureFailed("SCShareableContent.current failed: \(error.localizedDescription)")
        }

        guard let resolved = resolveTargetDisplay(in: content, requested: target) else {
            throw ScreenCaptureError.noDisplaysAvailable
        }

        let display = resolved.display
        let filter = SCContentFilter(display: display, excludingWindows: [])

        let cfg = SCStreamConfiguration()
        let scale = NSScreen.screens
            .first { ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID) == display.displayID }?
            .backingScaleFactor ?? 2.0
        cfg.width = Int((CGFloat(display.width) * scale).rounded())
        cfg.height = Int((CGFloat(display.height) * scale).rounded())
        cfg.showsCursor = true
        cfg.queueDepth = 1

        let cgImage: CGImage
        do {
            cgImage = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: cfg
            )
        } catch {
            throw ScreenCaptureError.captureFailed("SCScreenshotManager.captureImage failed: \(error.localizedDescription)")
        }

        return CapturedScreenshot(image: cgImage, target: resolved.resolved)
    }
}
