# PR 3 — Review-debt cleanup from PR #18

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans`. Steps use checkbox (`- [ ]`) syntax. **Project-specific:** "subagent" maps to Codex via the `agent-codex:codex` skill; Claude Opus 4.7 reviews each commit. Tasks 1 (branch + push) and 8 (PR creation) are maestro-only because Codex's sandbox blocks `.git` writes and `gh` writes.

**Goal:** Land the five review items the PR #18 5-agent review surfaced and that `TODO_FOR_OZZY.md` queued under "PR-3 follow-up items." After PR-3, the heartbeat ships clean: no silent capture-failure UX, no observability gaps on partial failures, no concurrent-invocation race, full test coverage of the gate-outcome state machine.

**Architecture:** Five disjoint changes. Two test-only additions, one tiny logging fix, one HotkeyManager refactor (sync trigger → async trigger with in-flight guard), one new SwiftUI view (`HUDErrorView`) plumbed through the existing `HUDPanelController` / `HotkeyInvocationHandler` pipeline. No new TCC-protected APIs touched. PermissionsGate boundary stays intact.

**Tech stack:** Swift 5.10, SwiftUI, AppKit, KeyboardShortcuts, XCTest, Xcode 16+, macOS 14.0+. No new dependencies.

**Spec sources:** `TODO_FOR_OZZY.md` "PR-3 follow-up items from PR #18 review" (5 checkboxes); the agent reports captured in PR #18's review thread (`silent-failure-hunter`, `pr-test-analyzer`, `code-reviewer`, `comment-analyzer`, `type-design-analyzer`).

**Out of scope:**

- AX tree, focused-window metadata (Week 2 — separate PR)
- Voice / WhisperKit (Week 3)
- Auto-dismiss timer on the error HUD (timing complexity; v1 mirrors the screenshot HUD's dismiss behavior)
- Retry button on the error HUD (user re-presses the hotkey)
- Refactoring `PermissionsGate` to a protocol (not needed; tests can hit `.notImplemented` via a non-implemented `PermissionKind` once the handler accepts a `kind` parameter)

---

## Pre-flight

### Task 1: Branch off develop (maestro only)

**Files:** none

**Why maestro-only:** `.git/index.lock` writes are blocked by Codex's `workspace-write` sandbox.

- [ ] **Step 1: Sync develop and create the feature branch**

```bash
git checkout develop && git pull origin develop && \
  git checkout -b feature/pr3-review-debt && \
  git push -u origin feature/pr3-review-debt
```

Expected: `Switched to a new branch 'feature/pr3-review-debt'`, branch tracks origin.

---

## Test-only additions

### Task 2: Add `.notImplemented` → `.restricted` test (parameterize `kind`)

**Files:**

- Modify: `TAELMacAgent/TAELMacAgent/App/HotkeyInvocationHandler.swift`
- Modify: `TAELMacAgent/TAELMacAgent/App/AppDelegate.swift`
- Modify: `TAELMacAgent/TAELMacAgentTests/HotkeyHandlerTests.swift`

**Why:** `HotkeyInvocationHandler.run()` maps `PermissionError.notImplemented` to `gateOutcome = .restricted`, but no test exercises that branch. The handler hardcodes `.screenRecording`, so the `.notImplemented` path is unreachable from tests today. Smallest-possible refactor: add a `kind: PermissionKind` init parameter defaulting to `.screenRecording` (production behavior unchanged), then test with `.accessibility` or `.microphone` (whose `isImplemented` returns `false` for Week 1).

**Ordering:** test-only items first because they have zero production-behavior risk. If any of Tasks 4–6 regress, these tests must remain green to prove the regression is in the new code, not the test fixture.

- [ ] **Step 1: Add `kind` parameter to `HotkeyInvocationHandler`**

In `TAELMacAgent/TAELMacAgent/App/HotkeyInvocationHandler.swift`, modify the struct:

```swift
@MainActor
struct HotkeyInvocationHandler {
    let permissionsGate: PermissionsGate
    let screenCaptureService: any DisplayScreenshotCapturing
    let presentScreenshot: (CapturedScreenshot) -> Void
    let logService: LocalLogService
    let now: () -> Date
    let kind: PermissionKind

