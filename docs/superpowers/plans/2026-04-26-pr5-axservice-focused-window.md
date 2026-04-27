# PR 5 — Week 2 part 2: AXService + focused-window metadata

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans`. Steps use checkbox (`- [ ]`) syntax. **Project-specific:** "subagent" maps to Codex via the `agent-codex:codex` skill; Claude Opus 4.7 reviews each commit. Tasks 1 (branch + push) and 8 (PR creation) are maestro-only because Codex's sandbox blocks `.git` writes and `gh` writes.

**Goal:** Add focused-window context to the heartbeat. After PR-5, a hotkey invocation captures both a screenshot AND focused-window metadata (frontmost app bundle ID + name, focused window title + role) bundled into a single `ContextBundle` value. The HUD renders both. PR-4's AX permission gate now actually does work — `withPermission(.accessibility)` grants a token that `AXService` consumes.

**Architecture:** `AXService` (parallel to `ScreenCaptureService`) reads window metadata via Accessibility APIs, gated by the same `PermissionGrant` token pattern. A `FocusedWindowReading` protocol mirrors `DisplayScreenshotCapturing` for test substitution. A new `ContextBundle` value type wraps `(screenshot: CapturedScreenshot?, window: FocusedWindowMetadata?)` — both optional because either one may fail without taking down the other (graceful degradation). `HotkeyInvocationHandler` runs both reads in parallel via `async let` and presents the bundle.

**Tech stack:** Swift 5.10, ApplicationServices framework (`AXUIElementCreateApplication`, `AXUIElementCopyAttributeValue`, `kAXFocusedWindowAttribute`, `kAXTitleAttribute`, `kAXRoleAttribute`), AppKit (`NSWorkspace.shared.frontmostApplication`), SwiftUI for the HUD additions, XCTest. No new SPM dependencies.

**Spec sources:** `TAEL_AI_mac_agent_build_plan_v0_3.md` §12.3 deliverables: "frontmost app detection, focused window title, bundle ID" — all in PR-5. The "AX tree dump" deliverable is intentionally deferred to PR-6.

**Out of scope:**

- AX tree dump (`kAXChildrenAttribute` walk + trimming) — PR-6
- Local debug JSON dump of the bundle — PR-6 or later
- Voice / WhisperKit (Week 3)
- Planner adapter (Week 4)
- Per-app bundle-ID allowlist for AX reads (PR-7+)
- Sandboxed apps that do not expose AX metadata (handled gracefully — return `nil` window, do not crash)

---

## Pre-flight

### Task 1: Branch off develop (autopilot writes the plan first; later cycles execute)

**Files:** none

**Why maestro/autopilot only:** The plan file lands as the first commit on `feature/pr5-axservice-focused-window`. Subsequent cycles execute Tasks 2-8 against that branch.

- [x] **Step 1: Branch and commit the plan** (this cycle)

```bash
git checkout develop && git pull origin develop && \
  git checkout -b feature/pr5-axservice-focused-window
# The plan file lands as the first commit; tasks below run in subsequent cycles.
```

---

## New types

### Task 2: `FocusedWindowMetadata` value type

**Files:**

- Create: `TAELMacAgent/TAELMacAgent/Capture/FocusedWindowMetadata.swift`

**Why:** structured carrier for window context. Optional fields because AX may report any subset depending on app state (sandboxed apps, hidden windows, etc.).

- [ ] **Step 1: Create the file**

```swift
//
//  FocusedWindowMetadata.swift
//  TAELMacAgent
//
//  Snapshot of the frontmost app's focused window taken alongside
//  the screenshot during a hotkey invocation. All fields optional
//  because AX availability varies by app, sandbox, and visibility.
//

import Foundation

public struct FocusedWindowMetadata: Equatable, Sendable {
    public let appBundleID: String?
    public let appName: String?
    public let windowTitle: String?
    public let windowRole: String?
    public let capturedAt: Date

