# PR 4 — Week 2 part 1: Accessibility permission gate

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans`. Steps use checkbox (`- [ ]`) syntax. **Project-specific:** "subagent" maps to Codex via the `agent-codex:codex` skill; Claude Opus 4.7 reviews each commit. Tasks 1 (branch + push) and 7 (PR creation) are maestro-only because Codex's sandbox blocks `.git` writes and `gh` writes.

**Goal:** Make the Accessibility permission flow real. `PermissionKind.accessibility.isImplemented` flips from `false` to `true`. `PermissionsChecker.status(for: .accessibility)` calls `AXIsProcessTrusted()` (no prompt — checking only, prompting stays the gate UI's job). The user-facing copy on `PermissionGateView` for `.accessibility` upgrades from "Not yet implemented" to a real explanation. After PR-4, calling `permissionsGate.withPermission(.accessibility) { ... }` actually gates against the OS state instead of throwing `.notImplemented`.

**Architecture:** No new types, no new files. PR-4 only flips bits and fills in a real `AXIsProcessTrusted()` call. The existing `PermissionsGate` machinery (token, gate UI, checker) already handles `.accessibility` — PR-1 wired it as a placeholder. PR-3's `.notImplemented` → `.restricted` test that uses `.accessibility` becomes incorrect when AX is implemented; the test swaps to `.microphone` (which stays unimplemented until Week 3).

**Tech stack:** Swift 5.10, ApplicationServices framework (`AXIsProcessTrusted`), AppKit, SwiftUI, XCTest. No new SPM dependencies.

**Spec sources:** `TAEL_AI_mac_agent_build_plan_v0_3.md` §12.3 ("AX permission gate" deliverable), §23.0 ("Accessibility and Microphone may exist as enum placeholders, but they are not real checks until their milestones"), `docs/ProtectedAPICallPolicy.md` (the row that says "Future. Enum placeholder only" for Accessibility — gets flipped to "Active" in this PR).

**Out of scope:**

- AX tree reading, focused-window metadata, `AXService` (PR-5)
- Context bundle v0 (combining screenshot + AX) (PR-5 or PR-6)
- Any actual call to `AXUIElementCopyAttributeValue` or sibling AX read APIs (PR-5)
- Microphone, Apple Events, Input Monitoring permissions (their own milestone weeks)
- Real prompt UX on first launch — `AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt: true])` deliberately not used; gate UI is the prompt path

---

## Pre-flight

### Task 1: Branch off develop (maestro only)

**Files:** none

**Why maestro-only:** `.git/index.lock` writes are blocked by Codex's `workspace-write` sandbox.

**Pre-condition:** PR #19 (PR-3 review-debt) must be merged into `develop` first, OR branch off `feature/pr3-review-debt` if PR-3 hasn't merged yet — pick the cleaner of the two when this task runs.

- [ ] **Step 1: Confirm PR #19 status and pick the base**

```bash
gh pr view 19 --json state,mergeStateStatus
```

If `state: "MERGED"`, branch off `develop`. If still `OPEN` and you want PR-4 to start now anyway, branch off `feature/pr3-review-debt` (PR-4 will rebase later).

- [ ] **Step 2: Sync develop and create the feature branch**

```bash
git checkout develop && git pull origin develop && \
  git checkout -b feature/pr4-accessibility-permission-gate && \
  git push -u origin feature/pr4-accessibility-permission-gate