    init(
        permissionsGate: PermissionsGate,
        screenCaptureService: any DisplayScreenshotCapturing,
        presentScreenshot: @escaping (CapturedScreenshot) -> Void,
        logService: LocalLogService,
        now: @escaping () -> Date = Date.init,
        kind: PermissionKind = .screenRecording
    ) {
        self.permissionsGate = permissionsGate
        self.screenCaptureService = screenCaptureService
        self.presentScreenshot = presentScreenshot
        self.logService = logService
        self.now = now
        self.kind = kind
    }
    // ... existing log + run() ...
}
```

In `run()`, change the hardcoded `.screenRecording` to `kind`:

```swift
let screenshot = try await permissionsGate.withPermission(kind) { grant in
    // ...
}
```

The `precondition` inside `ScreenCaptureService.captureDisplayScreenshot` still requires `.screenRecording`, so passing any other kind through to a real capture would assert. That's correct — production stays bound to `.screenRecording`; tests using a non-`.screenRecording` kind never reach the capture call (the gate throws first).

- [ ] **Step 2: AppDelegate — no change needed**

The default `kind: PermissionKind = .screenRecording` means `AppDelegate` keeps calling `HotkeyInvocationHandler(...)` without specifying kind. Verify the call site doesn't need updates by `grep`-ing:

```bash
grep -n "HotkeyInvocationHandler(" TAELMacAgent/TAELMacAgent/App/AppDelegate.swift
```

Expected: one match, no `kind:` argument needed.

- [ ] **Step 3: Add the new test**

In `TAELMacAgent/TAELMacAgentTests/HotkeyHandlerTests.swift`, add after the capture-failure test:

```swift
// MARK: - Not-implemented kind

func test_run_whenKindNotImplemented_doesNotCapture_logsRestricted() async {
    // Use a kind whose isImplemented returns false today (Week 1
    // implements only .screenRecording). The gate throws .notImplemented
    // before any capture work runs.
    let checker = StubChecker(.granted)
    let ui = SpyUI()
    let gate = PermissionsGate(checker: checker, permissionUI: ui)
    let capture = SpyCapture(stub: makeStubScreenshot())
    let logService = LocalLogService(capacity: 16)

    var presented: [CapturedScreenshot] = []
    let handler = HotkeyInvocationHandler(
        permissionsGate: gate,
        screenCaptureService: capture,
        presentScreenshot: { presented.append($0) },
        logService: logService,
        kind: .accessibility
    )

    await handler.run()

    let observed = await capture.observedTargets()
    XCTAssertTrue(observed.isEmpty, "Capture must not run when kind is unimplemented")
    XCTAssertTrue(presented.isEmpty)

    let logs = await logService.recent(10)
    XCTAssertEqual(logs.count, 1)
    XCTAssertEqual(logs.first?.gateOutcome, .restricted)
    XCTAssertNil(logs.first?.gateLatencyMs, "gate didn't grant; latency must stay nil")
    XCTAssertNotNil(logs.first?.errorDescription)

    // The gate does NOT show UI for .notImplemented (per the existing
    // PermissionsGateTests contract: not-implemented is silent).
    let shown = await ui.shownKinds
    XCTAssertTrue(shown.isEmpty)
}
```

- [ ] **Step 4: Build + run only the new test**

```bash
xcodebuild test \
  -project TAELMacAgent/TAELMacAgent.xcodeproj \
  -scheme TAELMacAgent \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO \
  -only-testing:TAELMacAgentTests/HotkeyHandlerTests/test_run_whenKindNotImplemented_doesNotCapture_logsRestricted
```

Expected: 1 test passes.

- [ ] **Step 5: Run the full suite**

```bash
xcodebuild -project TAELMacAgent/TAELMacAgent.xcodeproj \
  -scheme TAELMacAgent -configuration Debug \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test
```

Expected: 12 tests pass (5 PermissionsGate + 3 LocalLogService + 4 HotkeyHandler).

- [ ] **Step 6: Commit**

```bash
git add TAELMacAgent/TAELMacAgent/App/HotkeyInvocationHandler.swift \
        TAELMacAgent/TAELMacAgentTests/HotkeyHandlerTests.swift
git commit -m "test(handler): cover .notImplemented → .restricted mapping