    public init(
        appBundleID: String?,
        appName: String?,
        windowTitle: String?,
        windowRole: String?,
        capturedAt: Date = Date()
    ) {
        self.appBundleID = appBundleID
        self.appName = appName
        self.windowTitle = windowTitle
        self.windowRole = windowRole
        self.capturedAt = capturedAt
    }

    /// True iff at least one field beyond capturedAt is populated.
    public var hasAnyData: Bool {
        appBundleID != nil || appName != nil || windowTitle != nil || windowRole != nil
    }
}
```

- [ ] **Step 2: Build, no test yet** (the type is exercised by Task 4)

```bash
xcodebuild -project TAELMacAgent/TAELMacAgent.xcodeproj \
  -scheme TAELMacAgent -configuration Debug \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```

- [ ] **Step 3: Commit**

```bash
git add TAELMacAgent/TAELMacAgent/Capture/FocusedWindowMetadata.swift \
        TAELMacAgent/TAELMacAgent.xcodeproj/project.pbxproj
git commit -m "feat(capture): FocusedWindowMetadata value type

Snapshot of the frontmost app's focused window — bundle ID, app name,
window title, window role, capturedAt. All optional because AX
availability varies by app/sandbox/visibility."
```

(The maestro registers the new file in pbxproj manually with mirroring edits — same pattern as PR-3's HotkeyManagerTests and PR-4's PermissionsCheckerTests.)

---

### Task 3: `ContextBundle` and `FocusedWindowReading` protocol

**Files:**

- Modify: `TAELMacAgent/TAELMacAgent/Capture/ScreenCaptureService.swift` (add the protocol next to `DisplayScreenshotCapturing`)
- Create: `TAELMacAgent/TAELMacAgent/Capture/ContextBundle.swift`

**Why:** the protocol lets tests inject a fake AX reader; `ContextBundle` is what the handler returns and what the HUD renders.

- [ ] **Step 1: Add `FocusedWindowReading` protocol**

In `ScreenCaptureService.swift` (or a co-located new file — keep it next to `DisplayScreenshotCapturing` so the testability surface lives together), add:

```swift
public protocol FocusedWindowReading: Sendable {
    func readFocusedWindow(_ grant: PermissionGrant) async throws -> FocusedWindowMetadata
}
```

- [ ] **Step 2: Create `ContextBundle.swift`**

```swift
//
//  ContextBundle.swift
//  TAELMacAgent
//
//  What a single hotkey invocation captures. PR-5 has screenshot +
//  focused-window metadata; PR-6 will add AX tree dump.
//

import Foundation

public struct ContextBundle: Equatable, Sendable {
    public let screenshot: CapturedScreenshot?
    public let window: FocusedWindowMetadata?
    public let capturedAt: Date

    public init(
        screenshot: CapturedScreenshot?,
        window: FocusedWindowMetadata?,
        capturedAt: Date = Date()
    ) {
        self.screenshot = screenshot
        self.window = window
        self.capturedAt = capturedAt
    }
}
```

`CapturedScreenshot` may not yet conform to `Equatable` (it carries a `CGImage` which doesn't). If the build fails at the `Equatable` synthesis, drop `Equatable` from `ContextBundle` and use a custom comparison helper if needed in tests. Treat this as a real possibility, not a maybe — verify on build.

- [ ] **Step 3: Build + commit**

```bash
xcodebuild -project TAELMacAgent/TAELMacAgent.xcodeproj \
  -scheme TAELMacAgent -configuration Debug \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```

```bash
git add TAELMacAgent/TAELMacAgent/Capture/ScreenCaptureService.swift \
        TAELMacAgent/TAELMacAgent/Capture/ContextBundle.swift \
        TAELMacAgent/TAELMacAgent.xcodeproj/project.pbxproj
