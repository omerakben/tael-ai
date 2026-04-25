import Foundation

enum PermissionStatus: String, Equatable, Sendable {
    case granted
    case denied
    case notDetermined
    case restricted
    case unsupported
}