```

Expected: `Switched to a new branch 'feature/pr4-accessibility-permission-gate'`, branch tracks origin.

---

## The permission flip

### Task 2: Make `PermissionKind.accessibility.isImplemented` return `true`

**Files:**

- Modify: `TAELMacAgent/TAELMacAgent/Permissions/PermissionKind.swift`

**Why:** the `isImplemented` flag is what makes `PermissionsGate.withPermission` short-circuit with `.notImplemented` for placeholder kinds. Flipping `.accessibility` to `true` removes the short-circuit; the gate now consults `PermissionsChecker` and either grants or shows the gate UI.

- [ ] **Step 1: Edit the switch in `isImplemented`**

In `TAELMacAgent/TAELMacAgent/Permissions/PermissionKind.swift`, change:

```swift
public var isImplemented: Bool {
    switch self {
    case .screenRecording: return true
    case .accessibility, .microphone, .appleEvents, .inputMonitoring:
        return false
    }
}
```

To:

```swift
public var isImplemented: Bool {
    switch self {
    case .screenRecording, .accessibility: return true
    case .microphone, .appleEvents, .inputMonitoring:
        return false
    }
}
```

- [ ] **Step 2: Commit**

This commit will *break* a test (the `.notImplemented` test in `HotkeyHandlerTests` uses `.accessibility`). That's intentional — Task 4 fixes it. Commit Task 2 + Task 4 sequentially without running the suite in between, OR temporarily defer this commit until Task 4's fix is also staged. Pick the cleaner per-task split:

**Decision:** stage Tasks 2, 3, 4 together and commit as one logical unit. The semantic change is "Accessibility moves from placeholder to active, and the test that exercised the placeholder branch updates accordingly." Splitting that across three commits would leave the middle one with a known-broken test. See Task 4's commit message; Tasks 2 and 3 don't get their own commits.

---

### Task 3: Real `PermissionsChecker.status(for: .accessibility)`

**Files:**

- Modify: `TAELMacAgent/TAELMacAgent/Permissions/PermissionsChecker.swift`

**Why:** the checker currently returns `.notDetermined` for `.accessibility`. Replace with a real `AXIsProcessTrusted()` call. We do NOT use `AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt: true])` because prompting is the gate UI's job per `docs/ProtectedAPICallPolicy.md`.

- [ ] **Step 1: Add the ApplicationServices import**

At the top of `PermissionsChecker.swift`, after the existing imports, add:

```swift
#if canImport(ApplicationServices)
import ApplicationServices
#endif
```

(Wrapped in `#if canImport` for symmetry with the existing `CoreGraphics` import. ApplicationServices is macOS-only.)

- [ ] **Step 2: Add the accessibility status helper**

After `screenRecordingStatus()`, add:

```swift
// MARK: - Accessibility

private func accessibilityStatus() -> PermissionStatus {
    #if os(macOS)
    // AXIsProcessTrusted reads the current trust state without
    // prompting. The prompting variant
    // AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt: true])
    // is intentionally NOT used — the gate UI owns the prompt path so
    // the user always lands in the same flow regardless of which TCC
    // surface is missing.
    //
    // AX has no equivalent of CGPreflight's not-asked-yet ambiguity:
    // a fresh process that has never been added to the Accessibility
    // list returns false, same as one that was explicitly removed.
    // Either way, the gate UI surfaces the recovery path.
    return AXIsProcessTrusted() ? .granted : .notDetermined
    #else
    return .notDetermined
    #endif
}
```

- [ ] **Step 3: Route `.accessibility` through the new helper**

In `status(for:)`, change:

```swift
case .accessibility, .microphone, .appleEvents, .inputMonitoring:
    // Placeholder. Real checks land with their milestones.
    return .notDetermined
```

To:

```swift
case .accessibility:
    return accessibilityStatus()
case .microphone, .appleEvents, .inputMonitoring:
    // Placeholder. Real checks land with their milestones.
    return .notDetermined
```

- [ ] **Step 4: Update the file header**

The header currently says "PR 1: Screen Recording is implemented for real. The other kinds return `.notDetermined`...". Update to reflect that AX is now real too:

```swift
//  PR 1: Screen Recording is implemented for real.
//  PR 4: Accessibility is implemented for real.
//  Microphone, Apple Events, and Input Monitoring still return
//  `.notDetermined` so the gate can be exercised by tests without
//  making system calls until their milestones land.
```

(Trim if it gets too long; the exact wording is less important than accurately reflecting which kinds are live.)

---

### Task 4: Update PR-3's `.notImplemented` test

**Files:**

- Modify: `TAELMacAgent/TAELMacAgentTests/HotkeyHandlerTests.swift`
- Modify: `TAELMacAgent/TAELMacAgent/HUD/PermissionGateView.swift` (explanation copy update)

