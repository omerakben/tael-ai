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

    /// Restricted by policy (parental controls, MDM). Surfacing this
    /// distinctly lets us avoid showing a "click here to fix" affordance
    /// the user cannot actually act on.
    case restricted
}
