# PR 1 review and integration decision

**Date:** 2026-04-25
**Reviewer:** Claude Opus 4.7 (maestro role under the workflow agreed 2026-04-25)
**Decision authority:** Ozzy

## Context

Two parallel agent branches each opened a "scaffold native macOS menubar prototype" PR for the v0.3 PR 1 surface:

- **PR #14** — `dev-claude` (authored by a prior Claude Code session)
- **PR #15** — `dev-codex` (authored by a prior Codex CLI session)

Both target the same v0.3 §23 amendments (bundle id `ai.tael.macagent`, macOS 14.0+, `PermissionsGate` as tokenized boundary, Screen Recording as the only Week 1 protected check). The work overlaps but diverges on real architectural choices — exactly the case the maestro/delegate workflow exists to adjudicate.

## Decision

**Land PR #14 (`dev-claude`) into `develop` as the PR 1 base.** Follow with a small cleanup PR that ports four targeted improvements from PR #15 (`dev-codex`).

PR #15 is superseded by this plan but remains open for Ozzy to close.

## Why dev-claude wins as the base

| Dimension | dev-claude | dev-codex | Winner | Reasoning |
|---|---|---|---|---|
| Files / additions | 41 / 2925 | 34 / 1645 | claude | More complete |
| Build tooling | `Makefile`, `project.yml` (XcodeGen), `Info.plist`, `.entitlements`, asset catalogs | `.pbxproj` only | **claude** | Repeatable Xcode regen via `make xcodeproj`; matters when `.pbxproj` drifts |
| Concurrency design | `PermissionsGate: Sendable`, non-escaping closure, `@MainActor` only inside UI conformers | not Sendable, `@escaping` closure, `@MainActor` on protocol method | **claude** | Strict-concurrency-clean; non-escaping closure lets callers mutate captured locals freely |
| `ScreenCaptureService` contract | returns `CapturedScreenshot` value type, accepts `target: ScreenshotTarget = .week1Default`, defines `noDisplaysAvailable` and `captureFailed(String)` errors, includes PR-2 implementation outline as comment | returns raw `CGImage`, no target param, single error case | **claude** | Ships PR 2's contract in PR 1; PR 2 won't have to invent these types |
| Inline architectural docs | header comment on `PermissionsGate.swift` explains *why* `PermissionGrant` lives in same file (`fileprivate` boundary requires it) | docs/ folder only | **claude** | Non-obvious invariant flagged at site of enforcement |
| Test coverage | 4 (`granted`, `denied`, `notDetermined`, error propagation) | 2 | **claude** | More cases |
| External reviews | Gemini + Copilot reviewed; concurrency feedback addressed | CodeRabbit ran (rate-limited mid-review) | **claude** | More eyes on same surface |

## What dev-codex got right (cleanup PR follows up)

These are the four items to port from PR #15 onto `develop` after the integration lands:

1. **Rename `PermissionsCheckerProtocol` → `PermissionChecking`**
   Apple Swift convention: behavioral protocols use `-ing` suffix (`Hashable`, `Encodable`). The `Protocol` suffix is a Java holdover.

2. **Rename `PermissionGateUI` → `PermissionGatePresenting`**
   Same convention. `UI` is a layer name; `Presenting` is a behavior.

3. **`PermissionsChecker` returns `.notDetermined` (not `.denied`) when `CGPreflightScreenCaptureAccess()` returns `false`**
   Apple's preflight returns false for *both* "user denied" *and* "never asked." Calling that state `.denied` collapses two distinct user states; `.notDetermined` is more honest. This is a real semantic improvement, not just a style choice.

4. **Reject Codex's `PermissionKind` expansion**
   PR #15 added `.clipboardWrite`, `.subprocessAction`, `.keyboardMouseAutomation` to the enum. Clipboard writes and subprocess execution are not TCC-gated on macOS — they don't belong in a *permission* enum. Keep dev-claude's discipline of one kind per real TCC permission.

The first three are mechanical; item 4 is "don't accept the Codex change." The cleanup PR will be small (rename + one-liner semantic fix + nothing).

## Open items dev-claude flagged for PR 2 (not for this integration)

- KeyboardShortcuts package install (ticket 6)
- Real `SCShareableContent` / `SCContentFilter` / `SCStreamConfiguration` / `SCScreenshotManager.captureImage(contentFilter:configuration:)` capture (ticket 8)
- Hotkey → screen gate → screenshot wire-up (ticket 9)
- HUD render of captured screenshot (ticket 10)
- Disk-persisted invocation log (after executor lands)

## Open item Ozzy owns

`DEVELOPMENT_TEAM` is intentionally blank in the project until Ozzy sets the Apple Developer Team ID locally. This blocks signed builds but not `CODE_SIGNING_ALLOWED=NO build/test`. See `TODO_FOR_OZZY.md` (ships with the dev-claude integration).

## Process notes for future review docs

- Reviewer was the maestro (Opus 4.7), not an author of either PR. Per the model-bias rule, no agent should review their own work.
- Ozzy is the final arbiter; this doc records the recommendation but does not bypass approval.
- Future first-PR-style integrations should follow the same pattern: maestro reviews, recommends, Ozzy approves, cleanup PR follows.
