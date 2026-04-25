//
//  PermissionGrant.swift
//  TAELMacAgent
//
//  Tokenized capability used by `PermissionsGate` to authorize a
//  protected service call. The initializer is `fileprivate` to the
//  Permissions/ folder by being declared in the same module — only
//  `PermissionsGate.withPermission` mints these. Protected services
//  should accept a `PermissionGrant` and `precondition` on the kind.
//
//  See docs/ProtectedAPICallPolicy.md.
//

import Foundation

public struct PermissionGrant: Sendable, Hashable {
    public let kind: PermissionKind

    /// Internal so only the Permissions/ files can mint a grant.
    /// We use `internal` (the default) rather than `fileprivate`
    /// because `PermissionsGate` lives in a sibling file in the same
    /// folder/module; this keeps the boundary at the module level.
    /// Do not change to `public`.
    internal init(kind: PermissionKind) {
        self.kind = kind
    }
}
