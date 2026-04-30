//
//  ContextBundleTests.swift
//  TAELMacAgentTests
//

import CoreGraphics
import XCTest
@testable import TAELMacAgent

final class ContextBundleTests: XCTestCase {
    func test_focusedWindowMetadata_hasAnyDataReflectsOptionalFields() {
        let empty = FocusedWindowMetadata(
            bundleIdentifier: nil,
            applicationName: nil,
            windowTitle: nil,
            windowRole: nil
        )
        XCTAssertFalse(empty.hasAnyData)

        let populated = FocusedWindowMetadata(
            bundleIdentifier: "com.example.App",
            applicationName: nil,
            windowTitle: nil,
            windowRole: nil
        )
        XCTAssertTrue(populated.hasAnyData)
    }

    func test_contextBundle_logTargetDescriptionCombinesScreenshotAndFocusedWindow() throws {
        let screenshot = makeStubScreenshot()
        let window = FocusedWindowMetadata(
            bundleIdentifier: "com.example.Terminal",
            applicationName: "Terminal",
            windowTitle: "tael-ai",
            windowRole: "AXWindow"
        )

        let bundle = ContextBundle(screenshot: screenshot, focusedWindow: window)

        let description = try XCTUnwrap(bundle.logTargetDescription)
        XCTAssertTrue(description.contains("displayContainingCursor 1x1"))
        XCTAssertTrue(description.contains("Terminal: tael-ai"))
    }

    private func makeStubScreenshot() -> CapturedScreenshot {
        let cs = CGColorSpaceCreateDeviceRGB()
        let ctx = CGContext(
            data: nil,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: cs,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        let image = ctx.makeImage()!
        return CapturedScreenshot(image: image, target: .displayContainingCursor)
    }
}
