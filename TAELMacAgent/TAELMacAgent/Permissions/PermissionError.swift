import Foundation

enum PermissionError: Error, Equatable, LocalizedError {
    case missing(PermissionKind)
    case unsupported(PermissionKind)

    var errorDescription: String? {
        switch self {
        case .missing(let kind):
            return "\(kind.displayName) permission is required."
        case .unsupported(let kind):
            return "\(kind.displayName) permission is not implemented yet."
        }
    }
}
