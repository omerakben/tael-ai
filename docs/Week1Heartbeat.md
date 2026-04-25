# Week 1 heartbeat

The Week 1 heartbeat is the **only thing** Week 1 has to prove.

```
global hotkey
  → PermissionsGate
  → SCScreenshotManager.captureImage(contentFilter:configuration:)
  → non-activating NSPanel HUD with screenshot PNG
```

Source: `TAEL_AI_mac_agent_build_plan_v0_3.md` §1, §12.2, §23.3, §23.4.

## Definition of done

> Press hotkey while Terminal is focused.
> HUD appears without switching app focus unnecessarily.
> If Screen Recording is missing, permission gate appears.
> If Screen Recording is granted, screenshot appears.
> Screenshot is **not** persisted to disk.
> Invocation timing is logged locally.
> App does not crash if permission is denied.
> App does not crash in full-screen mode.
> App can be quit cleanly from menubar.

If these hold, Week 1 is done. Anything beyond is a different week.

## Week 1 ticket order

This is the v0.3 §23.5 "First 13 implementation tickets" list, plus a
binding on which PR ships each ticket.

| # | Title | Acceptance | PR |
|---:|---|---|---|
| 0 | Lock bundle ID, macOS 14.0+ target, signing team, and debug signing identity | App has stable identity before any TCC-protected work | PR 1 (signing team is owner-side, see TODO_FOR_OZZY) |
| 1 | Create native macOS menubar shell | App launches as menubar utility and can quit from menu | PR 1 |
| 2 | Add `ProtectedAPICallPolicy.md` | Documents screen, AX, mic, Apple Events, subprocess, clipboard policies | PR 1 |
| 3 | Add `PermissionKind` and `PermissionStatus` | Types exist before protected services. Accessibility and Microphone can be placeholders | PR 1 |
| 4 | Implement `PermissionsChecker` v0 for Screen Recording only | Can report Screen Recording status using the macOS ScreenCapture preflight path | PR 1 (skeleton); PR 2 (real check) |
| 5 | Implement `PermissionsGate` v0 | Protected operation cannot run without passing through tokenized gate. Missing permission shows placeholder gate and retry path | PR 1 |
| 6 | Add KeyboardShortcuts package | Temporary hotkey or user-configurable shortcut triggers a callback | PR 2 |
| 7 | Add `HUDPanelController` placeholder | Shows a non-activating `NSPanel` with placeholder content and does not steal focus | PR 1 |
| 8 | Add `ScreenCaptureService` | Captures display-containing-cursor screenshot using `SCShareableContent`, `SCContentFilter`, `SCStreamConfiguration`, and `SCScreenshotManager.captureImage(contentFilter:configuration:)` | PR 2 (PR 1 has typed stub only) |
| 9 | Wire hotkey → screen gate → screenshot capture | Missing permission shows gate state instead of crashing. Granted permission captures screenshot | PR 2 |
| 10 | Render screenshot in HUD | Screenshot appears in panel and is not persisted to disk | PR 2 |
| 11 | Add local invocation log | Logs hotkey timestamp, permission status, screenshot timing, target display metadata, and error state | PR 1 (skeleton); PR 2 (wired) |
| 12 | Add manual test checklist | Terminal, VS Code/Cursor, full-screen, denied permission, revoked permission, display-containing-cursor, no-persistence check | PR 1 |

## Why a tokenized `PermissionGrant`?

`PermissionsGate` is an **architectural boundary**, not a convenience
helper. The grant token enforces it at the type system level: a
protected service cannot be called without a `PermissionGrant`, and a
`PermissionGrant` can only be minted inside `PermissionsGate.withPermission`.
The shape:

```swift
struct PermissionGrant {
    let kind: PermissionKind

    fileprivate init(kind: PermissionKind) {
        self.kind = kind
    }
}

final class PermissionsGate {
    func withPermission<T>(
        _ kind: PermissionKind,
        operation: @escaping (PermissionGrant) async throws -> T
    ) async throws -> T {
        let status = await checker.status(for: kind)

        guard status == .granted else {
            await permissionUI.showGate(for: kind)
            throw PermissionError.missing(kind)
        }

        return try await operation(PermissionGrant(kind: kind))
    }
}
```

Protected services require the grant:

```swift
final class ScreenCaptureService {
    func captureDisplayScreenshot(_ grant: PermissionGrant) async throws -> CGImage {
        precondition(grant.kind == .screenRecording)
        // Week 1 implementation later.
    }
}
```

## Screenshot target (Week 1)

> **Display containing cursor, with fallback to main display.**

Do not call this "focused-window capture" — focused-window context is
AX work and starts in Week 2.

The capture path **must** use:

```
SCScreenshotManager.captureImage(contentFilter:configuration:)
```

Do **not** use `SCScreenshotManager.captureImage(in:)`. Reason: that
overload is macOS 15.2+, and our deployment target is macOS 14.0+.

## What Week 1 explicitly excludes

```
No AI planner.
No speech capture.
No WhisperKit.
No AX tree.
No executor.
No skills.
No YAML.
No dashboard.
No polished onboarding.
No product naming.
```

## GitHub issues

If Ozzy wants one issue per ticket, ask Claude/Codex on the next run
to mirror the table above into the GitHub Issues tab using the
`implementation_ticket.md` template. This run did not auto-open issues.