git commit -m "feat(capture): ContextBundle + FocusedWindowReading protocol"
```

---

## Real AX read

### Task 4: `AXService` implementing `FocusedWindowReading`

**Files:**

- Create: `TAELMacAgent/TAELMacAgent/Capture/AXService.swift`

**Why:** the production reader. Asserts `grant.kind == .accessibility` (mirroring how `ScreenCaptureService` asserts `.screenRecording`).

- [ ] **Step 1: Create the file**

```swift
//
//  AXService.swift
//  TAELMacAgent
//
//  Reads the frontmost app's focused window via Accessibility APIs.
//  Gated through PermissionsGate with the .accessibility kind.
//
//  PR-5: title + role + app bundle/name only. AX tree dump is PR-6.
//

import Foundation
#if canImport(AppKit)
import AppKit
#endif
#if canImport(ApplicationServices)
import ApplicationServices
#endif

public enum AXReadError: Error, Equatable {
    case noFrontmostApp
    case axElementUnavailable
    case attributeFailed(String)
}

public final class AXService: FocusedWindowReading {
    public init() {}

    public func readFocusedWindow(_ grant: PermissionGrant) async throws -> FocusedWindowMetadata {
        precondition(
            grant.kind == .accessibility,
            "AXService requires a .accessibility grant"
        )

        #if os(macOS)
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            throw AXReadError.noFrontmostApp
        }

        let appBundleID = frontApp.bundleIdentifier
        let appName = frontApp.localizedName
        let pid = frontApp.processIdentifier

        let axApp = AXUIElementCreateApplication(pid)
        var focusedWindowRef: CFTypeRef?
        let focusErr = AXUIElementCopyAttributeValue(
            axApp,
            kAXFocusedWindowAttribute as CFString,
            &focusedWindowRef
        )

        guard focusErr == .success, let focusedWindow = focusedWindowRef else {
            // Frontmost app may have no focused window (e.g. menu bar agents).
            // Return what we have without throwing.
            return FocusedWindowMetadata(
                appBundleID: appBundleID,
                appName: appName,
                windowTitle: nil,
                windowRole: nil
            )
        }

        let axWindow = focusedWindow as! AXUIElement

        let title = copyStringAttribute(axWindow, kAXTitleAttribute as CFString)
        let role = copyStringAttribute(axWindow, kAXRoleAttribute as CFString)

        return FocusedWindowMetadata(
            appBundleID: appBundleID,
            appName: appName,
            windowTitle: title,
            windowRole: role
        )
        #else
        throw AXReadError.axElementUnavailable
        #endif
    }

    private func copyStringAttribute(_ element: AXUIElement, _ attr: CFString) -> String? {
        var ref: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(element, attr, &ref)
        guard err == .success else { return nil }
        return ref as? String
    }
}
```

- [ ] **Step 2: Build (no unit test for AXService body — real AX requires real apps + permission)**

```bash
xcodebuild -project TAELMacAgent/TAELMacAgent.xcodeproj \
  -scheme TAELMacAgent -configuration Debug \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```

- [ ] **Step 3: Commit**

```bash
git add TAELMacAgent/TAELMacAgent/Capture/AXService.swift \
        TAELMacAgent/TAELMacAgent.xcodeproj/project.pbxproj
git commit -m "feat(capture): AXService reads focused-window metadata

Implementation of FocusedWindowReading using ApplicationServices.
AXUIElementCreateApplication on the frontmost app's pid, then
kAXFocusedWindowAttribute, kAXTitleAttribute, kAXRoleAttribute.

Bundle ID + app name come from NSWorkspace.frontmostApplication. App-
without-focused-window case (menu bar agents) returns metadata with
nil title/role — graceful, not an error.

