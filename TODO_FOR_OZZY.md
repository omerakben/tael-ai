# TODO for Ozzy

Owner-side decisions and credentials that affect the internal alpha track.

## Signing and identity

- [x] **Set Apple Developer Team ID in Xcode.**
  Set 2026-04-26. Team: OMER FARUK AKBEN, Team ID: 4X8U3NCLQ8.
  Automatic signing enabled, Development certificate.
- [x] **Choose preferred local signing identity.**
  Confirmed 2026-04-26. Apple Development (automatic), paid Apple
  Developer Program (Individual). Signing Certificate: Development.
- [x] **Confirm bundle ID `ai.tael.macagent` is acceptable long-term.**
  Confirmed 2026-04-26. Used as the stable TCC identity.
- [ ] **Install Developer ID Application certificate.**
  Required before `scripts/package-alpha-dmg.sh` can produce a notarized
  internal alpha DMG. Current local keychain inspection showed Apple
  Development only.
- [ ] **Create a `notarytool` keychain profile.**
  Recommended profile name: `tael-notary`.
  Run `xcrun notarytool store-credentials tael-notary` locally.

## Repo and naming

- [x] **Confirm repo name `tael-ai` should remain.**
  Confirmed 2026-04-26. Keeping `tael-ai`.
- [x] **Confirm GitHub Issues should be created manually or via CLI.**
  Week 1 issues were created via CLI and are reconciled as part of the
  SDLC stabilization pass.

## Branches

- [x] **Confirm branch model.**
  Active flow: `feature/*` or `codex/*` → `develop` → `main`.
  Claude remains a review checkpoint; Codex can lead scoped execution.

## Build / test status

- [x] **Run `xcodebuild` locally.**
  Verified 2026-04-26. Clean build succeeds. All 11 tests pass
  (3 HotkeyHandler, 3 LocalLogService, 5 PermissionsGate).
  App launches as menubar utility. Permission gate HUD confirmed
  working. Quit menu works. Required fix: set
  `GENERATE_INFOPLIST_FILE = YES` on TAELMacAgentTests target.
- [x] **Fix signing source drift for test host.**
  Verified 2026-04-30. `project.yml` now carries Team `4X8U3NCLQ8`,
  Apple Development debug signing, and generated test target Info.plist
  settings so `make xcodeproj` does not reintroduce ad-hoc test signing.
  `make test` passes with 20 tests.

## Future, intentionally deferred

These are not blockers for the current internal alpha stabilization pass:

- [ ] Decide product name. Internal alpha remains TAEL / TAELMacAgent.
- [x] Decide release signing model.
  Internal alpha uses manual Developer ID DMG plus notarization.
- [x] Decide on KeyboardShortcuts package source.
  `sindresorhus/KeyboardShortcuts` is active via SPM.
- [ ] Decide on a HUD design language. The current HUD is functional
  but intentionally plain.

## PR-3 follow-up items from PR #18 review

The 5-agent review of PR #18 surfaced these gaps. They were
deliberately not bundled into PR 2 because each one either
exceeds Week 1 scope, touches behavior the v0.3 §23.4 acceptance
test does not require, or is a test-quality improvement that
adds value without blocking the heartbeat. Pick them up in PR 3
or as small follow-ups. None of them are urgent in isolation.

- [x] **User-facing error HUD on capture failure.**
  Shipped 2026-04-26 in PR-3 (Task 6). `HUDErrorView` + a `presentError`
  closure on `HotkeyInvocationHandler`, wired through `HUDPanelController`
  and `AppDelegate`. Permission-error path intentionally does not call
  `presentError`; `PermissionsGate` already shows the gate UI.
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
  a `kind: PermissionKind` init parameter (default `.screenRecording`;
  no production behavior change). New test passes `.microphone` (which
  remains unimplemented) and asserts the gate throws
  `.notImplemented`, the handler logs `.restricted`, and no UI is shown.