HotkeyInvocationHandler maps PermissionError.notImplemented to
GateOutcome.restricted, but the previous tests hardcoded
.screenRecording so the branch was unreachable. Add a kind:
PermissionKind init parameter (defaulting to .screenRecording — no
production behavior change) and exercise the branch by passing
.accessibility, whose isImplemented returns false for Week 1."
```

---

### Task 3: Deterministic-clock latency assertions

**Files:**

- Modify: `TAELMacAgent/TAELMacAgentTests/HotkeyHandlerTests.swift`

**Why:** existing tests assert `XCTAssertNotNil(logs.first?.gateLatencyMs)`. A regression that drops `* 1000` (units) or flips a sign or computes from the wrong baseline would not fail. The handler already accepts `now: () -> Date = Date.init` — wire a stub clock through it and pin exact ms values + ordering.

- [ ] **Step 1: Add a clock helper in `HotkeyHandlerTests`**

Above the test methods (after `makeStubScreenshot`), add:

```swift
/// Pops dates from a fixed sequence each time it's read. The handler
/// reads `now()` exactly twice on the granted path (gateEnd, captureEnd)
/// and once on the failure paths (`started` only). Provide enough slots
/// for the longest path. Built as a class so the closure-captured `var`
/// stays alive across reads from any actor.
private final class StubClock: @unchecked Sendable {
    private var ticks: [Date]
    init(_ ticks: [Date]) { self.ticks = ticks }
    func next() -> Date {
        precondition(!ticks.isEmpty, "StubClock ran out of ticks")
        return ticks.removeFirst()
    }
}
```

- [ ] **Step 2: Strengthen the granted test**

Replace the granted-path test body with the deterministic version:

```swift
func test_run_whenGranted_callsCaptureAndPresentsAndLogsGranted() async {
    let checker = StubChecker(.granted)
    let ui = SpyUI()
    let gate = PermissionsGate(checker: checker, permissionUI: ui)
    let capture = SpyCapture(stub: makeStubScreenshot())
    let logService = LocalLogService(capacity: 16)

    // Pin exact latencies: started=0, gateEnd=0.1 (gate took 100ms),
    // captureEnd=0.3 (capture took 200ms). 4 slots: started, gateEnd,
    // captureStart (= gateEnd in handler, but read separately is fine
    // since handler aliases captureStart = gateEnd via let), captureEnd.
    let clock = StubClock([
        Date(timeIntervalSince1970: 0),
        Date(timeIntervalSince1970: 0.1),
        Date(timeIntervalSince1970: 0.3),
    ])

    var presented: [CapturedScreenshot] = []
    let handler = HotkeyInvocationHandler(
        permissionsGate: gate,
        screenCaptureService: capture,
        presentScreenshot: { presented.append($0) },
        logService: logService,
        now: { clock.next() }
    )

    await handler.run()

    let targets = await capture.observedTargets()
    XCTAssertEqual(targets, [.week1Default])
    XCTAssertEqual(presented.count, 1)

    let logs = await logService.recent(10)
    XCTAssertEqual(logs.count, 1)
    let row = try XCTUnwrap(logs.first)
    XCTAssertEqual(row.gateOutcome, .granted)
    XCTAssertEqual(row.gateLatencyMs, 100, accuracy: 0.001,
        "gate took 100ms (0 → 0.1 second), value must be ms not seconds")
    XCTAssertEqual(row.captureLatencyMs, 200, accuracy: 0.001,
        "capture took 200ms (0.1 → 0.3 second)")
    XCTAssertGreaterThanOrEqual(row.gateLatencyMs ?? -1, 0)
    XCTAssertGreaterThanOrEqual(row.captureLatencyMs ?? -1, 0)
}
```

Note: `XCTUnwrap` requires `try` and the test method becomes `async throws` — change the signature.

- [ ] **Step 3: Strengthen the capture-failure test similarly**

Replace its body:

```swift
func test_run_whenCaptureFails_logsErroredOutcome() async throws {
    let checker = StubChecker(.granted)
    let ui = SpyUI()
    let gate = PermissionsGate(checker: checker, permissionUI: ui)
    let capture = SpyCapture(stub: makeStubScreenshot())
    await capture.setError(ScreenCaptureError.captureFailed("simulated"))

    let logService = LocalLogService(capacity: 16)

    let clock = StubClock([
        Date(timeIntervalSince1970: 0),
        Date(timeIntervalSince1970: 0.05),
    ])

    var presented: [CapturedScreenshot] = []
    let handler = HotkeyInvocationHandler(
        permissionsGate: gate,
        screenCaptureService: capture,
        presentScreenshot: { presented.append($0) },
        logService: logService,
        now: { clock.next() }
    )

    await handler.run()

    XCTAssertTrue(presented.isEmpty)
    let logs = await logService.recent(10)
    XCTAssertEqual(logs.count, 1)
    let row = try XCTUnwrap(logs.first)
    XCTAssertEqual(row.gateOutcome, .errored)
    XCTAssertEqual(row.errorDescription, "captureFailed(\"simulated\")")
    XCTAssertEqual(row.gateLatencyMs, 50, accuracy: 0.001,
        "gate granted in 50ms before capture threw; latency must be retained")
}
```

- [ ] **Step 4: Run the full suite**

```bash
xcodebuild -project TAELMacAgent/TAELMacAgent.xcodeproj \
  -scheme TAELMacAgent -configuration Debug \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test
