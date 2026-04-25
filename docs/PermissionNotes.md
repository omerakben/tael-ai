# Permission notes (developer-facing)

This file accumulates **observed reality** about macOS TCC behavior as
we hit it. It is intentionally not a glossy onboarding doc.

If you hit a TCC weirdness, write it down here.

## Bundle / signing identity

- Bundle ID: `ai.tael.macagent` (do not change without coordinating;
  changing it resets every TCC entry on every dev machine).
- Deployment target: macOS 14.0+.
- Debug signing: Apple Development identity tied to a real Team ID.
  See [`../TODO_FOR_OZZY.md`](../TODO_FOR_OZZY.md).
- Ad-hoc signing ("Sign to Run Locally") is **discouraged** for
  TCC-touching builds. TCC keys grants to bundle id + signing
  requirement, and ad-hoc identities flap, which causes the OS to
  re-prompt or silently drop grants.

## Week 1 active permission: Screen Recording

### Behavior

- macOS shows the prompt the first time the app calls a screen capture
  API. We trigger this intentionally during the first hotkey
  invocation, behind `PermissionsGate`.
- Once the user grants Screen Recording, **the app must be quit and
  relaunched** before the new grant takes effect for ScreenCaptureKit
  in some macOS 14 builds. We surface this in `PermissionGateView`.
- Revoking Screen Recording in System Settings while the app is
  running will cause subsequent capture calls to fail with an
  `SCStreamError`. We treat this as a recoverable state: re-show the
  gate, do not crash.

### Preflight

We use `CGPreflightScreenCaptureAccess()` to read the current
state without triggering the prompt. We use
`CGRequestScreenCaptureAccess()` only when the user explicitly clicks
"Request access" in the gate.

> Note: in some macOS 14 minor versions, `CGPreflightScreenCaptureAccess`
> can return `true` even when ScreenCaptureKit later fails. The gate
> should consider both preflight and an actual `SCShareableContent` probe.
> This is an open item — see ticket 4 in `Week1Heartbeat.md`.

### Reset for development

```bash
./scripts/reset-tcc-dev.sh
```

This wraps `tccutil reset ScreenCapture ai.tael.macagent`. See the
script for what it does and how to dry-run it.

## Future permissions (placeholders only in PR 1)

### Accessibility

- Required for AX tree reads and for `CGEvent` synthesis on Apple
  Silicon under modern macOS.
- Use `AXIsProcessTrustedWithOptions` to check; pass
  `kAXTrustedCheckOptionPrompt` to prompt.
- Quit-and-relaunch behavior: similar to Screen Recording.

### Microphone

- Use `AVCaptureDevice.requestAccess(for: .audio)`.
- The first denial is sticky; recovery requires System Settings.

### Apple Events / Automation

- Per-target. Sending an event to e.g. Terminal prompts a per-app
  grant. There is no global "Apple Events on" toggle.
- We will not request these in PR 1.

### Input Monitoring

- Required if we ever use a low-level `CGEventTap` for global hotkey
  capture. We avoid this in PR 1 by using KeyboardShortcuts (which
  uses Carbon HotKey APIs and does not require Input Monitoring).

## Logs

`LocalLogService` keeps an in-memory ring buffer of `InvocationLog`
rows in PR 1. To inspect after a session, use the menubar "Show recent
invocations" item (planned for PR 2). For now, attach a debugger.

## Things we have not yet observed but expect

- macOS may sometimes need two relaunches to pick up a freshly granted
  Screen Recording entry after `tccutil reset`. Document if seen.
- After Xcode rebuilds with a new signing cert, TCC may treat the app
  as a new identity. This is the main reason we want a stable Team ID
  early.
