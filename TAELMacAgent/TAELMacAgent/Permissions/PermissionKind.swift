//
//  PermissionKind.swift
//  TAELMacAgent
//
//  The full vocabulary of TCC-protected surfaces the agent will ever
//  touch. PR 1 only implements `.screenRecording` for real; the rest
//  are placeholders so the gate has a complete enum to switch on as
//  future milestones land.
//
//  See docs/ProtectedAPICallPolicy.md.
//

import Foundation

public enum PermissionKind: String, CaseIterable, Sendable, Hashable {
    case screenRecording
    case accessibility
    case microphone
    case appleEvents
    case inputMonitoring

    /// Whether `PermissionsChecker` performs a real OS query for this
    /// kind in the current build. PR 1: only screen recording is real.
    public var isImplemented: Bool {
        switch self {
        case .screenRecording: return true
        case .accessibility, .microphone, .appleEvents, .inputMonitoring:
            return false
        }
    }

    public var displayName: String {
        switch self {
        case .screenRecording: return "Screen Recording"
        case .accessibility:   return "Accessibility"
        case .microphone:      return "Microphone"
        case .appleEvents:     return "Automation (Apple Events)"
        case .inputMonitoring: return "Input Monitoring"
        }
    }
}
