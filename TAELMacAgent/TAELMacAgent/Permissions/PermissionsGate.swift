import Foundation

protocol PermissionChecking: AnyObject {
    func status(for kind: PermissionKind) async -> PermissionStatus
}

protocol PermissionGatePresenting: AnyObject {
    @MainActor func showGate(for kind: PermissionKind) async
}

final class NoopPermissionGatePresenter: PermissionGatePresenting {
    @MainActor func showGate(for kind: PermissionKind) async {}
}

struct PermissionGrant: Sendable {
    let kind: PermissionKind

    fileprivate init(kind: PermissionKind) {
        self.kind = kind
    }
}

final class PermissionsGate {
    private let checker: PermissionChecking
    private let permissionUI: any PermissionGatePresenting

    init(
        checker: PermissionChecking = PermissionsChecker(),
        permissionUI: any PermissionGatePresenting = NoopPermissionGatePresenter()
    ) {
        self.checker = checker
        self.permissionUI = permissionUI
    }

    func withPermission<T>(
        _ kind: PermissionKind,
        operation: @escaping (PermissionGrant) async throws -> T
    ) async throws -> T {
        let status = await checker.status(for: kind)

        guard status == .granted else {
            await permissionUI.showGate(for: kind)
            throw PermissionError.missing(kind)
        }

        return try await operation(PermissionGrant(kind: kind))
    }
}
