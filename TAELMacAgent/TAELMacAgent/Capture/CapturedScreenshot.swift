import CoreGraphics
import Foundation

struct CapturedScreenshot {
    let image: CGImage
    let target: ScreenshotTarget
    let capturedAt: Date
}
