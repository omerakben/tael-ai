# Architecture

## Current scope

This repository currently contains the PR 1 foundation for the native TAEL AI mac agent.

The app shape is a native macOS menubar utility:

- Swift app lifecycle
- SwiftUI views
- AppKit menubar controller
- AppKit `NSPanel` HUD placeholder
- permission boundary types for future protected work

## Week 1 heartbeat

The Week 1 heartbeat is:

```text
global hotkey -> PermissionsGate -> SCScreenshotManager.captureImage(contentFilter:configuration:) -> non-activating NSPanel HUD with screenshot PNG
```

PR 1 does not implement that full heartbeat. It creates the shell and policy structure needed to implement it safely next.

## Protected boundary

Protected services must require a `PermissionGrant`. The grant can only be issued by `PermissionsGate`.

```swift
let image = try await permissionsGate.withPermission(.screenRecording) { grant in
    try await screenCaptureService.captureDisplayScreenshot(grant)
}
```

`ScreenCaptureService` has no public screenshot method that can run without a grant.

## Week 1 screenshot target

The Week 1 screenshot target will be the display containing the cursor, with fallback to the main display.

It must use:

```text
SCScreenshotManager.captureImage(contentFilter:configuration:)
```

It must not use `captureImage(in:)` while the app targets macOS 14.0+.

## Out of scope for PR 1

- AI planner
- speech capture
- WhisperKit
- AX tree
- focused-window metadata
- YAML skills
- executor paths
- clipboard actions
- shell actions
- AppleScript
- CGEvent automation
- settings UI
- polished onboarding
- DMG packaging
- Sparkle
- analytics
- token tracking
- screenshot persistence
- landing page work
