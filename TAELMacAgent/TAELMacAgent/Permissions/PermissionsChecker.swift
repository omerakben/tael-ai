import CoreGraphics
import Foundation

final class PermissionsChecker: PermissionChecking {
    func status(for kind: PermissionKind) async -> PermissionStatus {
        switch kind {
        case .screenRecording:
            return CGPreflightScreenCaptureAccess() ? .granted : .notDetermined
        case .accessibility,
             .microphone,
             .appleEvents,
             .inputMonitoring,
             .clipboardWrite,
             .subprocessAction,
             .keyboardMouseAutomation:
            return .unsupported
        }
    }
}
