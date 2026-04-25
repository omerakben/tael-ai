//
//  InvocationLog.swift
//  TAELMacAgent
//
//  One row per hotkey invocation. Captures enough to debug TCC weirdness
//  and capture latency without needing to attach a debugger.
//

import Foundation

public struct InvocationLog: Sendable, Equatable {
    public enum GateOutcome: String, Sendable, Equatable {
        case granted
        case denied
        case notDetermined
        case restricted
        case errored
    }

    public let id: UUID
    public let hotkeyTimestamp: Date
    public let gateOutcome: GateOutcome
    public let gateLatencyMs: Double?
    public let captureLatencyMs: Double?
    public let targetDescription: String?
    public let errorDescription: String?

    public init(
        id: UUID = UUID(),
        hotkeyTimestamp: Date = Date(),
        gateOutcome: GateOutcome,
        gateLatencyMs: Double? = nil,
        captureLatencyMs: Double? = nil,
        targetDescription: String? = nil,
        errorDescription: String? = nil
    ) {
        self.id = id
        self.hotkeyTimestamp = hotkeyTimestamp
        self.gateOutcome = gateOutcome
        self.gateLatencyMs = gateLatencyMs
        self.captureLatencyMs = captureLatencyMs
        self.targetDescription = targetDescription
        self.errorDescription = errorDescription
    }
}