**Why:** PR-3 added `test_run_whenKindNotImplemented_doesNotCapture_logsRestricted` which constructs a handler with `kind: .accessibility`. That worked when `.accessibility.isImplemented` was `false`, but Task 2 flipped it to `true`. The test now needs a kind that's still unimplemented. `.microphone` is the right swap — it stays placeholder until Week 3.

Also: `PermissionGateView` has a hardcoded "Not yet implemented" string for `.accessibility` that's now wrong.

- [ ] **Step 1: Swap `.accessibility` to `.microphone` in the test**

In `TAELMacAgent/TAELMacAgentTests/HotkeyHandlerTests.swift`, find the `.notImplemented` test:

```swift
let handler = HotkeyInvocationHandler(
    permissionsGate: gate,
    screenCaptureService: capture,
    presentScreenshot: { presented.append($0) },
    logService: logService,
    kind: .accessibility
)
```

Change `kind: .accessibility` to `kind: .microphone`. The test's purpose is to exercise the `.notImplemented` → `.restricted` mapping; any unimplemented kind works. `.microphone` stays unimplemented until Week 3 (see `PermissionKind.swift`).

Update the test's leading comment if it mentions accessibility specifically; replace with "Use a kind whose isImplemented returns false today (Week 1 implements .screenRecording, PR 4 implements .accessibility; .microphone, .appleEvents, .inputMonitoring stay placeholders)."

- [ ] **Step 2: Update the `.accessibility` explanation in `PermissionGateView`**

In `TAELMacAgent/TAELMacAgent/HUD/PermissionGateView.swift`, find:

```swift
case .accessibility:
    return "Used to read the focused window's UI tree. Not yet implemented."
```

Change to:

```swift
case .accessibility:
    return "Used to read the focused window's UI tree (title, role, content text) so TAEL can scope context to what you're looking at. Read-only — TAEL does not synthesize keyboard or mouse events."
```

The "Read-only" sentence anticipates a likely user concern: AX permission grants the *ability* to synthesize input, not just read. We're not using the synthesis path in PR-4, but the user's mental model when granting Accessibility includes "this app could move my mouse." Calling out the read-only intent reduces reluctance. (Real input synthesis, when it lands, will be a separate `.inputMonitoring` grant per `docs/ProtectedAPICallPolicy.md`.)

- [ ] **Step 3: Run the full suite**

```bash
xcodebuild -project TAELMacAgent/TAELMacAgent.xcodeproj \
  -scheme TAELMacAgent -configuration Debug \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test
```

Expected: 15 tests pass. If any fail, STOP — Tasks 2/3/4 are committed together so a failure means one of them needs fixing.

- [ ] **Step 4: Commit Tasks 2 + 3 + 4 as one logical unit**

```bash
git add TAELMacAgent/TAELMacAgent/Permissions/PermissionKind.swift \
        TAELMacAgent/TAELMacAgent/Permissions/PermissionsChecker.swift \
        TAELMacAgent/TAELMacAgentTests/HotkeyHandlerTests.swift \
        TAELMacAgent/TAELMacAgent/HUD/PermissionGateView.swift
git commit -m "feat(perms): real Accessibility permission flow

PermissionKind.accessibility.isImplemented flips from false to true.
PermissionsChecker.accessibilityStatus() calls AXIsProcessTrusted()
to read the current trust state without prompting; prompting stays
the gate UI's job per docs/ProtectedAPICallPolicy.md.

PermissionGateView's .accessibility copy updates from 'Not yet
implemented' to a real explanation that calls out read-only intent —
the synthesis path is a separate .inputMonitoring grant.

HotkeyHandlerTests' .notImplemented → .restricted test was using
.accessibility (since it was unimplemented in PR 1). Swap to
.microphone, which stays placeholder until Week 3.

After this PR, calling permissionsGate.withPermission(.accessibility)
gates against the real OS state instead of throwing .notImplemented.
No actual AX read happens yet — that's PR 5."
```

---

## Tests

### Task 5: Add `PermissionsChecker.accessibility` tests

**Files:**

- Modify: `TAELMacAgent/TAELMacAgentTests/PermissionsGateTests.swift` — OR create `TAELMacAgent/TAELMacAgentTests/PermissionsCheckerTests.swift` if there's no existing `Checker`-specific test file. Read both directories first to decide.

