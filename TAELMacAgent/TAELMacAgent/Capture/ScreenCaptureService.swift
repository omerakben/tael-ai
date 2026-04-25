import CoreGraphics
import Foundation

enum ScreenCaptureServiceError: Error, Equatable {
    case notImplementedInPR1
}

final class ScreenCaptureService {
    func captureDisplayScreenshot(_ grant: PermissionGrant) async throws -> CGImage {
        precondition(grant.kind == .screenRecording)
        throw ScreenCaptureServiceError.notImplementedInPR1
    }
}
