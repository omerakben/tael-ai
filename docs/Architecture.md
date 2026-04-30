# TAEL macOS agent architecture

This document tracks the *current* architecture, not the eventual one.
The eventual architecture is described in
[`TAEL_AI_mac_agent_build_plan_v0_3.md`](../TAEL_AI_mac_agent_build_plan_v0_3.md)
sections 8 and 13.

## What exists today

```text
TAELMacAgent (menubar app, native macOS)
├── App
│   ├── TAELMacAgentApp.swift      SwiftUI App entry
│   ├── AppDelegate.swift          Menubar lifecycle and dependency wiring
│   ├── HotkeyInvocationHandler.swift
│   │                              gate → capture → focused-window metadata → HUD + log
│   └── MenuBarController.swift    Menubar menu (Show HUD, Quit)
├── Hotkey
│   ├── HotkeyManager.swift        KeyboardShortcuts-backed global hotkey
│   └── HotkeyName.swift           Command-Shift-T binding name
├── Permissions
│   ├── PermissionKind.swift       Enum: screenRecording, accessibility,
│   │                              microphone, appleEvents, inputMonitoring
│   ├── PermissionStatus.swift     Enum: notDetermined, denied, granted,
│   │                              restricted
│   ├── PermissionError.swift      Errors thrown by PermissionsGate
│   ├── PermissionsChecker.swift   Reads current OS permission state for
│   │                              Screen Recording and Accessibility.
│   └── PermissionsGate.swift      The architectural boundary. Every
│                                  protected call goes through here.
│                                  Also defines `PermissionGrant` so
│                                  its initializer is `fileprivate` to
│                                  this single file.
├── HUD
│   ├── HUDPanelController.swift   Non-activating NSPanel host.
│   ├── HUDView.swift              SwiftUI placeholder content.
│   ├── HUDScreenshotView.swift    Screenshot rendering.
│   ├── HUDContextBundleView.swift Screenshot plus focused-window metadata.
│   ├── HUDErrorView.swift         Capture failure surface.
│   └── PermissionGateView.swift   "Open System Settings" sheet.
├── Capture
│   ├── ScreenshotTarget.swift     displayContainingCursor / mainDisplay
│   ├── CapturedScreenshot.swift   Screenshot value type + metadata
│   ├── ScreenCaptureService.swift ScreenCaptureKit screenshot service.
│   ├── FocusedWindowMetadata.swift
│   ├── ContextBundle.swift        Per-invocation screenshot + AX metadata.
│   └── AXService.swift            Focused-window metadata through AX APIs.
├── Logging
│   ├── InvocationLog.swift        Value type: hotkey ts, gate result,
│   │                              capture timing, target metadata.
│   └── LocalLogService.swift      Local-only logger. Does not touch disk
│                                  in the alpha track; in-memory ring buffer.
└── Resources
    └── Assets.xcassets            App icon placeholder.
```

## The architectural rule

> **No protected macOS API call may bypass `PermissionsGate`.**

See [`ProtectedAPICallPolicy.md`](ProtectedAPICallPolicy.md).

The mechanism is a **tokenized closure boundary**:

```swift
let image = try await permissionsGate.withPermission(.screenRecording) { grant in
    try await screenCaptureService.captureDisplayScreenshot(grant)
}
```

`PermissionGrant` is declared in the same file as `PermissionsGate`,
so its `fileprivate init` is callable only from inside that one file.
Only `PermissionsGate.withPermission` can mint one. Protected services
accept the grant and assert their expected kind via `precondition`.
This makes the boundary **a code-review-visible, type-system-visible
boundary**, not a polite convention.

## Invocation flow

```text
global hotkey                                                (HotkeyManager)
  → PermissionsGate.withPermission(.screenRecording) { grant in
      → SCScreenshotManager.captureImage(contentFilter:configuration:)
        (display containing cursor, fallback to main display)
                                                           (ScreenCaptureService)
    }
  → PermissionsGate.withPermission(.accessibility, showMissingUI: false) { grant in
      → read frontmost app and focused-window title / role       (AXService)
    }
  → HUDPanelController shows non-activating NSPanel              (HUD)
  → InvocationLog written locally                               (Logging)
```

Accessibility metadata is optional. Missing or revoked Accessibility permission
must not break the screenshot heartbeat or show a second permission gate during
the hotkey flow.

## Folder layout reference

The current layout is still a subset of the section-13 "Recommended initial
structure" in v0.3. Folders that have no implementation yet (`Voice/`,
`Planner/`, `Skills/`, `Executor/`, `Settings/`) are not created here. They
will be added in their own milestones.

## Third-party packages

Active:

| Package | Purpose | Ticket |
|---|---|---|
| `sindresorhus/KeyboardShortcuts` | global hotkey | Week 1 ticket 6 |

Planned, not yet added:

| Package | Purpose | Milestone |
|---|---|---|
| `argmaxinc/WhisperKit` | local STT, isolated behind `TranscriptionService` | Week 3 |

## Concurrency model

- `PermissionsGate.withPermission` is `async throws`. All protected
  service calls are `async`.
- AppKit / NSPanel work happens on `MainActor`.
- Capture and gate checks may run on background actors but always hop to
  `MainActor` for UI presentation.

## Logging

`LocalLogService` keeps an in-memory ring buffer of `InvocationLog` rows.
The app does **not** persist screenshots, AX metadata, audio, transcripts, or
invocation logs to disk in the current alpha track. Disk persistence with size
cap and rotation lands only when the executor milestone needs it.

## Test layout

- `TAELMacAgentTests/PermissionsGateTests.swift` verifies the tokenized gate.
- `TAELMacAgentTests/HotkeyHandlerTests.swift` verifies screenshot success,
  capture failure, missing permissions, and optional AX metadata degradation.
- `TAELMacAgentTests/ContextBundleTests.swift` verifies context value behavior.
