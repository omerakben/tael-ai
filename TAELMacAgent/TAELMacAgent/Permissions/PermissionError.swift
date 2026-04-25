//
//  PermissionError.swift
//  TAELMacAgent
//

import Foundation

public enum PermissionError: Error, Sendable, Equatable {
    /// The gate refused to mint a grant because the OS-reported status
    /// was not `.granted`.
    case missing(PermissionKind)

    /// The kind exists in the enum but has no real implementation in
    /// this build. Throwing keeps the type system honest while we
    /// stage future milestones.
    case notImplemented(PermissionKind)
}

extension PermissionError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .missing(let kind):
            return "TAEL needs \(kind.displayName) permission to continue."
        case .notImplemented(let kind):
            return "\(kind.displayName) is not yet implemented in this build."
        }
    }
}
