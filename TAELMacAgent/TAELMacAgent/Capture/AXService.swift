//
//  AXService.swift
//  TAELMacAgent
//
//  Reads frontmost/focused-window metadata through Accessibility APIs.
//  The service is read-only and requires a .accessibility PermissionGrant.
//

import AppKit
import Foundation
#if canImport(ApplicationServices)
import ApplicationServices
#endif

public protocol FocusedWindowReading: Sendable {
    @MainActor
    func captureFocusedWindowMetadata(_ grant: PermissionGrant) async throws -> FocusedWindowMetadata
}

@MainActor
public final class AXService: FocusedWindowReading {
    public init() {}

    public func captureFocusedWindowMetadata(_ grant: PermissionGrant) async throws -> FocusedWindowMetadata {
        precondition(
            grant.kind == .accessibility,
            "AXService requires a .accessibility grant"
        )

        let app = NSWorkspace.shared.frontmostApplication
        let bundleIdentifier = app?.bundleIdentifier
        let applicationName = app?.localizedName
        let capturedAt = Date()

        guard let app, app.processIdentifier > 0 else {
            return FocusedWindowMetadata(
                bundleIdentifier: bundleIdentifier,
                applicationName: applicationName,
                windowTitle: nil,
                windowRole: nil,
                capturedAt: capturedAt
            )
        }

        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var focusedWindowRef: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedWindowAttribute as CFString,
            &focusedWindowRef
        )

        guard err == .success, let focusedWindowRef else {
            return FocusedWindowMetadata(
                bundleIdentifier: bundleIdentifier,
                applicationName: applicationName,
                windowTitle: nil,
                windowRole: nil,
                capturedAt: capturedAt
            )
        }

        let focusedWindow = focusedWindowRef as! AXUIElement
        return FocusedWindowMetadata(
            bundleIdentifier: bundleIdentifier,
            applicationName: applicationName,
            windowTitle: copyStringAttribute(focusedWindow, kAXTitleAttribute as CFString),
            windowRole: copyStringAttribute(focusedWindow, kAXRoleAttribute as CFString),
            capturedAt: capturedAt
        )
    }

    private func copyStringAttribute(_ element: AXUIElement, _ attribute: CFString) -> String? {
        var value: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard err == .success else { return nil }
        return value as? String
    }
}