```

Expected: 12 tests pass.

- [ ] **Step 5: Commit**

```bash
git add TAELMacAgent/TAELMacAgentTests/HotkeyHandlerTests.swift
git commit -m "test(handler): pin latency values with a deterministic clock

Existing assertions only checked notNil. A units regression (missing
* 1000) or a sign flip would have shipped silently. Inject a StubClock
through the handler's existing now: closure parameter and assert exact
millisecond values for both the granted path (100ms gate + 200ms
capture) and the capture-failure path (50ms gate, latency retained
across the failure)."
```

---

## Production fixes

### Task 4: Concurrent-invocation guard in `HotkeyManager`

**Files:**

- Modify: `TAELMacAgent/TAELMacAgent/Hotkey/HotkeyManager.swift`
- Modify: `TAELMacAgent/TAELMacAgent/App/AppDelegate.swift`
- Modify: `TAELMacAgent/TAELMacAgentTests/` (new file `HotkeyManagerTests.swift`)

**Why:** two rapid hotkey presses spawn two concurrent `Task { await handler.run() }` blocks. The slower one's HUD wins. If invocation #1 succeeds late and #2 fails fast, the user sees invocation #1's screenshot with no signal that the most recent press failed. Fix: change `onTrigger` from `() -> Void` to `() async -> Void`, gate it with an `isInFlight` flag inside `HotkeyManager`. Drops re-entrant presses. AppDelegate adapts.

**Why HotkeyManager and not the handler:** the manager is the entity that knows about hotkey events. The handler is per-invocation; making it self-aware of a sibling invocation is awkward. Manager-level debounce is the natural seam.

- [ ] **Step 1: Update `HotkeyManager` to async trigger + in-flight guard**

Replace `TAELMacAgent/TAELMacAgent/Hotkey/HotkeyManager.swift` body:

```swift
@MainActor
final class HotkeyManager {
    /// Set by `AppDelegate` to the gate→capture→HUD pipeline. Async so
    /// the manager can `await` it and clear the in-flight guard only
    /// after the full invocation completes.
    var onTrigger: (() async -> Void)?

    private var isInFlight = false

    func installBinding() {
        KeyboardShortcuts.onKeyDown(for: .toggleTAEL) { [weak self] in
            self?.fireIfFree()
        }
    }

    /// Drops the press if a previous invocation hasn't completed yet.
    private func fireIfFree() {
        guard !isInFlight else { return }
        guard let onTrigger else { return }
        isInFlight = true
        Task { @MainActor [weak self] in
            await onTrigger()
            self?.isInFlight = false
        }
    }

    func tearDown() {
        KeyboardShortcuts.disable(.toggleTAEL)
        onTrigger = nil
        isInFlight = false
    }

    // MARK: - Test seam

    /// Test-only entry: simulates a hotkey press without going through
    /// the KeyboardShortcuts package. Exposed via @testable import.
    func simulatePressForTesting() {
        fireIfFree()
    }
}
```

- [ ] **Step 2: Update `AppDelegate` — onTrigger closure becomes async**

The current closure does `Task { @MainActor in await handler.run() }` because `onTrigger` was `() -> Void`. With the new async signature, the inner `Task` is redundant. Replace:

```swift
hotkeyManager.onTrigger = { [weak self] in
    guard let self,
          let permissionsGate = self.permissionsGate,
          let screenCaptureService = self.screenCaptureService,
          let hudController = self.hudController,
          let logService = self.logService else { return }
    let handler = HotkeyInvocationHandler(
        permissionsGate: permissionsGate,
        screenCaptureService: screenCaptureService,
        presentScreenshot: { shot in hudController.present(screenshot: shot) },
        logService: logService
    )
    Task { @MainActor in
        await handler.run()
    }
}
```

With:

```swift
hotkeyManager.onTrigger = { [weak self] in
    guard let self,
          let permissionsGate = self.permissionsGate,
          let screenCaptureService = self.screenCaptureService,
          let hudController = self.hudController,
          let logService = self.logService else {
        AppDelegate.log.error("Hotkey fired but app state unavailable; ignoring")
        return
    }
    let handler = HotkeyInvocationHandler(
        permissionsGate: permissionsGate,
        screenCaptureService: screenCaptureService,
        presentScreenshot: { shot in hudController.present(screenshot: shot) },
        logService: logService
    )
    await handler.run()
}
```

(Also addresses Task 5's teardown-race logger requirement in the same edit. Convert `private let log = Logger(...)` to `private static let log = Logger(...)` at the class level so the static reference works in the guard's else.)

- [ ] **Step 3: Add `HotkeyManagerTests`**

Create `TAELMacAgent/TAELMacAgentTests/HotkeyManagerTests.swift`:

```swift
//
//  HotkeyManagerTests.swift
//  TAELMacAgentTests
//

