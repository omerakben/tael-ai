# Protected API call policy

This is an **architectural rule**, not a guideline.

> No ScreenCaptureKit call, AX read, microphone access, Apple Events
> call, keyboard/mouse event synthesis, subprocess action, or clipboard
> write may bypass the appropriate policy/gate.

## What is a "protected API call"?

| Surface | Examples | TCC permission | Status in PR 1 |
|---|---|---|---|
| Screen capture | `SCScreenshotManager`, `CGDisplayStream`, `CGWindowListCreateImage` | Screen Recording | **Active** — gated through `PermissionsGate` with `.screenRecording`. |
| Accessibility tree | `AXUIElement*`, `AXObserver*` | Accessibility | Future. Enum placeholder only; no real check yet. |
| Microphone | `AVAudioEngine`, `AVCaptureDevice` (audio) | Microphone | Future. Enum placeholder only. |
| Apple Events / scripting | `NSAppleScript`, `OSAScript`, `appleScriptObjectSpecifier` | Apple Events / Automation | Future. Enum placeholder only. |
| Keyboard/mouse synthesis | `CGEvent.post`, `CGEventTapCreate` | Input Monitoring / Accessibility | Future. Enum placeholder only. |
| Subprocess execution | `Process()`, `posix_spawn`, `system()` | n/a (but treated as protected by `SafetyPolicy`) | Future. Not in PR 1. Will go through `SafeExecutor`. |
| Clipboard write | `NSPasteboard.general.set*` | n/a (but treated as protected by `SafetyPolicy`) | Future. Not in PR 1. Will go through `ClipboardExecutor`. |

For PR 1, only Screen Recording is active. The rest are future policy
entries — their enum cases exist (so the gate has a complete vocabulary)
but `PermissionsChecker` does not query them, and no service consumes
their grants yet.

## How the gate works

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
        operation: (PermissionGrant) async throws -> T
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

Two properties:

1. **Tokenized boundary.** `PermissionGrant` is declared in the same
   file as `PermissionsGate` (`PermissionsGate.swift`) with a
   `fileprivate init`. Swift's `fileprivate` is scoped to a single
   file, so only code inside `PermissionsGate.swift` can construct a
   grant. A protected service is therefore *unable* to be called
   without going through the gate, because the closure body
   `PermissionsGate.withPermission` runs is the only place a grant
   exists.
2. **Single source of permission UI.** Missing permission always shows
   the same `PermissionGateView`. There is no per-feature ad-hoc
   "did you grant…" sheet.

## Required usage pattern

```swift
let image = try await permissionsGate.withPermission(.screenRecording) { grant in
    try await screenCaptureService.captureDisplayScreenshot(grant)
}
```

Protected services accept the grant and assert their expected kind:

```swift
final class ScreenCaptureService {
    func captureDisplayScreenshot(_ grant: PermissionGrant) async throws -> CapturedScreenshot {
        precondition(grant.kind == .screenRecording)
        // ScreenCaptureKit call here.
    }
}
```

## Forbidden patterns

The following are **review-blocking**:

- Calling any API from the table above without a `PermissionGrant` in
  scope.
- Adding a "convenience" overload on a protected service that does not
  take a `PermissionGrant`.
- Catching `PermissionError.missing` and silently retrying without going
  back through the gate.
- Caching a `PermissionGrant` outside the closure that received it.
- Making `PermissionGrant.init` anything other than `fileprivate`,
  or moving `PermissionGrant` out of `PermissionsGate.swift`.
- Adding a per-feature permission sheet instead of routing through
  `PermissionGateView`.

## Adding a new protected surface

When a new TCC-protected API is added in a future PR:

1. Add a case to `PermissionKind`.
2. Implement a `PermissionsChecker` branch that queries real OS state.
3. Update this table with status `Active`.
4. Update the new service to take `PermissionGrant` and `precondition`
   on the kind.
5. Update `PermissionGateView` to render an explanation for the new
   kind.
6. Add a test in `PermissionsGateTests` that covers the new kind in
   both `granted` and `denied` paths.
