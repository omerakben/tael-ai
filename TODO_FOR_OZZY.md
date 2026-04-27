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

- [ ] **User-facing error HUD on capture failure.**
  Today `HotkeyInvocationHandler.run()` writes an `InvocationLog`
  row and `os.log` line on capture failure, then returns silently.
  v0.3 §23.4 only requires "does not crash," but the UX intent of
  the heartbeat is feedback. Add an `HUDErrorView(message:)` and a
  `presentError: (String) -> Void` closure on the handler, parallel
  to `presentScreenshot`. Wire it from `AppDelegate`. Source: `silent-failure-hunter` review of PR #18.
- [ ] **Hotkey closure teardown race.**
  In `AppDelegate.swift:51-66` the hotkey closure early-returns
  silently if any of `permissionsGate`, `screenCaptureService`,
  `hudController`, `logService` is nil — only happens during
  `applicationWillTerminate` race. Add at minimum
  `Self.log.error("Hotkey fired but app state unavailable")` in the
  guard's `else`. Source: `silent-failure-hunter` review of PR #18.
- [ ] **Concurrent invocation guard.**
  Two rapid hotkey presses spawn two concurrent `Task { await
  handler.run() }` blocks. The slower one wins the HUD. If
  invocation #1 succeeds late and #2 fails fast, the user sees
  invocation #1's screenshot with no signal that the most recent
  press failed. Add an in-flight token on the handler (or
  `HotkeyManager` debounce). Source: `silent-failure-hunter` IMPORTANT
  4 + `pr-test-analyzer` #7 from PR #18 review.
- [ ] **Test: deterministic-clock latency assertions.**
  `HotkeyHandlerTests` currently asserts `XCTAssertNotNil` on
  `gateLatencyMs` / `captureLatencyMs`. Inject a deterministic
  `now: () -> Date` (the handler already accepts one) and assert
  exact ms values, ordering (`gateLatencyMs >= 0`,
  `gateLatencyMs + captureLatencyMs <= elapsed`), and units
  (regression-proof against a missing `* 1000`). Source:
  `pr-test-analyzer` #2.
- [ ] **Test: `.notImplemented` → `.restricted` mapping.**
  `HotkeyInvocationHandler.swift` maps `PermissionError.notImplemented`
  to `gateOutcome = .restricted`. No test exercises this branch.
  Add a stub gate that throws `.notImplemented` and assert the
  outcome is `.restricted`. Source: `pr-test-analyzer` #1.
