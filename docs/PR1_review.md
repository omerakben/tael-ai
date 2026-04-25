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

---

## Addendum: pr-review-toolkit pass (2026-04-25)

Five specialized agents (`type-design-analyzer`, `silent-failure-hunter`, `comment-analyzer`, `pr-test-analyzer`, `code-reviewer`) audited PR #14 after the bot reviews and the initial maestro pass. Each was briefed to skip what Gemini and Copilot already flagged and hunt for new issues.

### Correction to the original review

The original review section above said the cleanup PR would need to fix the `internal init` vs `fileprivate init` boundary on `PermissionGrant`. **That is already done** on dev-claude HEAD. Commit `d592c18` removed `Permissions/PermissionGrant.swift` as a separate file and inlined the type into `PermissionsGate.swift` with `fileprivate init`. The boundary is now genuinely file-scoped — stronger than module-scoped — and is non-bypassable except by adding code to `PermissionsGate.swift` itself. Don't ask Codex to "split for clarity" or any similar refactor.

### Critical findings beyond bot coverage

**C1 — `scripts/reset-tcc-dev.sh:71`, `set -e` interaction with `output=$(...)`.** With `set -euo pipefail`, the script aborts on the FIRST `tccutil` non-zero exit. The benign-vs-real distinguishing logic on lines 73-87 is dead code; the `Done.` on line 97 never prints. Fix:

```bash
if ! output=$("${cmd[@]}" 2>&1); then
    rc=$?
    # ... distinguishing logic
fi
```

**C2 — `PermissionGateView.swift:33-35`, Cancel button is a no-op.** `NSApp.keyWindow?.close()` rarely matches the gate's `.nonactivatingPanel` (`becomesKeyOnlyIfNeeded = true`). Even when it does, calling `close()` leaves `HUDPanelController.panel` referencing a closed instance, breaking `tearDown()`. Replace with a callback to `HUDPanelController.tearDown()` (or an injected `onCancel` action).

### Important findings beyond bot coverage

| # | File:line | Finding |
|---|---|---|
| I1 | `PermissionsGate.swift:27` | `PermissionGrant: Hashable` invites a `Set<PermissionGrant>` caching anti-pattern that the policy doc explicitly bans. Drop to `Equatable`. |
| I2 | `LocalLogService.swift:21-26` | Ring-buffer overflow drops entries silently (no counter, no `os_log`). Add `droppedCount` and emit `os_log(.fault)` on first drop per session. |
| I3 | `PermissionsChecker.swift:32-35` | Placeholder kinds return `.notDetermined`, causing the gate to show "user must grant Microphone" UI for kinds with no real check. Throw `PermissionError.notImplemented(kind)` instead — the case already exists in `PermissionError` and is currently unreachable. |
| I4 | `HUDPanelController.swift:59-77` | Panel style mask is `[.titled, .closable, .nonactivatingPanel, .utilityWindow, .hudWindow]` — v0.3 §23.11 mandates `[.nonactivatingPanel, .borderless]`. Either bring back to spec or add a comment justifying the deviation. |
| I5 | `LocalLogService` (overall) | Instantiated in `AppDelegate` but `record(_:)` never called. Ticket 11 ("Add local invocation log") is in the §23.5 first-13 scope. |
| I6 | `docs/ProtectedAPICallPolicy.md:38-50, 78-85` and `docs/Week1Heartbeat.md:67-92` | Code snippets still show the pre-fix `@escaping` closure and `CGImage` return type. Drift from gemini-review fix in commit `0219024`. |
| I7 | `PermissionsGate.swift:80-92` | `await permissionUI.showGate(for: kind)` has no timeout. A buggy UI conformer can hang the hotkey path forever. Wrap in `withTimeout` (~2s) or detach. |

### Type-design verdict on `PermissionGrant`: sound

The type-design-analyzer evaluated the *current* implementation (post-`d592c18`) and confirmed:

- File-scoped `fileprivate init` is genuinely non-bypassable — `@testable import` cannot reach `fileprivate` symbols, and only code added to `PermissionsGate.swift` itself can mint a grant.
- `precondition(grant.kind == .screenRecording)` in `ScreenCaptureService` is the right failure mode (panic on programmer error).
- The two residual weaknesses are policy-shaped, not type-shaped: `Hashable` invites caching (I1), and the grant has no liveness binding so a future author could stash it past the closure (defer to PR 2 if executor lands first).

### Test coverage verdict: sufficient for PR 1 merge

- Existing 4 tests defend invariants 2 (denied → throws + UI), 3 (granted → runs + grant kind), 5 (operation errors propagate), plus the `.notDetermined` sub-case.
- Invariant 1 (non-bypassability) is enforced by Swift's `fileprivate` access modifier; the test-file comment documents the intent.
- Invariant 4 (precondition crash on wrong-kind grant) is untested but Swift's `precondition` is hard to test without first-party `XCTAssertCrash`. Defer to PR 2 when ScreenCaptureKit replaces the stub.

### Cleanup PR scope (revised from 4 items to 11)

1. Rename `PermissionsCheckerProtocol` → `PermissionChecking`
2. Rename `PermissionGateUI` → `PermissionGatePresenting`
3. `PermissionsChecker` returns `.notDetermined` (not `.denied`) when preflight is false
4. Reject Codex's `PermissionKind` enum expansion (clipboard/subprocess aren't TCC permissions)
5. **C1**: Fix `reset-tcc-dev.sh` `set -e` interaction with command-substitution assignment
6. **C2**: Wire `PermissionGateView` Cancel button to `HUDPanelController.tearDown()`
7. **I1**: Drop `PermissionGrant: Hashable` → `Equatable`
8. **I2**: `LocalLogService` overflow signal (`droppedCount` field + `os_log(.fault)`)
9. **I3**: Throw `PermissionError.notImplemented(kind)` for unimplemented kinds
10. **I4**: Panel style mask back to v0.3 §23.11 OR add justification comment
11. **I6**: Sync `ProtectedAPICallPolicy.md` and `Week1Heartbeat.md` code snippets to current closure shape

Items I5 and I7 can also be in this cleanup PR; I7 is small enough (`withTimeout` wrapper) and I5 is just wiring the existing `LocalLogService` into the placeholder hotkey path.

### Strengths to preserve (don't ask Codex to "improve" these)

- File-scoped tokenized boundary on `PermissionGrant` (don't split the file)
- `PermissionsChecker.screenRecordingStatus` uses preflight (not request) — correct per no-silent-prompt rule
- `ScreenCaptureService.precondition` on grant kind — correct failure mode
- `HUDPanelController` deliberately doesn't call `NSApp.activate` — preserves focus
- `LocalLogService` as `actor` with bounded buffer and `precondition(capacity > 0)` — minimal, correct
- `PermissionKind.displayName` co-located with cases (no separate localization table to drift)
- `@unchecked Sendable` on `CapturedScreenshot` is honestly justified (CGImage thread-safety) — keep
- `[weak hudController]` capture in AppDelegate menu callback — correct, no retain cycle

### v0.3 plan compliance

- §23.1 deployment target / capture API: **pass**
- §23.2 bundle id / signing: **pass on bundle**, signing deferred to Ozzy via `TODO_FOR_OZZY.md` (acceptable but worth surfacing in PR description)
- §23.3 PR-1 scope boundary: **pass**
- §13 repo layout: **matches**
- §6 rules: pass with one minor note — `PermissionsChecker.screenRecordingStatus` calls `CGPreflightScreenCaptureAccess` directly (not through the gate), which is correct because preflight isn't a "protected API call" in the TCC sense (no prompt, no protected data). Worth a one-line comment so future reviewers don't pattern-match on it.

### Final verdict

**GO for merge to develop.** The shipped surface is structurally sound, the critical issues are cleanup-PR-scope (not block-the-merge scope), the test coverage is sufficient for what PR 1 actually delivers, and the file-scoped tokenized boundary works as claimed.