import XCTest
@testable import TAELMacAgent

@MainActor
final class HotkeyManagerTests: XCTestCase {

    func test_simulatePress_invokesTriggerOnce_evenIfFiredTwiceConcurrently() async {
        let manager = HotkeyManager()

        // Use an actor counter so concurrent reads/writes are safe.
        let counter = Counter()

        manager.onTrigger = {
            await counter.increment()
            // Hold the in-flight gate open long enough for a second press
            // to race in. Sleep on the main actor is fine; we just need
            // the Task to suspend.
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
        }

        manager.simulatePressForTesting()
        // Second press while the first is still in-flight; must be dropped.
        manager.simulatePressForTesting()

        // Wait for the in-flight Task to complete + a margin.
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms

        let count = await counter.value
        XCTAssertEqual(count, 1, "Re-entrant press during in-flight invocation must be dropped")
    }

    func test_simulatePress_afterPreviousCompletes_invokesTriggerAgain() async {
        let manager = HotkeyManager()
        let counter = Counter()

        manager.onTrigger = {
            await counter.increment()
        }

        manager.simulatePressForTesting()
        try? await Task.sleep(nanoseconds: 20_000_000) // let it finish
        manager.simulatePressForTesting()
        try? await Task.sleep(nanoseconds: 20_000_000)

        let count = await counter.value
        XCTAssertEqual(count, 2, "Sequential presses must each fire once")
    }

    func test_tearDown_clearsInFlightAndOnTrigger() async {
        let manager = HotkeyManager()
        manager.onTrigger = { /* no-op */ }
        manager.simulatePressForTesting()

        // Tear down immediately; even though the in-flight Task may still
        // run, the manager's state should be reset for next session.
        manager.tearDown()

        XCTAssertNil(manager.onTrigger)
    }

    private actor Counter {
        private(set) var value = 0
        func increment() { value += 1 }
    }
}
```

- [ ] **Step 4: Run the full suite**

```bash
xcodebuild -project TAELMacAgent/TAELMacAgent.xcodeproj \
  -scheme TAELMacAgent -configuration Debug \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test
```

Expected: 15 tests pass (12 prior + 3 HotkeyManager).

- [ ] **Step 5: Commit**

```bash
git add TAELMacAgent/TAELMacAgent/Hotkey/HotkeyManager.swift \
        TAELMacAgent/TAELMacAgent/App/AppDelegate.swift \
        TAELMacAgent/TAELMacAgentTests/HotkeyManagerTests.swift \
        TAELMacAgent/TAELMacAgent.xcodeproj/project.pbxproj
git commit -m "feat(hotkey): drop re-entrant presses while invocation is in-flight

Two rapid hotkey presses used to spawn two concurrent Task blocks; the
slower invocation's HUD content won regardless of which press was most
recent. HotkeyManager now flips an isInFlight flag when firing onTrigger
and clears it after the awaited closure returns. Re-entrant presses are
dropped silently.

onTrigger signature changes from () -> Void to () async -> Void;
AppDelegate adapts. The previous fire-and-forget Task wrapper at the
call site is no longer needed because HotkeyManager owns the Task now.