**Why:** the `PermissionsCheckerTests.swift` (or equivalent) needs a test for the new `.accessibility` path. The check is hard to fully mock — `AXIsProcessTrusted()` is a global C API not parameterizable per-process. But we can at least verify:

1. The checker returns either `.granted` or `.notDetermined` for `.accessibility` (never crashes, never returns a different value).
2. The checker's behavior matches whatever the OS reports for the test process.

CI test runs likely return `.notDetermined` (xcodebuild test on a CI runner is not in the Accessibility allow-list). Local dev runs may return `.granted` if the developer added Xcode/`xctest` to Accessibility for unrelated reasons. So the assertion has to accept both.

- [ ] **Step 1: Find or create the test file**

```bash
find TAELMacAgent/TAELMacAgentTests -name "*Checker*" -o -name "*PermissionsChecker*"
```

If a file exists, add the test there. If not, create `TAELMacAgent/TAELMacAgentTests/PermissionsCheckerTests.swift`.

- [ ] **Step 2: Write the test**

Add this test to whichever file Step 1 picked:

```swift
func test_status_forAccessibility_returnsGrantedOrNotDetermined() async {
    let checker = PermissionsChecker()
    let status = await checker.status(for: .accessibility)
    XCTAssertTrue(
        status == .granted || status == .notDetermined,
        "Accessibility status must be either .granted or .notDetermined; got \(status). The checker must never return .denied or .restricted for AX since AXIsProcessTrusted only distinguishes trusted/not-trusted."
    )
}
```

Why this assertion shape: `AXIsProcessTrusted()` returns `Bool`, not a four-way TCC enum, so we map `true` to `.granted` and `false` to `.notDetermined`. The test pins that mapping — if a future refactor maps `false` to `.denied` instead, this test catches it.

If you created a new test file, mirror the existing test class structure:

```swift
//
//  PermissionsCheckerTests.swift
//  TAELMacAgentTests
//

import XCTest
@testable import TAELMacAgent

@MainActor
final class PermissionsCheckerTests: XCTestCase {
    // ... test method here ...
}
```

- [ ] **Step 3: Add the test file to the Xcode project (maestro only)**

If a new file was created, registration in `project.pbxproj` is required. Maestro mirrors the pattern used for `HotkeyManagerTests.swift` in PR 3 (4 entries: PBXBuildFile, PBXFileReference, PBXGroup `TAELMacAgentTests` children, PBXSourcesBuildPhase test target). Generate two fresh UUIDs:

```bash
openssl rand -hex 12 | tr 'a-f' 'A-F' && openssl rand -hex 12 | tr 'a-f' 'A-F'
```

Insert the 4 entries by reading the corresponding sections in `project.pbxproj` and using `Edit` with `old_string`/`new_string` blocks anchored to `HotkeyManagerTests`-style entries.

- [ ] **Step 4: Run the full suite**

```bash
xcodebuild -project TAELMacAgent/TAELMacAgent.xcodeproj \
  -scheme TAELMacAgent -configuration Debug \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test
```

Expected: 16 tests pass (15 prior + 1 new accessibility checker test).

- [ ] **Step 5: Commit**

```bash
git add TAELMacAgent/TAELMacAgentTests/PermissionsCheckerTests.swift \
        TAELMacAgent/TAELMacAgent.xcodeproj/project.pbxproj
git commit -m "test(perms): pin AXIsProcessTrusted → granted/notDetermined mapping

PermissionsChecker.status(for: .accessibility) maps AXIsProcessTrusted
true to .granted and false to .notDetermined. AXIsProcessTrusted
returns Bool, so .denied and .restricted are not reachable through
this path. Test asserts the value is one of those two and never the
other two."
```

(Adjust `git add` if Task 5 added the test to an existing file rather than creating a new one — drop the pbxproj path in that case.)

---

## Documentation

### Task 6: Update `docs/ProtectedAPICallPolicy.md` and `docs/PermissionNotes.md`

**Files:**

- Modify: `docs/ProtectedAPICallPolicy.md`
- Modify: `docs/PermissionNotes.md`

