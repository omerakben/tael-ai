import CoreGraphics
import Foundation

struct ScreenshotTarget: Equatable, Sendable {
    enum ResolutionReason: String, Equatable, Sendable {
        case displayContainingCursor
        case mainDisplayFallback
    }

    let displayID: CGDirectDisplayID?
    let reason: ResolutionReason
}
