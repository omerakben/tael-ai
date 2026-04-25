//
//  PermissionsGate.swift
//  TAELMacAgent
//
//  Architectural boundary. Every TCC-protected operation in the app
//  must execute inside `withPermission`. The closure parameter is the
//  ONLY way to obtain a `PermissionGrant`, so protected services are
//  type-system-prevented from being called outside the gate.
//
//  `PermissionGrant` lives in this same file on purpose — its
//  initializer is `fileprivate`, so the gate is the ONLY thing that
//  can mint a grant token. Moving the type out of this file would
//  weaken the boundary to module level.
//
//  See docs/ProtectedAPICallPolicy.md.
//

import Foundation

// MARK: - PermissionGrant (tokenized capability)

/// Tokenized capability used by `PermissionsGate` to authorize a
/// protected service call. The initializer is `fileprivate` so only
/// `PermissionsGate.withPermission` (in this file) can mint one.
/// Protected services should accept a `PermissionGrant` and
/// `precondition` on the kind they expect.
public struct PermissionGrant: Sendable, Hashable {
    public let kind: PermissionKind

    fileprivate init(kind: PermissionKind) {
        self.kind = kind
    }
}

// MARK: - Permission gate UI

/// Minimal hook the gate uses to surface a permission sheet to the
/// user. The HUD layer provides the real implementation; tests inject
/// a stub.
///
/// The method is `async` (no actor isolation in the protocol itself)
/// so non-UI conformers (`NoopPermissionGateUI`, test spies) don't
/// need to hop. UI conformers (e.g. `HUDPanelController`) hop to
/// `@MainActor` explicitly inside the implementation.
public protocol PermissionGateUI: Sendable {
    func showGate(for kind: PermissionKind) async
}

/// No-op UI used when the gate runs in a non-UI context (tests, CLI).
public struct NoopPermissionGateUI: PermissionGateUI {
    public init() {}
    public func showGate(for kind: PermissionKind) async {}
}

// MARK: - PermissionsGate

public final class PermissionsGate: Sendable {
    private let checker: PermissionsCheckerProtocol
    private let permissionUI: PermissionGateUI

    public init(
        checker: PermissionsCheckerProtocol = PermissionsChecker(),
        permissionUI: PermissionGateUI = NoopPermissionGateUI()
    ) {
        self.checker = checker
        self.permissionUI = permissionUI
    }

    /// Run `operation` only if the OS reports `.granted` for `kind`.
    /// On any other status, show the permission gate UI and throw
    /// `PermissionError.missing(kind)`.
    ///
    /// The closure receives a `PermissionGrant` whose `kind` matches
    /// the requested kind. Protected services should `precondition`
    /// on the kind they expect.
    ///
    /// `operation` is non-escaping: it is awaited inline and never
    /// stored. Callers can therefore mutate captured locals freely.
    @discardableResult
    public func withPermission<T>(
        _ kind: PermissionKind,
        operation: (PermissionGrant) async throws -> T
    ) async throws -> T {
        let status = await checker.status(for: kind)

        guard status == .granted else {
            await permissionUI.showGate(for: kind)
            throw PermissionError.missing(kind)
        }

        return try await operation(PermissionGrant(kind: kind))
    }
}
