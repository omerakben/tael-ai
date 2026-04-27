# TODO for Ozzy

Items that require owner input before this repo is truly buildable
on a real Mac. Nothing here blocks PR 1, but PR 2 will start to feel
the pain if these are not resolved.

## Signing and identity

- [x] **Set Apple Developer Team ID in Xcode.**
  Set 2026-04-26. Team: OMER FARUK AKBEN, Team ID: 4X8U3NCLQ8.
  Automatic signing enabled, Development certificate.
- [x] **Choose preferred local signing identity.**
  Confirmed 2026-04-26. Apple Development (automatic), paid Apple
  Developer Program (Individual). Signing Certificate: Development.
- [x] **Confirm bundle ID `ai.tael.macagent` is acceptable long-term.**
  Confirmed 2026-04-26. Used as the stable TCC identity.

## Repo and naming

- [x] **Confirm repo name `tael-ai` should remain.**
  Confirmed 2026-04-26. Keeping `tael-ai`.
- [ ] **Confirm GitHub Issues should be created manually or via CLI.**
  Maestro Claude does not have `gh` access and does not auto-open
  Issues from this run. Week 1 ticket checklist lives in
  [`docs/Week1Heartbeat.md`](docs/Week1Heartbeat.md). If you want a
  one-issue-per-ticket layout, tell Claude/Codex on the next run and
  it can be created via the GitHub MCP server.

## Branches

- [ ] **Confirm branch model.** The plan says:
  - `main` — frozen plan + scaffold
  - `dev-claude` — Maestro Claude
  - `dev-codex` — Codex
  
  This run created `dev-claude` from `main` and developed there.
  PR is opened against `main` as a draft per repo policy.

## Build / test status from PR 1

- [x] **Run `xcodebuild` locally.**
  Verified 2026-04-26. Clean build succeeds. All 11 tests pass
  (3 HotkeyHandler, 3 LocalLogService, 5 PermissionsGate).
  App launches as menubar utility. Permission gate HUD confirmed
  working. Quit menu works. Required fix: set
  `GENERATE_INFOPLIST_FILE = YES` on TAELMacAgentTests target.

## Future, intentionally deferred

These are *not* PR 1 problems but Ozzy-side decisions that will land soon:

- [ ] Decide product name. v0.3 is explicit: do this **after** the
  Week 1 heartbeat works.
- [ ] Decide release signing model (Developer ID + notarization).
- [ ] Decide on KeyboardShortcuts package source (sindresorhus/KeyboardShortcuts)
  vs hand-rolled. PR 2 will need to add it via SPM.
- [ ] Decide on a HUD design language. PR 1 ships an intentionally
  ugly placeholder.

## PR-3 follow-up items from PR #18 review

The 5-agent review of PR #18 surfaced these gaps. They were
deliberately not bundled into PR 2 because each one either
exceeds Week 1 scope, touches behavior the v0.3 §23.4 acceptance
test does not require, or is a test-quality improvement that
adds value without blocking the heartbeat. Pick them up in PR 3
or as small follow-ups — none of them are urgent in isolation.

- [x] **User-facing error HUD on capture failure.**
  Shipped 2026-04-26 in PR-3 (Task 6). `HUDErrorView` + a `presentError`
  closure on `HotkeyInvocationHandler`, wired through `HUDPanelController`
  and `AppDelegate`. Permission-error path intentionally does not call
  `presentError` — `PermissionsGate` already shows the gate UI.
- [x] **Hotkey closure teardown race.**
  Shipped 2026-04-26 in PR-3 (Task 4). `AppDelegate.log` is now
  `private static let` so the guard's `else` clause can log
  `"Hotkey fired but app state unavailable; ignoring"` without a `self`
  reference. Folded into the same commit as the concurrent-invocation guard.
- [x] **Concurrent invocation guard.**
  Shipped 2026-04-26 in PR-3 (Task 4). `HotkeyManager.onTrigger` is now
  `() async -> Void`; the manager wraps the closure in a `Task` and gates
  on a private `isInFlight` flag. Re-entrant presses during a slow capture
  are dropped silently. New `HotkeyManagerTests` cover the in-flight drop,
  the post-completion fire-again, and `tearDown` clearing state.
- [x] **Test: deterministic-clock latency assertions.**
  Shipped 2026-04-26 in PR-3 (Task 3). `StubClock` pops dates from a fixed
  sequence and is wired through the handler's existing `now:` parameter.
  Granted-path test asserts exact 100ms gate + 200ms capture; capture-
  failure test asserts 50ms gate latency is retained across the failure.
- [x] **Test: `.notImplemented` → `.restricted` mapping.**
  Shipped 2026-04-26 in PR-3 (Task 2). `HotkeyInvocationHandler` accepts
  a `kind: PermissionKind` init parameter (default `.screenRecording` —
  no production behavior change). New test passes `.accessibility` (whose
  `isImplemented` returns false in Week 1) and asserts the gate throws
  `.notImplemented`, the handler logs `.restricted`, and no UI is shown.
