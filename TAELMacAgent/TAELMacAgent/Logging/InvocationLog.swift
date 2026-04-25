import Foundation

struct InvocationLog: Sendable {
    enum Source: String, Sendable {
        case menuBar
        case hotkeyPlaceholder
    }

    let id: UUID
    let source: Source
    let occurredAt: Date
    let permissionStatus: PermissionStatus?
    let message: String

    init(
        id: UUID = UUID(),
        source: Source,
        occurredAt: Date,
        permissionStatus: PermissionStatus?,
        message: String
    ) {
        self.id = id
        self.source = source
        self.occurredAt = occurredAt
        self.permissionStatus = permissionStatus
        self.message = message
    }

    var summary: String {
        let status = permissionStatus?.rawValue ?? "notChecked"
        return "invocation id=\(id.uuidString) source=\(source.rawValue) permissionStatus=\(status) message=\(message)"
    }
}