Also: AppDelegate.log is now a static let so the guard-failed teardown
path can log without a self reference (silent-failure-hunter
BLOCKER 2 from PR #18 review).

Three new HotkeyManagerTests cover: re-entrant drop, sequential fire-
again, tearDown clears state."
```

---

### Task 5: Subsumed by Task 4

The teardown-race logger fix folds into Task 4 (the AppDelegate guard's else clause now logs via `AppDelegate.log`). No separate task needed; this slot is intentionally empty so the task numbering matches the TODO_FOR_OZZY item count when reading both side-by-side.

---

### Task 6: Error HUD on capture failure

**Files:**

- Create: `TAELMacAgent/TAELMacAgent/HUD/HUDErrorView.swift`
- Modify: `TAELMacAgent/TAELMacAgent/HUD/HUDPanelController.swift`
- Modify: `TAELMacAgent/TAELMacAgent/App/HotkeyInvocationHandler.swift`
- Modify: `TAELMacAgent/TAELMacAgent/App/AppDelegate.swift`
- Modify: `TAELMacAgent/TAELMacAgentTests/HotkeyHandlerTests.swift`

**Why:** today, capture failure writes an `InvocationLog` row + `os.log` line and returns silently. The user sees nothing — they assume the hotkey is broken and press it again, harder. v0.3 §23.4 only requires "doesn't crash," so this isn't a Week 1 blocker, but the heartbeat's UX intent is feedback. Add a parallel `HUDErrorView` and a `presentError: (String) -> Void` closure on the handler.

**Design choices fixed:**

- Multi-line view: title + message
- Click to dismiss: not in v1 (would require NSPanel mouse-event interception; defer)
- Auto-dismiss timer: not in v1 (timing complexity)
- Dismiss behavior: same as the screenshot HUD — replaced by the next hotkey press; otherwise sticks around. Acceptable for v1.

- [ ] **Step 1: Create `HUDErrorView`**

Create `TAELMacAgent/TAELMacAgent/HUD/HUDErrorView.swift`:

```swift
//
//  HUDErrorView.swift
//  TAELMacAgent
//
//  Shown when a hotkey invocation reaches the capture stage and fails.
//  Mirrors HUDScreenshotView's layout for visual consistency.
//

import SwiftUI

struct HUDErrorView: View {
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Capture failed", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(.orange)

            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 480, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
    }
}
```

- [ ] **Step 2: Add `present(error:)` to `HUDPanelController`**

In `TAELMacAgent/TAELMacAgent/HUD/HUDPanelController.swift`, add the method next to `present(screenshot:)`:

```swift
func present(error message: String) {
    presentNew(content: HUDErrorView(message: message))
}
```

- [ ] **Step 3: Add `presentError` to `HotkeyInvocationHandler`**

In `TAELMacAgent/TAELMacAgent/App/HotkeyInvocationHandler.swift`, add the property + init parameter:

```swift
let presentError: (String) -> Void

init(
    permissionsGate: PermissionsGate,
    screenCaptureService: any DisplayScreenshotCapturing,
    presentScreenshot: @escaping (CapturedScreenshot) -> Void,
    presentError: @escaping (String) -> Void = { _ in },
    logService: LocalLogService,
    now: @escaping () -> Date = Date.init,
    kind: PermissionKind = .screenRecording
) {
    self.permissionsGate = permissionsGate
    self.screenCaptureService = screenCaptureService
    self.presentScreenshot = presentScreenshot
    self.presentError = presentError
    self.logService = logService
    self.now = now
    self.kind = kind
}
```

(Default `{ _ in }` so existing tests that don't care about errors still construct cleanly.)

In `run()`'s generic-error catch arm, add the `presentError` call AFTER the log row is recorded (so observability lands first, then UI):

```swift
} catch {
    await logService.record(InvocationLog(
        hotkeyTimestamp: started,
        gateOutcome: .errored,
        gateLatencyMs: gateLatencyMs,
        errorDescription: String(describing: error)
    ))
    presentError("Screen capture failed: \(error.localizedDescription)")
    Self.log.error("Hotkey invocation failed: \(error.localizedDescription, privacy: .public)")
}
```

Do NOT add `presentError` to the `PermissionError` catch arm — `PermissionsGate` already shows a permission UI. Calling `presentError` there would stack two HUD panels.

- [ ] **Step 4: Wire in `AppDelegate`**

In the `onTrigger` closure (already async after Task 4), update the handler construction:

```swift
let handler = HotkeyInvocationHandler(
    permissionsGate: permissionsGate,
    screenCaptureService: screenCaptureService,
    presentScreenshot: { shot in hudController.present(screenshot: shot) },
    presentError: { msg in hudController.present(error: msg) },
    logService: logService
)
```

- [ ] **Step 5: Strengthen the capture-failure test**

In `HotkeyHandlerTests.swift`, update `test_run_whenCaptureFails_logsErroredOutcome` to also assert `presentError` was called:

```swift
var presented: [CapturedScreenshot] = []
var presentedErrors: [String] = []
let handler = HotkeyInvocationHandler(
    permissionsGate: gate,
    screenCaptureService: capture,
    presentScreenshot: { presented.append($0) },
    presentError: { presentedErrors.append($0) },
    logService: logService,
    now: { clock.next() }
)