**Why:** the policy doc has a row that says Accessibility is "Future. Enum placeholder only; no real check yet." After PR-4, that's wrong. PermissionNotes (if it has milestone-tracking content) needs the same update.

- [ ] **Step 1: Flip the Accessibility row in the policy table**

In `docs/ProtectedAPICallPolicy.md`, find the table row for Accessibility:

```markdown
| Accessibility tree | `AXUIElement*`, `AXObserver*` | Accessibility | Future. Enum placeholder only; no real check yet. |
```

Replace the rightmost cell:

```markdown
| Accessibility tree | `AXUIElement*`, `AXObserver*` | Accessibility | **Active (PR 4)** — gated through `PermissionsGate` with `.accessibility`. PR 4 lands the permission check (`AXIsProcessTrusted`); the actual AX tree read lands in PR 5. |
```

If the surrounding text says "For PR 1, only Screen Recording is active. The rest are future policy entries...", update that paragraph too:

> "For PR 4, Screen Recording and Accessibility are active. Microphone, Apple Events, and Input Monitoring remain future policy entries — their enum cases exist (so the gate has a complete vocabulary) but `PermissionsChecker` does not query them, and no service consumes their grants yet."

- [ ] **Step 2: Update `docs/PermissionNotes.md` if it has a Status table**

Read `docs/PermissionNotes.md`. If there's a per-kind status table or a "what's wired" section, flip Accessibility from placeholder to active. If it's narrative-only and AX isn't called out, no change needed.

- [ ] **Step 3: Commit**

```bash
git add docs/ProtectedAPICallPolicy.md docs/PermissionNotes.md
git commit -m "docs(perms): mark Accessibility permission as active in PR 4

ProtectedAPICallPolicy.md flips the Accessibility row from 'Future.
Enum placeholder only' to 'Active (PR 4) — gated through
PermissionsGate'. AX tree read itself remains future (PR 5).
PermissionNotes.md updated to match."
```

---

## Wrap up (maestro only)

### Task 7: Open the PR

**Files:** none (orchestration)

**Why maestro-only:** `gh pr create` writes to GitHub.

- [ ] **Step 1: Run the full clean test suite**

```bash
xcodebuild -project TAELMacAgent/TAELMacAgent.xcodeproj \
  -scheme TAELMacAgent -configuration Debug \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO clean test
```

Expected: 16 tests pass.

- [ ] **Step 2: Confirm the branch state**

```bash
git log origin/develop..HEAD --oneline
```

Expected: 3 commits — one for the perms flip + test swap (Tasks 2/3/4), one for the new accessibility checker test (Task 5), one for docs (Task 6).

- [ ] **Step 3: Push and open the PR**

```bash
git push origin feature/pr4-accessibility-permission-gate
gh pr create --base develop --head feature/pr4-accessibility-permission-gate \
  --title "feat: PR 4 — Accessibility permission gate (Week 2 part 1)" \
  --body "$(cat <<'EOF'
## Summary

Lands the AX permission flow as the foundation for Week 2 (focused-window context). Plan: `docs/superpowers/plans/2026-04-26-pr4-accessibility-permission-gate.md`.

After this PR, calling `permissionsGate.withPermission(.accessibility) { ... }` gates against the real OS state. No AX tree read happens yet — that's PR 5.

## What's in

- **`PermissionKind.accessibility.isImplemented` flips to `true`** — gate stops short-circuiting with `.notImplemented` for AX.
- **`PermissionsChecker.accessibilityStatus()`** — calls `AXIsProcessTrusted()` (no-prompt variant); returns `.granted` for trusted, `.notDetermined` otherwise. Prompting stays the gate UI's job per `docs/ProtectedAPICallPolicy.md`.
- **Updated `PermissionGateView` copy for `.accessibility`** — replaces "Not yet implemented" with a real explanation that calls out read-only intent.
- **Test fixup** — PR-3's `.notImplemented` test was using `.accessibility` to exercise the unimplemented branch; swapped to `.microphone` since AX is now implemented.
- **New test** for the `AXIsProcessTrusted` → `.granted`/`.notDetermined` mapping.
- **`ProtectedAPICallPolicy.md`** flips the AX row from "Future" to "Active (PR 4)".

## Test plan

- [x] `xcodebuild ... clean test` — 16 tests, 0 failures.
- [ ] Manual: with TAEL not yet in System Settings → Privacy & Security → Accessibility, call `await permissionsGate.withPermission(.accessibility) { _ in }` from a debug menu (no menu item lands in PR 4 — verify via the next hotkey-driven flow once PR 5 wires it). Expected: gate UI appears with the new copy and the "Open System Settings" deep link routes to the AX pane.
- [ ] Manual: grant TAEL accessibility in System Settings, relaunch, retry the same call. Expected: gate UI does NOT appear; the closure runs.

## Out of scope

- AX tree reading, `AXService` (PR 5)
- Focused-window metadata (PR 5)
- Context bundle v0 (PR 5 or PR 6)
- Microphone, Apple Events, Input Monitoring permission flows (their own milestone weeks)
EOF
)"
```

