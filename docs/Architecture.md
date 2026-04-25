# TAEL macOS agent — Architecture (PR 1)

This document tracks the *current* architecture, not the eventual one.
The eventual architecture is described in
[`TAEL_AI_mac_agent_build_plan_v0_3.md`](../TAEL_AI_mac_agent_build_plan_v0_3.md)
sections 8 and 13.

## What exists today

```
TAELMacAgent (menubar app, native macOS)
├── App
│   ├── TAELMacAgentApp.swift     SwiftUI App entry
│   ├── AppDelegate.swift          Menubar lifecycle, NSStatusItem
│   └── MenuBarController.swift    Menubar menu (Show HUD, Quit)
├── Hotkey
│   └── HotkeyManager.swift        Stub. Registers a callback. No real
│                                  global hotkey until KeyboardShortcuts
│                                  package is added (PR 2, ticket 6).
├── Permissions
│   ├── PermissionKind.swift       Enum: screenRecording, accessibility,
│   │                              microphone, appleEvents, inputMonitoring
│   ├── PermissionStatus.swift     Enum: notDetermined, denied, granted,
│   │                              restricted
│   ├── PermissionError.swift      Errors thrown by PermissionsGate
│   ├── PermissionsChecker.swift   Reads current OS permission state.
│   │                              v0: Screen Recording only.
│   └── PermissionsGate.swift      The architectural boundary. Every
│                                  protected call goes through here.
│                                  Also defines `PermissionGrant` so
│                                  its initializer is `fileprivate` to
│                                  this single file.
├── HUD
│   ├── HUDPanelController.swift   Non-activating NSPanel host.
│   ├── HUDView.swift              SwiftUI placeholder content.
│   └── PermissionGateView.swift   "Open System Settings" sheet for
│                                  missing permissions.
├── Capture
│   ├── ScreenshotTarget.swift     displayContainingCursor / mainDisplay
│   ├── CapturedScreenshot.swift   Value type wrapping CGImage + metadata
│   └── ScreenCaptureService.swift Stub. Real SCScreenshotManager call
│                                  lands in PR 2, ticket 8. Requires a
│                                  PermissionGrant of kind .screenRecording.
├── Logging
│   ├── InvocationLog.swift        Value type: hotkey ts, gate result,
│   │                              capture timing, target metadata.
│   └── LocalLogService.swift      Local-only logger. Does not touch disk
│                                  in PR 1; in-memory ring buffer.
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

## Week 1 heartbeat (target, not yet wired)

```
global hotkey                                                (HotkeyManager)
  → PermissionsGate.withPermission(.screenRecording) { grant in
      → SCScreenshotManager.captureImage(contentFilter:configuration:)
        (display containing cursor, fallback to main display)
                                                           (ScreenCaptureService)
    }
  → HUDPanelController shows non-activating NSPanel with PNG     (HUD)
  → InvocationLog written locally                               (Logging)
```

## Folder layout reference

The Week 1 layout in this repo is intentionally a strict subset of the
section-13 "Recommended initial structure" in v0.3. Folders that have no
PR 1 implementation (`Voice/`, `Planner/`, `Skills/`, `Executor/`,
`Settings/`) are not created here. They will be added in their own PRs.

## Third-party packages

PR 1: none.

Planned (do not add yet):

| Package | Purpose | Ticket |
|---|---|---|
| `sindresorhus/KeyboardShortcuts` | global hotkey + user-configurable | Week 1 ticket 6 |
| `argmaxinc/WhisperKit` | local STT, isolated behind `TranscriptionService` | Week 3 |

## Concurrency model

- `PermissionsGate.withPermission` is `async throws`. All protected
  service calls are `async`.
- AppKit / NSPanel work happens on `MainActor`.
- Capture and gate checks may run on background actors but always hop to
  `MainActor` for UI presentation.

## Logging

`LocalLogService` keeps an in-memory ring buffer of `InvocationLog` rows
in PR 1. PR 1 does **not** persist logs to disk. Disk persistence (with
size cap and daily rotation) lands when the executor lands.

## Test layout

- `TAELMacAgentTests/PermissionsGateTests.swift` — verifies that
  `withPermission` short-circuits on denied status, that the operation
  is invoked exactly once on granted, and that the closure receives a
  grant of the requested kind.