AX tree dump (kAXChildrenAttribute walk + trimming) is PR-6."
```

---

## Wire into the heartbeat

### Task 5: `HotkeyInvocationHandler` captures both screenshot AND window

**Files:**

- Modify: `TAELMacAgent/TAELMacAgent/App/HotkeyInvocationHandler.swift`
- Modify: `TAELMacAgent/TAELMacAgent/App/AppDelegate.swift`
- Modify: `TAELMacAgent/TAELMacAgentTests/HotkeyHandlerTests.swift`

**Why:** today the handler returns a `CapturedScreenshot`. PR-5 makes it return a `ContextBundle` (screenshot + optional window). Both reads happen in parallel via `async let`. Either failing logs but doesn't take down the other — graceful degradation.

- [ ] **Step 1: Add `axService` and `presentBundle` parameters to the handler**

The struct gains `axService: any FocusedWindowReading` and the `presentScreenshot: (CapturedScreenshot) -> Void` closure becomes `presentBundle: (ContextBundle) -> Void`. Both with sensible defaults (a no-op AX reader and the existing screenshot-presenter as a fallback if `presentBundle` not provided).

Actually — DON'T break the existing test surface in this commit. Add the new parameters with defaults; existing tests keep working. Only the production wire-up at AppDelegate constructs with the real AX service and the bundle presenter.

- [ ] **Step 2: Inside `run()`, parallelize**

```swift
async let screenshotResult: CapturedScreenshot? = (try? await captureScreenshotPath())
async let windowResult: FocusedWindowMetadata? = (try? await captureWindowPath())

let screenshot = await screenshotResult
let window = await windowResult

