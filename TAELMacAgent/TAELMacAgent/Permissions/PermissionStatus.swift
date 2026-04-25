//
//  PermissionStatus.swift
//  TAELMacAgent
//

import Foundation

public enum PermissionStatus: String, Sendable, Hashable {
    /// The system has not yet been asked. We have not triggered the
    /// prompt and the user has not made a decision.
    case notDetermined

    /// User explicitly denied or the policy disallows.
    case denied

    /// Granted and currently usable.
    case granted

    /// Restricted by policy (parental controls, MDM). Modeled
    /// distinctly from `.denied` so callers (logging, future gate UI)
    /// can treat policy-based unavailability as non-user-actionable.
    /// Note: PR 1's gate UI receives only `PermissionKind`, not status,
    /// so it cannot yet differentiate `.restricted` from `.denied` in
    /// the presented sheet — that hook lands when status is threaded
    /// through `PermissionGateUI`.
    case restricted
}