Expected: PR URL printed.

---

## Self-review checklist

**1. Spec coverage:**

- v0.3 §12.3 deliverable "AX permission gate" — covered by Task 2 + Task 3.
- v0.3 §23.0 ("Accessibility... not real checks until their milestones") — Task 2 + Task 3 cross the milestone boundary correctly.
- v0.3 §12.3 deliverable "missing AX permission handled" — covered by the existing `PermissionsGate` + `PermissionGateView` machinery (no new code needed).
- v0.3 §12.3 deliverables NOT in this PR (frontmost app detection, focused window title, AX tree dump, context bundle v0, local debug JSON) — explicit "Out of scope" callout. PR-5.

**2. Placeholder scan:** No "TBD", "implement later" patterns. Each step has concrete code or commands.

**3. Type consistency:**

- `PermissionKind.accessibility` stays the same enum case; only `isImplemented` flips.
- `PermissionsChecker.status(for:)` signature unchanged.
- `PermissionGateView` signature unchanged; only the copy strings inside `explanation` switch change.
- `HotkeyHandlerTests` preserves the test's name; only the kind argument flips.

**4. Test count progression:** PR-3 left the suite at 15. Task 5 adds 1 → 16. PR title and commit messages match.

**5. Branch model alignment:** Feature branch off `develop`, single PR back into `develop`. Pre-condition: PR #19 merged or branch off PR-3's tip with rebase intent.

**6. Breaking-change concern:** flipping `PermissionKind.accessibility.isImplemented` is a behavior change for any downstream code that branched on this. The only such caller today is the test in PR-3 (Task 4 fixes it). No production code depends on `.isImplemented` of `.accessibility` returning `false`.

---

## Notes for the executor

- **Tasks 1 + 7 are maestro-only** for the same reasons as PR-2 / PR-3: branch creation pushes to origin, PR creation hits GitHub.
- **Sandbox commit pattern:** unchanged from PR-3. Codex applies edits + reports diff; maestro stages, runs `xcodebuild test`, commits.
- **Tasks 2/3/4 commit together:** the plan deliberately bundles them because an intermediate commit (e.g. flipping `isImplemented` without updating the test) would leave the suite red.
- **No new pbxproj work for Tasks 2-4:** they only modify existing files. Task 5 may add a new test file, in which case maestro does the 4-entry pbxproj registration with mirroring (same pattern as `HotkeyManagerTests` in PR-3).
- **`AXIsProcessTrusted()` vs `AXIsProcessTrustedWithOptions(nil)`:** functionally identical. The plan uses the simpler no-arg version. If a future need arises for the prompting variant, it goes in the gate UI (the user's "Open System Settings" path), NOT in the checker.
- **CI/local divergence on Task 5's test:** the test allows both `.granted` and `.notDetermined` because the result depends on whether the test process is trusted by AX. CI runners are not; local dev machines may or may not be. Don't tighten the assertion to one specific value.
- **Why not bundle PR-5's AXService into PR-4:** PR-5 introduces a new service, new types, and is the first time we're actually consuming an AX grant. That's the natural review surface for AX-as-a-feature. PR-4 is intentionally narrow so reviewers can verify the permission flow without wading through tree-read logic.