let bundle = ContextBundle(screenshot: screenshot, window: window)
presentBundle(bundle)
```

(This is sketch — actual implementation needs to keep gate latencies recorded per InvocationLog. Decide: record two latency rows or one combined? Recommendation: one combined row with `gateLatencyMs`/`captureLatencyMs` capturing the LONGER of the two paths plus a new `axLatencyMs` field. That's an InvocationLog schema bump — flag for explicit decision in this task.)

- [ ] **Step 3: Update `AppDelegate` to construct with `axService: AXService()` and `presentBundle:` closure**

- [ ] **Step 4: Add test that exercises the parallel paths**

`SpyAXReader` actor returns a stub `FocusedWindowMetadata`. Test asserts that the bundle has BOTH screenshot and window populated on the granted path; AX-failure path produces a bundle with `screenshot != nil, window == nil` and a log row noting the AX failure.

- [ ] **Step 5: Build, run full suite, commit**

Expected: 17+ tests pass (existing 16 plus new bundle-path test).

---

## HUD rendering

### Task 6: `HUDScreenshotView` becomes `HUDBundleView` (or similar)

**Files:**

- Rename or modify: `TAELMacAgent/TAELMacAgent/HUD/HUDScreenshotView.swift`
- Modify: `TAELMacAgent/TAELMacAgent/HUD/HUDPanelController.swift`

**Why:** the HUD now renders both screenshot and window context. Decision: rename `HUDScreenshotView` → `HUDBundleView` and update to take a `ContextBundle`, OR keep `HUDScreenshotView` and add a new `HUDBundleView` that composes screenshot + window. **Recommendation:** rename. The screenshot-only HUD never appears in production after this PR.

- [ ] **Step 1: Rewrite the view**

```swift
struct HUDBundleView: View {
    let bundle: ContextBundle

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let win = bundle.window, win.hasAnyData {
                HStack(spacing: 6) {
                    Text(win.appName ?? win.appBundleID ?? "Unknown app")
                        .font(.caption.bold())
                    if let title = win.windowTitle {
                        Text("— \(title)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            if let shot = bundle.screenshot {
                Text("Captured \(shot.width)×\(shot.height) — \(targetLabel(shot.target))")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Image(decorative: shot.image, scale: 1.0, orientation: .up)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 720, maxHeight: 480)
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(6)
            } else {
                Text("Screenshot unavailable")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(16)
    }

    private func targetLabel(_ target: ScreenshotTarget) -> String {
        switch target {
        case .displayContainingCursor: return "cursor display"
        case .mainDisplay:             return "main display (fallback)"
        }
    }
}
```

- [ ] **Step 2: `HUDPanelController.present(screenshot:)` becomes `present(bundle:)`**

Update call sites in `AppDelegate` and `HotkeyInvocationHandler`.

- [ ] **Step 3: Manual verify (no unit test for SwiftUI view)**

- [ ] **Step 4: Commit**

---

## Documentation

### Task 7: Update `docs/Architecture.md`, `docs/Week1Heartbeat.md`, `docs/PermissionNotes.md`

**Files:**

- Modify: `docs/Architecture.md` — add the AXService + ContextBundle to the diagram
- Modify: `docs/Week1Heartbeat.md` — note that PR-5 extends the heartbeat to a context bundle (Week 2 territory now, but the heartbeat doc should acknowledge it)
- Modify: `docs/PermissionNotes.md` — Accessibility section gains a "PR 5: actual reads" note

- [ ] **Step 1: Edit each file**
- [ ] **Step 2: Commit**

---

## Wrap up (maestro only)

### Task 8: Open the PR

**Files:** none (orchestration)

- [ ] **Step 1: Final clean test run** — `xcodebuild ... clean test`. Expected: 17+ tests pass.
- [ ] **Step 2: Push** — `git push origin feature/pr5-axservice-focused-window`
- [ ] **Step 3: Open PR** with body summarizing what's in PR-5 and what's deferred to PR-6.

---

## Self-review checklist

**1. Spec coverage:**

- v0.3 §12.3 deliverables in PR-5: frontmost app detection ✓ (`NSWorkspace.frontmostApplication`), focused window title ✓ (`kAXTitleAttribute`), bundle ID ✓.
- Deferred: AX tree dump (PR-6), local debug JSON (PR-6 or later), context bundle UX iterations (post-Week 2).

**2. Type consistency:**

- `FocusedWindowMetadata` is a value type, mirrors `CapturedScreenshot`'s shape.
- `FocusedWindowReading` mirrors `DisplayScreenshotCapturing` (test-substitutable, takes `PermissionGrant`).
- `AXService` asserts `.accessibility` grant kind via `precondition`, mirroring `ScreenCaptureService`'s `.screenRecording` precondition.
- `ContextBundle` may need to drop `Equatable` if `CapturedScreenshot` doesn't synthesize it — flagged in Task 3.

**3. Failure-mode coverage:**

- AX-disabled or no-frontmost-app: returns a metadata with everything but `appBundleID`/`appName` nil, doesn't throw.
- Screenshot fails but AX succeeds: bundle has `screenshot=nil, window=metadata`.
- Both fail: bundle has both nil, presented HUD shows "Screenshot unavailable" (already there) and just no window header.

**4. Test count progression:** PR-4 left the suite at 16. Task 5 adds 1+ → 17 minimum. PR title and commit messages reflect.

**5. Branch model alignment:** Feature branch off `develop`, single PR back into `develop`.

---

## Notes for the executor

- **Tasks 1 + 8 are maestro/autopilot-only** — branch creation pushes to origin, PR creation hits GitHub. Codex's sandbox can't do either.
- **`async let` parallelization** — `screenshotResult` and `windowResult` run concurrently. The handler must `await` both before constructing the bundle. Make sure both run on the MainActor (the handler is `@MainActor`).
- **Two PermissionGrants in one invocation** — this is the first time the handler needs grants from two different kinds (`.screenRecording` AND `.accessibility`). Two separate `withPermission` calls, NOT a single multi-kind call. The gate enforces one grant per call site.
- **InvocationLog schema bump** — adding `axLatencyMs` and `axOutcome` fields probably needs to land in PR-5. Decide explicitly: extend `InvocationLog` in this PR, or do it as a small precursor commit.
- **Equatable conformance landmines** — `CapturedScreenshot` carries a `CGImage`. If you put it inside an `Equatable` struct, the compiler may not synthesize. Drop `Equatable` from `ContextBundle` if so.
- **Manual verification gate** — Task 4 (AXService) and Task 6 (HUDBundleView) cannot be unit-tested end-to-end. Manual matrix should add at least: PR-5.1 (focused window title appears in HUD when invoked from VS Code), PR-5.2 (bundle ID appears for sandboxed apps like Safari), PR-5.3 (menu-bar agent has nil window title but app name still appears).