await handler.run()

XCTAssertTrue(presented.isEmpty)
XCTAssertEqual(presentedErrors.count, 1)
let msg = try XCTUnwrap(presentedErrors.first)
XCTAssertTrue(msg.contains("Screen capture failed"),
    "Error HUD message should lead with the user-facing prefix")
```

Also update the granted, denied, and `.notImplemented` tests to pass a no-op `presentError: { _ in }` (or rely on the default — verify the default is still in the init).

In the granted test, ALSO assert `presentedErrors.isEmpty` — the success path must not present an error.

- [ ] **Step 6: Run the full suite**

```bash
xcodebuild -project TAELMacAgent/TAELMacAgent.xcodeproj \
  -scheme TAELMacAgent -configuration Debug \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test
```

Expected: 15 tests pass.

- [ ] **Step 7: Commit**

```bash
git add TAELMacAgent/TAELMacAgent/HUD/HUDErrorView.swift \
        TAELMacAgent/TAELMacAgent/HUD/HUDPanelController.swift \
        TAELMacAgent/TAELMacAgent/App/HotkeyInvocationHandler.swift \
        TAELMacAgent/TAELMacAgent/App/AppDelegate.swift \
        TAELMacAgent/TAELMacAgentTests/HotkeyHandlerTests.swift \
        TAELMacAgent/TAELMacAgent.xcodeproj/project.pbxproj
git commit -m "feat(hud): show error HUD on capture failure

Capture failures used to write an InvocationLog row plus an os.log
line and return silently — from the user's seat the hotkey just did
nothing. Add HUDErrorView and a presentError closure on
HotkeyInvocationHandler. The PermissionError catch arm intentionally
does NOT call presentError because PermissionsGate already shows the
permission UI; double-stacking would be confusing.

Test asserts: granted path doesn't fire presentError; capture-failure
path fires it exactly once with a message that leads with 'Screen
capture failed'."
```

---

## Documentation

### Task 7: Mark PR-3 items complete in `TODO_FOR_OZZY.md`

**Files:**

- Modify: `TODO_FOR_OZZY.md`

**Why:** the "PR-3 follow-up items from PR #18 review" section has 5 unchecked boxes. After the implementation tasks land, flip them to `[x]` with a short status line.

- [ ] **Step 1: Edit each checkbox**

For each of the 5 items:

- `User-facing error HUD on capture failure` → `[x]` + "Shipped 2026-04-26 in PR-3 (Task 6). HUDErrorView + presentError closure."
- `Hotkey closure teardown race` → `[x]` + "Shipped 2026-04-26 in PR-3 (Task 4). AppDelegate guard's else clause now logs via AppDelegate.log."
- `Concurrent invocation guard` → `[x]` + "Shipped 2026-04-26 in PR-3 (Task 4). HotkeyManager isInFlight flag drops re-entrant presses."
- `Test: deterministic-clock latency assertions` → `[x]` + "Shipped 2026-04-26 in PR-3 (Task 3). StubClock pins exact ms values."
- `Test: .notImplemented → .restricted mapping` → `[x]` + "Shipped 2026-04-26 in PR-3 (Task 2). Handler accepts kind: PermissionKind init param; test uses .accessibility."

- [ ] **Step 2: Commit**

```bash
git add TODO_FOR_OZZY.md
git commit -m "docs(todo): mark PR-3 review-debt items complete

All five PR #18 review follow-ups landed in PR-3. Status updated with
the task that addressed each item."
```

---

## Wrap up (maestro only)

### Task 8: Open the PR

**Files:** none (orchestration)

**Why maestro-only:** `gh pr create` writes to GitHub.

- [ ] **Step 1: Run the full clean test suite**

```bash
xcodebuild -project TAELMacAgent/TAELMacAgent.xcodeproj \
  -scheme TAELMacAgent -configuration Debug \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO clean test
```

Expected: 15 tests pass.

- [ ] **Step 2: Confirm the branch state**

```bash
git log origin/develop..HEAD --oneline
```

Expected: 5 or 6 commits (Tasks 2, 3, 4, 6, 7; Task 5 folded into Task 4).

- [ ] **Step 3: Push**

```bash
git push origin feature/pr3-review-debt
```

- [ ] **Step 4: Open the PR**

```bash
gh pr create --base develop --head feature/pr3-review-debt \
  --title "feat: PR 3 — review-debt cleanup from PR #18" \
  --body "$(cat <<'EOF'
