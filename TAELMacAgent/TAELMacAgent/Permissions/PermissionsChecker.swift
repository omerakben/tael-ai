//
//  PermissionsChecker.swift
//  TAELMacAgent
//
//  Reads the OS-reported state for each PermissionKind WITHOUT
//  triggering a prompt. The actual prompt is the user's job (via the
//  permission gate sheet → "Open System Settings" → real grant).
//
//  PR 1: Screen Recording is implemented for real. The other kinds
//  return `.notDetermined` so the gate can still be exercised by tests
//  without making system calls.
//
//  See docs/ProtectedAPICallPolicy.md and docs/PermissionNotes.md.
//

import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

public protocol PermissionChecking: Sendable {
    func status(for kind: PermissionKind) async -> PermissionStatus
}

public final class PermissionsChecker: PermissionChecking {
    public init() {}

    public func status(for kind: PermissionKind) async -> PermissionStatus {
        switch kind {
        case .screenRecording:
            return screenRecordingStatus()
        case .accessibility, .microphone, .appleEvents, .inputMonitoring:
            // Placeholder. Real checks land with their milestones.
            return .notDetermined
        }
    }

    // MARK: - Screen Recording

    private func screenRecordingStatus() -> PermissionStatus {
        #if os(macOS)
        // `CGPreflightScreenCaptureAccess` reads the current state
        // without prompting. We deliberately do NOT call
        // `CGRequestScreenCaptureAccess` here — prompting is the gate
        // UI's job, not the checker's.
        //
        // Apple's preflight returns `false` for BOTH "user denied" AND
        // "never asked." We can't distinguish those two without a
        // prompting call, so the honest mapping is `.notDetermined`.
        // The gate UI surfaces the recovery path either way.
        //
        // Note: in some macOS 14 minor versions, preflight can return
        // `true` even when ScreenCaptureKit later fails. PR 2 may add
        // an `SCShareableContent` sanity probe on top of preflight.
        return CGPreflightScreenCaptureAccess() ? .granted : .notDetermined
        #else
        return .notDetermined
        #endif
    }
}