## Summary

Lands the five review items the PR #18 5-agent review surfaced. Plan: `docs/superpowers/plans/2026-04-26-pr3-review-debt.md`.

## What's in

- **Error HUD on capture failure** — new `HUDErrorView` + `presentError` closure. Capture failures now show a user-facing error instead of returning silently.
- **Concurrent-invocation guard** — `HotkeyManager` drops re-entrant presses while an invocation is in-flight. `onTrigger` is now `() async -> Void`.
- **Teardown-race logger** — `AppDelegate.log` becomes static so the guard's else clause can log when the app state is unavailable during shutdown.
- **Deterministic-clock latency assertions** — `StubClock` pins exact ms values on the granted and capture-failure paths. Catches units regressions (missing `* 1000`) and sign flips.
- **`.notImplemented` → `.restricted` test** — `HotkeyInvocationHandler` accepts a `kind` parameter (defaulting to `.screenRecording` — no production behavior change). Test exercises the branch via `.accessibility`.

## Test plan

- [x] `xcodebuild ... clean test` — 15 tests, 0 failures (5 PermissionsGate + 3 LocalLogService + 4 HotkeyHandler + 3 HotkeyManager).
- [ ] Manual: trigger a real capture failure (e.g., revoke Screen Recording mid-session) and confirm `HUDErrorView` appears with the orange triangle icon.
- [ ] Manual: press the hotkey twice rapidly while a capture is in-flight; only one HUD should appear.

## Out of scope

- AX tree (Week 2)
- Voice / WhisperKit (Week 3)
- Auto-dismiss timer or click-to-dismiss on the error HUD (deferred for v1.1)
- Refactoring `PermissionsGate` to a protocol (not needed for the test added here)
EOF
)"
```

Expected: PR URL printed. Notify Ozzy.

---

## Self-review checklist

After writing the plan and before handing off:

**1. Spec coverage:** All 5 PR-3 follow-up items in `TODO_FOR_OZZY.md` map to a task above (with Task 5 folded into Task 4). Cross-checked.

**2. Placeholder scan:** No "TBD", "implement later", or "add appropriate error handling" patterns. Each step has concrete code or commands.

**3. Type consistency:**

- `HotkeyInvocationHandler` gains `kind: PermissionKind` (Task 2) and `presentError: (String) -> Void` (Task 6). Both have defaults so older test call sites don't need updates beyond the ones the plan calls out.
- `HotkeyManager.onTrigger` changes from `() -> Void` to `() async -> Void` (Task 4). The single call site in `AppDelegate` is updated in the same task.
- `HUDPanelController.present(error:)` is new (Task 6); `present(screenshot:)` stays.
- `HUDErrorView` is a fresh SwiftUI struct, no conflicts.
- `AppDelegate.log` migrates from `private let` to `private static let` (Task 4). All uses of `self.log` inside instance methods continue to work because `Self.log` is a valid reference; verify by `grep`.

**4. Test count progression:** PR #18 left the suite at 11 tests. Plan adds: +1 (`.notImplemented`), 0 net (Task 3 strengthens existing tests), +3 (HotkeyManager). Final: 15. The PR title and commit messages must match.

**5. Branch model alignment:** Feature branch off `develop`, single PR back into `develop`. Matches `project_branches` memory.

---

## Notes for the executor

- **Tasks 1 + 8 are maestro-only** for the same reasons as PR-2: branch creation pushes to origin, PR creation hits GitHub.
- **Sandbox commit pattern:** Codex's sandbox blocks `.git/index.lock` writes and `~/Library/Caches/org.swift.swiftpm`. Codex applies edits + reports diff; maestro stages, runs `xcodebuild test`, and commits. Same as PR #18 follow-up.
- **Test seam for Task 4:** `HotkeyManager.simulatePressForTesting()` is a deliberate testability hook. It mirrors the pattern from `PermissionsGate` where production code only ever fires from the real path but tests have a public seam. Document it inline; do NOT remove it after PR-3 lands — Week 4+ will need it again when AX gets its own hotkey-derived workflow.
- **Manual verification gate:** Task 6's error HUD can't be unit-tested visually. Manual case: revoke Screen Recording grant in System Settings → Privacy → Screen Recording while TAEL is running, then press the hotkey. Expected: `HUDErrorView` appears with the orange triangle and a message that contains "Screen capture failed".
- **Bot review gate:** open the PR, wait for CodeRabbit. If it flags anything substantial, batch a follow-up commit on the same branch — don't open a separate PR.
