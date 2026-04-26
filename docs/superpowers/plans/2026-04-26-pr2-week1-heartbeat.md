# PR 2 — Week 1 Heartbeat Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans`. Steps use checkbox (`- [ ]`) syntax. **Project-specific:** "subagent" maps to Codex via the `agent-codex:codex` skill; Claude Opus 4.7 reviews each commit. Tasks 1 (SPM dep) and 11 (PR creation) are maestro-only because Codex's sandbox blocks network and `gh` writes.

**Goal:** Ship the Week 1 heartbeat — `global hotkey → PermissionsGate → SCScreenshotManager → non-activating NSPanel HUD with screenshot PNG`. This is the loop v0.3 §1 calls "the first product heartbeat."

**Architecture:** Replace PR 1's typed stubs with real implementations. Add `KeyboardShortcuts` SPM dependency. Wire `AppDelegate` so the hotkey closure runs `permissionsGate.withPermission(.screenRecording) { grant in screenCaptureService.captureDisplayScreenshot(grant) }` and presents the result via `HUDPanelController`. Introduce a thin `DisplayScreenshotCapturing` protocol so the wire-up is unit-testable without TCC. Populate `LocalLogService` per invocation with `InvocationLog` rows including latency.

**Tech stack:** Swift 5.10, ScreenCaptureKit (`SCShareableContent`, `SCContentFilter`, `SCStreamConfiguration`, `SCScreenshotManager.captureImage(contentFilter:configuration:)`), KeyboardShortcuts package (`sindresorhus/KeyboardShortcuts`), AppKit + SwiftUI, XCTest, XcodeGen for SPM dep regen, macOS 14.0+, Xcode 16+.

**Spec sources:** `TAEL_AI_mac_agent_build_plan_v0_3.md` §12.2 (Week 1 milestone), §23.10 (ScreenCaptureKit notes), §23.11 (HUD defaults), §23.5 first-13 tickets 6–11.

---

## Pre-flight

### Task 0: Branch off develop

**Files:** none

- [ ] **Step 1: Sync develop and create feature branch**

```bash
git checkout develop && git pull origin develop && \
  git checkout -b feature/pr2-week1-heartbeat && \
  git push -u origin feature/pr2-week1-heartbeat
```

Expected: `Switched to a new branch 'feature/pr2-week1-heartbeat'`, branch tracks origin.

---

## Add the SPM dependency (maestro only)

### Task 1: Add `KeyboardShortcuts` SPM dependency via XcodeGen

**Files:**

- Modify: `TAELMacAgent/project.yml`
- Modify (regenerated): `TAELMacAgent/TAELMacAgent.xcodeproj/project.pbxproj`
- Modify (created by Xcode/SPM resolve): `TAELMacAgent/TAELMacAgent.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`

**Why maestro-only:** SPM resolution needs network access; Codex's `workspace-write` sandbox blocks outbound requests. Also, `xcodegen` may not be in Codex's PATH. Maestro runs this; Codex resumes from Task 2.

- [ ] **Step 1: Add packages and dependency to `project.yml`**

In `TAELMacAgent/project.yml`, after the `options:` block and before `settings:`, add:

```yaml
packages:
  KeyboardShortcuts:
    url: https://github.com/sindresorhus/KeyboardShortcuts
    from: "2.0.0"
```

Then in the `targets.TAELMacAgent` block, add a `dependencies` key:

```yaml
  TAELMacAgent:
    type: application
    platform: macOS
    deploymentTarget: "14.0"
    dependencies:
      - package: KeyboardShortcuts
    sources:
      - path: TAELMacAgent
        excludes:
          - "Resources/Info.plist"
          - "Resources/TAELMacAgent.entitlements"
```

- [ ] **Step 2: Confirm xcodegen is installed**

```bash
command -v xcodegen >/dev/null && echo OK || brew install xcodegen
```

Expected: `OK`, or `xcodegen` installed via Homebrew.

- [ ] **Step 3: Regenerate `.xcodeproj`**

```bash
make xcodeproj
```

Expected: XcodeGen prints `Created project at ...TAELMacAgent.xcodeproj`. The pbxproj will now include the package reference, product dependency, and Frameworks build phase entry.

- [ ] **Step 4: Resolve SPM dependencies**

```bash
xcodebuild -project TAELMacAgent/TAELMacAgent.xcodeproj -resolvePackageDependencies
```

Expected: `Resolved source packages`. Creates/updates `Package.resolved`.

- [ ] **Step 5: Build to confirm KeyboardShortcuts links cleanly**

```bash
xcodebuild -project TAELMacAgent/TAELMacAgent.xcodeproj \
  -scheme TAELMacAgent -configuration Debug \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```

Expected: BUILD SUCCEEDED. No source code uses `KeyboardShortcuts` yet, but the link should succeed.

- [ ] **Step 6: Commit**

```bash
git add TAELMacAgent/project.yml \
        TAELMacAgent/TAELMacAgent.xcodeproj/project.pbxproj \
        TAELMacAgent/TAELMacAgent.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved
git commit -m "chore(deps): add KeyboardShortcuts SPM package

sindresorhus/KeyboardShortcuts at >= 2.0.0. Used in PR 2 to register
the global hotkey via Carbon HotKey APIs. No source code yet uses it;
the wire-up lands in Task 6.

Regenerated pbxproj via 'make xcodeproj' (XcodeGen)."
```

---

## Testability seam

### Task 2: Define `DisplayScreenshotCapturing` protocol and conform `ScreenCaptureService`

**Files:**

- Modify: `TAELMacAgent/TAELMacAgent/Capture/ScreenCaptureService.swift`

**Why:** the hotkey wire-up in Task 6 needs to be unit-testable, but the real `ScreenCaptureService` requires TCC Screen Recording grant. A thin protocol lets Task 7's tests inject a mock without touching ScreenCaptureKit. **Do NOT pull the type into a separate file** — keep it co-located with the service per the same file-locality principle that protects `PermissionGrant` from forgery (the protocol+default is the public surface; the implementation stays one read away).

- [ ] **Step 1: Add the protocol declaration above `ScreenCaptureService`**

In `TAELMacAgent/TAELMacAgent/Capture/ScreenCaptureService.swift`, after the imports and existing `ScreenCaptureError` enum, add:

```swift
/// Minimal protocol the hotkey/wiring layer depends on. Lets tests
/// inject a mock that returns a synthetic `CapturedScreenshot` without
/// pulling in ScreenCaptureKit or requiring a real TCC grant.
public protocol DisplayScreenshotCapturing: Sendable {
    func captureDisplayScreenshot(
        _ grant: PermissionGrant,
        target: ScreenshotTarget
    ) async throws -> CapturedScreenshot
}
```

- [ ] **Step 2: Conform `ScreenCaptureService` and remove the default-arg duplication**

The existing `captureDisplayScreenshot` already has a default `target: ScreenshotTarget = .week1Default`. Move that default to the protocol via a default-implementation extension:

```swift
public extension DisplayScreenshotCapturing {
    func captureDisplayScreenshot(_ grant: PermissionGrant) async throws -> CapturedScreenshot {
        try await captureDisplayScreenshot(grant, target: .week1Default)
    }
}
```

Then update the `ScreenCaptureService` class declaration:

```swift
public final class ScreenCaptureService: DisplayScreenshotCapturing {
    public init() {}

    public func captureDisplayScreenshot(
        _ grant: PermissionGrant,
        target: ScreenshotTarget
    ) async throws -> CapturedScreenshot {
        precondition(
            grant.kind == .screenRecording,
            "ScreenCaptureService requires a .screenRecording grant"
        )

        // Body still throws .notImplemented in this task; Task 3 fills
        // in the real ScreenCaptureKit path.
        throw ScreenCaptureError.notImplemented
    }
}
```

- [ ] **Step 3: Build and test**

```bash
xcodebuild -project TAELMacAgent/TAELMacAgent.xcodeproj \
  -scheme TAELMacAgent -configuration Debug \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test
```

Expected: BUILD SUCCEEDED, all 8 existing tests still pass. The protocol extraction is a refactor — behavior is unchanged.

- [ ] **Step 4: Commit**

```bash
git add TAELMacAgent/TAELMacAgent/Capture/ScreenCaptureService.swift
git commit -m "refactor(capture): extract DisplayScreenshotCapturing protocol

Thin protocol with a default implementation that supplies
target = .week1Default. Lets the hotkey wire-up tests inject a mock
without pulling in ScreenCaptureKit or requiring a TCC grant.
Type stays co-located with the service per file-locality discipline."
```

---

## Real ScreenCaptureKit capture

### Task 3: Replace `notImplemented` stub with real `SCScreenshotManager` capture

**Files:**

- Modify: `TAELMacAgent/TAELMacAgent/Capture/ScreenCaptureService.swift`

**Why:** ticket 8. Replace the stub body. The PR 2 outline comment in the file already describes the shape; this task fills it in.

**Why no unit test for this body:** real screen capture requires TCC Screen Recording permission, which CI (and Codex's sandbox) cannot grant. Manual verification via `make run` after Task 6 is the gate. The Task 7 wire-up tests use the mock from Task 2.

- [ ] **Step 1: Add ScreenCaptureKit + AppKit imports**

At the top of `TAELMacAgent/TAELMacAgent/Capture/ScreenCaptureService.swift`:

```swift
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
#if canImport(ScreenCaptureKit)
import ScreenCaptureKit
#endif
#if canImport(AppKit)
import AppKit
#endif
```

- [ ] **Step 2: Add display resolution helper**

After the `DisplayScreenshotCapturing` extension, before the `ScreenCaptureService` class, add:

```swift
/// Resolves the target display per v0.3 §23.2: cursor display first,
/// fallback to main display, fallback to the first available display.
/// Returns the resolved `(SCDisplay, ScreenshotTarget)` so the caller
/// knows whether it got the cursor display or fell back.
@available(macOS 14.0, *)
private func resolveTargetDisplay(
    in content: SCShareableContent,
    requested: ScreenshotTarget
) -> (display: SCDisplay, resolved: ScreenshotTarget)? {
    guard !content.displays.isEmpty else { return nil }

    let mainDisplayID = CGMainDisplayID()

    if requested == .displayContainingCursor {
        let cursorPoint = NSEvent.mouseLocation
        if let nsScreen = NSScreen.screens.first(where: { $0.frame.contains(cursorPoint) }),
           let screenNumber = nsScreen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID,
           let display = content.displays.first(where: { $0.displayID == screenNumber })
        {
            return (display, .displayContainingCursor)
        }
    }

    // Fallback path: main display, then first available.
    if let main = content.displays.first(where: { $0.displayID == mainDisplayID }) {
        return (main, .mainDisplay)
    }
    if let first = content.displays.first {
        return (first, .mainDisplay)
    }
    return nil
}
```

- [ ] **Step 3: Replace the stub body**

Replace the current `captureDisplayScreenshot` body in `ScreenCaptureService`:

```swift
    public func captureDisplayScreenshot(
        _ grant: PermissionGrant,
        target: ScreenshotTarget
    ) async throws -> CapturedScreenshot {
        precondition(
            grant.kind == .screenRecording,
            "ScreenCaptureService requires a .screenRecording grant"
        )

        let content: SCShareableContent
        do {
            content = try await SCShareableContent.current
        } catch {
            throw ScreenCaptureError.captureFailed("SCShareableContent.current failed: \(error.localizedDescription)")
        }

        guard let resolved = resolveTargetDisplay(in: content, requested: target) else {
            throw ScreenCaptureError.noDisplaysAvailable
        }

        let display = resolved.display
        let filter = SCContentFilter(display: display, excludingWindows: [])

        let cfg = SCStreamConfiguration()
        let scale = NSScreen.screens
            .first { ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID) == display.displayID }?
            .backingScaleFactor ?? 2.0
        cfg.width = display.width * Int(scale)
        cfg.height = display.height * Int(scale)
        cfg.showsCursor = true
        cfg.queueDepth = 1

        let cgImage: CGImage
        do {
            cgImage = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: cfg
            )
        } catch {
            throw ScreenCaptureError.captureFailed("SCScreenshotManager.captureImage failed: \(error.localizedDescription)")
        }

        return CapturedScreenshot(image: cgImage, target: resolved.resolved)
    }
```

- [ ] **Step 4: Remove the now-unused `.notImplemented` case from the error enum**

Replace:

```swift
public enum ScreenCaptureError: Error, Equatable {
    /// PR 1 placeholder. Removed when ScreenCaptureKit lands in PR 2.
    case notImplemented
    /// `SCShareableContent` returned no displays.
    case noDisplaysAvailable
    /// Underlying ScreenCaptureKit error. Wrapped to keep call sites
    /// independent of the framework.
    case captureFailed(String)
}
```

With:

```swift
public enum ScreenCaptureError: Error, Equatable {
    /// `SCShareableContent` returned no displays.
    case noDisplaysAvailable
    /// Underlying ScreenCaptureKit error. Wrapped to keep call sites
    /// independent of the framework.
    case captureFailed(String)
}
```

- [ ] **Step 5: Build and run existing tests**

```bash
xcodebuild -project TAELMacAgent/TAELMacAgent.xcodeproj \
  -scheme TAELMacAgent -configuration Debug \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test
```

Expected: BUILD SUCCEEDED, all 8 existing tests still pass. The body change is not exercised by any current test (it's the production capture path).

- [ ] **Step 6: Commit**

```bash
git add TAELMacAgent/TAELMacAgent/Capture/ScreenCaptureService.swift
git commit -m "feat(capture): real SCScreenshotManager capture path

Implements v0.3 §23.10 capture contract:
- SCShareableContent.current for available displays
- Cursor-display resolution with mainDisplay fallback (§23.2)
- SCContentFilter + SCStreamConfiguration with explicit width/height
  multiplied by NSScreen backingScaleFactor
- SCScreenshotManager.captureImage(contentFilter:configuration:) —
  the only allowed overload until deployment target moves to 15.2+

Removes ScreenCaptureError.notImplemented (no longer reachable).
Manual verification via 'make run' after Task 6 wires the hotkey."
```

---

## Hotkey integration

### Task 4: Add `KeyboardShortcuts.Name` extension

**Files:**

- Create: `TAELMacAgent/TAELMacAgent/Hotkey/HotkeyName.swift`

**Why:** the KeyboardShortcuts API requires shortcut names declared as `KeyboardShortcuts.Name` static properties. Co-locate the name in its own small file under `Hotkey/` so it's findable.

- [ ] **Step 1: Create the file**

Create `TAELMacAgent/TAELMacAgent/Hotkey/HotkeyName.swift`:

```swift
//
//  HotkeyName.swift
//  TAELMacAgent
//
//  Declares the global hotkey name used by KeyboardShortcuts.
//  Default chord: ⌘⇧T ("T" for TAEL). User can rebind via Settings
//  later (post-PR 2).
//

import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// Primary "summon TAEL" hotkey. v0.3 §1: this triggers the full
    /// hotkey → gate → capture → HUD pipeline.
    static let toggleTAEL = Self(
        "toggleTAEL",
        default: .init(.t, modifiers: [.command, .shift])
    )
}
```

- [ ] **Step 2: Register the new file in the Xcode project**

If the project was regenerated via XcodeGen in Task 1, the new file is picked up automatically by the `sources: - path: TAELMacAgent` glob — no pbxproj edit needed. Confirm by running:

```bash
make xcodeproj
```

If the project was not regenerated (pbxproj edited by hand), Codex/maestro must add the file reference manually following the same pattern used for `LocalLogServiceTests.swift` in PR 1 (PBXBuildFile + PBXFileReference + group + Sources build phase).

- [ ] **Step 3: Build to verify the name compiles**

```bash
xcodebuild -project TAELMacAgent/TAELMacAgent.xcodeproj \
  -scheme TAELMacAgent -configuration Debug \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
git add TAELMacAgent/TAELMacAgent/Hotkey/HotkeyName.swift \
        TAELMacAgent/TAELMacAgent.xcodeproj/project.pbxproj
git commit -m "feat(hotkey): declare KeyboardShortcuts.Name.toggleTAEL

Default chord ⌘⇧T. Used in Task 5 to register the real global hotkey
via KeyboardShortcuts.onKeyDown."
```

---

### Task 5: Replace `HotkeyManager` placeholder with real registration

**Files:**

- Modify: `TAELMacAgent/TAELMacAgent/Hotkey/HotkeyManager.swift`

**Why:** ticket 6. Currently `installPlaceholderBinding()` is a no-op; PR 2 wires it through `KeyboardShortcuts.onKeyDown(for:)`.

- [ ] **Step 1: Replace the file contents**

Replace the entire `TAELMacAgent/TAELMacAgent/Hotkey/HotkeyManager.swift`:

```swift
//
//  HotkeyManager.swift
//  TAELMacAgent
//
//  Owns the global hotkey registration via the KeyboardShortcuts
//  package. The actual work (gate → capture → HUD) is the closure
//  assigned to `onTrigger` by `AppDelegate`.
//

import Foundation
import KeyboardShortcuts

@MainActor
final class HotkeyManager {
    /// Set by `AppDelegate` to the gate→capture→HUD closure.
    /// Read inside the KeyboardShortcuts callback.
    var onTrigger: (() -> Void)?

    /// Registers the real global hotkey with KeyboardShortcuts.
    /// Call once during `applicationDidFinishLaunching`.
    func installBinding() {
        KeyboardShortcuts.onKeyDown(for: .toggleTAEL) { [weak self] in
            self?.onTrigger?()
        }
    }

    func tearDown() {
        KeyboardShortcuts.disable(.toggleTAEL)
        onTrigger = nil
    }
}
```

- [ ] **Step 2: Build**

```bash
xcodebuild -project TAELMacAgent/TAELMacAgent.xcodeproj \
  -scheme TAELMacAgent -configuration Debug \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```

Expected: BUILD SUCCEEDED. There's still a call site in `AppDelegate` to `installPlaceholderBinding()` that no longer exists — Task 6 fixes it. If you want a passing build between tasks, temporarily rename the call site too; otherwise commit Task 5 + Task 6 together.

**Decision:** for cleaner per-task commits, keep `installPlaceholderBinding` as a deprecated alias that just calls `installBinding`. Replace Step 1's file with this version instead:

```swift
//
//  HotkeyManager.swift
//  TAELMacAgent
//
//  Owns the global hotkey registration via the KeyboardShortcuts
//  package. The actual work (gate → capture → HUD) is the closure
//  assigned to `onTrigger` by `AppDelegate`.
//

import Foundation
import KeyboardShortcuts

@MainActor
final class HotkeyManager {
    /// Set by `AppDelegate` to the gate→capture→HUD closure.
    /// Read inside the KeyboardShortcuts callback.
    var onTrigger: (() -> Void)?

    /// Registers the real global hotkey with KeyboardShortcuts.
    /// Call once during `applicationDidFinishLaunching`.
    func installBinding() {
        KeyboardShortcuts.onKeyDown(for: .toggleTAEL) { [weak self] in
            self?.onTrigger?()
        }
    }

    /// Backwards-compatible alias for the PR 1 call site. Removed in
    /// the same commit that updates `AppDelegate` to call
    /// `installBinding()` directly (Task 6).
    @available(*, deprecated, renamed: "installBinding")
    func installPlaceholderBinding() {
        installBinding()
    }

    func tearDown() {
        KeyboardShortcuts.disable(.toggleTAEL)
        onTrigger = nil
    }
}
```

Build expectation: BUILD SUCCEEDED with one deprecation warning at the AppDelegate call site (Task 6 removes it).

- [ ] **Step 3: Run existing tests**

```bash
xcodebuild -project TAELMacAgent/TAELMacAgent.xcodeproj \
  -scheme TAELMacAgent -configuration Debug \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test
```

Expected: 8 tests pass.

- [ ] **Step 4: Commit**

```bash
git add TAELMacAgent/TAELMacAgent/Hotkey/HotkeyManager.swift
git commit -m "feat(hotkey): real KeyboardShortcuts registration

HotkeyManager.installBinding wires KeyboardShortcuts.onKeyDown to the
onTrigger closure that AppDelegate assigns. tearDown disables the
shortcut and nils the closure on app termination.

installPlaceholderBinding kept as a deprecated alias to keep this
commit's build green; removed when AppDelegate updates in Task 6."
```

---

## The wire-up

### Task 6: Wire `AppDelegate` — hotkey → gate → capture → HUD + log

**Files:**

- Modify: `TAELMacAgent/TAELMacAgent/App/AppDelegate.swift`

**Why:** ticket 9. This is the heartbeat itself. The closure assigned to `hotkeyManager.onTrigger` runs the gate, captures, presents to HUD, records a log row.

- [ ] **Step 1: Replace the file contents**

Replace `TAELMacAgent/TAELMacAgent/App/AppDelegate.swift`:

```swift
//
//  AppDelegate.swift
//  TAELMacAgent
//

import AppKit
import Foundation
import os.log
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?
    private var hotkeyManager: HotkeyManager?
    private var hudController: HUDPanelController?
    private var permissionsGate: PermissionsGate?
    private var screenCaptureService: DisplayScreenshotCapturing?
    private var logService: LocalLogService?
    private let log = Logger(subsystem: "ai.tael.macagent", category: "AppDelegate")

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Belt and braces: even though `LSUIElement = YES`, force
        // accessory mode at runtime so the app never gets a Dock icon.
        NSApp.setActivationPolicy(.accessory)

        let logService = LocalLogService()
        let hudController = HUDPanelController()
        let permissionsGate = PermissionsGate(
            checker: PermissionsChecker(),
            permissionUI: hudController
        )
        let screenCaptureService = ScreenCaptureService()
        let hotkeyManager = HotkeyManager()
        let menuBarController = MenuBarController(
            onShowHUD: { [weak hudController] in
                hudController?.showPlaceholder()
            },
            onQuit: {
                NSApp.terminate(nil)
            }
        )

        self.logService = logService
        self.hudController = hudController
        self.permissionsGate = permissionsGate
        self.screenCaptureService = screenCaptureService
        self.hotkeyManager = hotkeyManager
        self.menuBarController = menuBarController

        menuBarController.install()

        // Hotkey closure: gate → capture → HUD + log. Runs on the main
        // actor (the `@MainActor` class isolation already covers it).
        hotkeyManager.onTrigger = { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                await self.handleHotkeyInvocation()
            }
        }
        hotkeyManager.installBinding()
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyManager?.tearDown()
        hudController?.tearDown()
    }

    /// One invocation of the Week 1 heartbeat. Captures latency,
    /// outcome, and target metadata into a LocalLogService row.
    private func handleHotkeyInvocation() async {
        guard let permissionsGate, let screenCaptureService, let hudController, let logService else {
            log.fault("Hotkey fired before AppDelegate finished launch wiring; ignoring.")
            return
        }

        let started = Date()
        let gateStart = started

        do {
            let screenshot = try await permissionsGate.withPermission(.screenRecording) { grant in
                let gateEnd = Date()
                let captureStart = gateEnd
                let result = try await screenCaptureService.captureDisplayScreenshot(grant, target: .week1Default)
                let captureEnd = Date()

                await logService.record(InvocationLog(
                    hotkeyTimestamp: started,
                    gateOutcome: .granted,
                    gateLatencyMs: gateEnd.timeIntervalSince(gateStart) * 1000,
                    captureLatencyMs: captureEnd.timeIntervalSince(captureStart) * 1000,
                    targetDescription: "\(result.target) \(result.width)x\(result.height)"
                ))

                return result
            }
            hudController.present(screenshot: screenshot)
        } catch let error as PermissionError {
            // PermissionsGate already invoked permissionUI.showGate.
            // Log the outcome and stop.
            let outcome: InvocationLog.GateOutcome
            switch error {
            case .missing: outcome = .denied
            case .notImplemented: outcome = .restricted
            }
            await logService.record(InvocationLog(
                hotkeyTimestamp: started,
                gateOutcome: outcome,
                errorDescription: error.localizedDescription
            ))
        } catch {
            await logService.record(InvocationLog(
                hotkeyTimestamp: started,
                gateOutcome: .errored,
                errorDescription: error.localizedDescription
            ))
            log.error("Hotkey invocation failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
```

- [ ] **Step 2: Build and confirm the deprecation warning is gone**

```bash
xcodebuild -project TAELMacAgent/TAELMacAgent.xcodeproj \
  -scheme TAELMacAgent -configuration Debug \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```

Expected: BUILD SUCCEEDED, no deprecation warning. The change references `installBinding()` (Task 5) and a new `hudController.present(screenshot:)` method (added in Task 7).

**Will fail at this point** — `HUDPanelController.present(screenshot:)` doesn't exist yet. That's expected; the next task adds it. **Do not commit Task 6 alone.** Commit Task 6 + Task 7 together OR add a stub `present(screenshot:)` to HUDPanelController in this commit and flesh it out in Task 7.

For cleaner per-task commits, **add a one-line stub now** and flesh out in Task 7:

In `TAELMacAgent/TAELMacAgent/HUD/HUDPanelController.swift`, add this method body (just the placeholder; Task 7 replaces it):

```swift
    func present(screenshot: CapturedScreenshot) {
        // Task 7 fills this in. Stub so Task 6's AppDelegate wiring
        // compiles in its own commit.
        showPlaceholder()
    }
```

Then re-run the build — it should now succeed.

- [ ] **Step 3: Run existing tests**

```bash
xcodebuild -project TAELMacAgent/TAELMacAgent.xcodeproj \
  -scheme TAELMacAgent -configuration Debug \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test
```

Expected: 8 tests pass.

- [ ] **Step 4: Commit**

```bash
git add TAELMacAgent/TAELMacAgent/App/AppDelegate.swift \
        TAELMacAgent/TAELMacAgent/HUD/HUDPanelController.swift
git commit -m "feat(app): wire hotkey → PermissionsGate → capture → HUD + log

The Week 1 heartbeat. AppDelegate.handleHotkeyInvocation runs the
gate, captures (via DisplayScreenshotCapturing protocol so it stays
testable), presents to HUD, and records an InvocationLog row with
gate/capture latencies plus target description.

PermissionError.missing → InvocationLog.GateOutcome.denied
PermissionError.notImplemented → .restricted (kind isn't wired)
Any other thrown error → .errored + os_log.error

HUDPanelController.present(screenshot:) currently calls showPlaceholder
as a stub; Task 7 fleshes out the real screenshot rendering."
```

---

## Show the screenshot

### Task 7: HUD screenshot rendering

**Files:**

- Create: `TAELMacAgent/TAELMacAgent/HUD/HUDScreenshotView.swift`
- Modify: `TAELMacAgent/TAELMacAgent/HUD/HUDPanelController.swift`

**Why:** ticket 10. Render the captured screenshot inside the existing non-activating NSPanel. Keep the placeholder HUDView for the menubar "Show HUD" item; add a new view for screenshot display.

- [ ] **Step 1: Create the screenshot view**

Create `TAELMacAgent/TAELMacAgent/HUD/HUDScreenshotView.swift`:

```swift
//
//  HUDScreenshotView.swift
//  TAELMacAgent
//
//  Displays a CapturedScreenshot inside the HUD. PR 2: the shot is
//  shown at a fixed maximum size so a full 5K display still fits in a
//  reasonable HUD. Aspect ratio preserved.
//

import SwiftUI
import AppKit

struct HUDScreenshotView: View {
    let screenshot: CapturedScreenshot

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Captured \(screenshot.width)×\(screenshot.height) — \(targetLabel)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Image(decorative: screenshot.image, scale: 1.0, orientation: .up)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 720, maxHeight: 480)
                .background(Color.black.opacity(0.3))
                .cornerRadius(6)

            Text(screenshot.capturedAt.formatted(date: .omitted, time: .standard))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(16)
    }

    private var targetLabel: String {
        switch screenshot.target {
        case .displayContainingCursor: return "cursor display"
        case .mainDisplay: return "main display (fallback)"
        }
    }
}
```

- [ ] **Step 2: Replace the stub `present(screenshot:)` in `HUDPanelController`**

Replace the stub from Task 6's Step 2 with:

```swift
    func present(screenshot: CapturedScreenshot) {
        presentNew(content: HUDScreenshotView(screenshot: screenshot))
    }
```

- [ ] **Step 3: Build**

```bash
xcodebuild -project TAELMacAgent/TAELMacAgent.xcodeproj \
  -scheme TAELMacAgent -configuration Debug \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Run tests**

```bash
xcodebuild -project TAELMacAgent/TAELMacAgent.xcodeproj \
  -scheme TAELMacAgent -configuration Debug \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test
```

Expected: 8 tests pass.

- [ ] **Step 5: Commit**

```bash
git add TAELMacAgent/TAELMacAgent/HUD/HUDScreenshotView.swift \
        TAELMacAgent/TAELMacAgent/HUD/HUDPanelController.swift \
        TAELMacAgent/TAELMacAgent.xcodeproj/project.pbxproj
git commit -m "feat(hud): render CapturedScreenshot in non-activating HUD

HUDScreenshotView shows the CGImage at a fixed max 720x480 with aspect
ratio preserved, plus a caption with dimensions, target (cursor display
vs main fallback), and capture timestamp.

HUDPanelController.present(screenshot:) replaces the Task 6 stub."
```

---

## Test the wire-up

### Task 8: Wire-up tests via `DisplayScreenshotCapturing` mock (TDD)

**Files:**

- Create: `TAELMacAgent/TAELMacAgentTests/HotkeyHandlerTests.swift`

**Why:** the hotkey path orchestrates four collaborators (gate, capture service, HUD, log). Without tests, regressions in the wire-up only surface in manual testing. The `DisplayScreenshotCapturing` protocol from Task 2 makes this mockable. Tests live in their own file because they exercise a different surface than `PermissionsGateTests`.

**Caveat:** `AppDelegate.handleHotkeyInvocation` is `private`. Two options:

1. Make it `internal` and `@testable import` — simpler but expands the API.
2. Extract the body into a free function or a small `HotkeyInvocationHandler` type that AppDelegate composes — testable in isolation, no privacy widening.

**Choice:** option 2. Extract a `HotkeyInvocationHandler` in this task; AppDelegate calls `handler.run()`. Cleaner boundary.

- [ ] **Step 1: Extract the handler**

Create `TAELMacAgent/TAELMacAgent/App/HotkeyInvocationHandler.swift`:

```swift
//
//  HotkeyInvocationHandler.swift
//  TAELMacAgent
//
//  Single invocation of the Week 1 heartbeat: gate → capture → HUD +
//  log. Extracted from AppDelegate so the wire-up is unit-testable
//  without spinning up a real menubar or NSPanel.
//

import Foundation
import os.log

@MainActor
struct HotkeyInvocationHandler {
    let permissionsGate: PermissionsGate
    let screenCaptureService: any DisplayScreenshotCapturing
    let presentScreenshot: (CapturedScreenshot) -> Void
    let logService: LocalLogService
    let now: () -> Date

    init(
        permissionsGate: PermissionsGate,
        screenCaptureService: any DisplayScreenshotCapturing,
        presentScreenshot: @escaping (CapturedScreenshot) -> Void,
        logService: LocalLogService,
        now: @escaping () -> Date = Date.init
    ) {
        self.permissionsGate = permissionsGate
        self.screenCaptureService = screenCaptureService
        self.presentScreenshot = presentScreenshot
        self.logService = logService
        self.now = now
    }

    private static let log = Logger(subsystem: "ai.tael.macagent", category: "HotkeyInvocationHandler")

    func run() async {
        let started = now()
        let gateStart = started

        do {
            let screenshot = try await permissionsGate.withPermission(.screenRecording) { grant in
                let gateEnd = self.now()
                let captureStart = gateEnd
                let result = try await screenCaptureService.captureDisplayScreenshot(grant, target: .week1Default)
                let captureEnd = self.now()

                await logService.record(InvocationLog(
                    hotkeyTimestamp: started,
                    gateOutcome: .granted,
                    gateLatencyMs: gateEnd.timeIntervalSince(gateStart) * 1000,
                    captureLatencyMs: captureEnd.timeIntervalSince(captureStart) * 1000,
                    targetDescription: "\(result.target) \(result.width)x\(result.height)"
                ))

                return result
            }
            presentScreenshot(screenshot)
        } catch let error as PermissionError {
            let outcome: InvocationLog.GateOutcome
            switch error {
            case .missing: outcome = .denied
            case .notImplemented: outcome = .restricted
            }
            await logService.record(InvocationLog(
                hotkeyTimestamp: started,
                gateOutcome: outcome,
                errorDescription: error.localizedDescription
            ))
        } catch {
            await logService.record(InvocationLog(
                hotkeyTimestamp: started,
                gateOutcome: .errored,
                errorDescription: error.localizedDescription
            ))
            Self.log.error("Hotkey invocation failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
```

Update `TAELMacAgent/TAELMacAgent/App/AppDelegate.swift` to use the handler. Replace the `handleHotkeyInvocation` method and the `hotkeyManager.onTrigger` assignment:

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

Remove the `handleHotkeyInvocation` private method and the `import os.log` from `AppDelegate.swift` (it's now in `HotkeyInvocationHandler`).

- [ ] **Step 2: Write the failing tests**

Create `TAELMacAgent/TAELMacAgentTests/HotkeyHandlerTests.swift`:

```swift
//
//  HotkeyHandlerTests.swift
//  TAELMacAgentTests
//

import XCTest
@testable import TAELMacAgent
import CoreGraphics

@MainActor
final class HotkeyHandlerTests: XCTestCase {

    // MARK: - Test doubles

    private actor StubChecker: PermissionChecking {
        private let status: PermissionStatus
        init(_ status: PermissionStatus) { self.status = status }
        func status(for kind: PermissionKind) async -> PermissionStatus { status }
    }

    private actor SpyUI: PermissionGatePresenting {
        private(set) var shownKinds: [PermissionKind] = []
        func showGate(for kind: PermissionKind) async { shownKinds.append(kind) }
    }

    private actor SpyCapture: DisplayScreenshotCapturing {
        var thrownError: Error?
        var capturedTargets: [ScreenshotTarget] = []
        var stubScreenshot: CapturedScreenshot

        init(stub: CapturedScreenshot) { self.stubScreenshot = stub }

        func setError(_ error: Error?) { self.thrownError = error }
        func observedTargets() -> [ScreenshotTarget] { capturedTargets }

        func captureDisplayScreenshot(
            _ grant: PermissionGrant,
            target: ScreenshotTarget
        ) async throws -> CapturedScreenshot {
            precondition(grant.kind == .screenRecording)
            capturedTargets.append(target)
            if let thrownError { throw thrownError }
            return stubScreenshot
        }
    }

    /// Builds a 1x1 transparent CGImage for tests; no real capture.
    private func makeStubScreenshot() -> CapturedScreenshot {
        let cs = CGColorSpaceCreateDeviceRGB()
        let ctx = CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        let image = ctx.makeImage()!
        return CapturedScreenshot(image: image, target: .displayContainingCursor)
    }

    // MARK: - Granted path

    func test_run_whenGranted_callsCaptureAndPresentsAndLogsGranted() async {
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
            logService: logService
        )

        await handler.run()

        let targets = await capture.observedTargets()
        XCTAssertEqual(targets, [.week1Default])
        XCTAssertEqual(presented.count, 1)

        let logs = await logService.recent(10)
        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(logs.first?.gateOutcome, .granted)
        XCTAssertNotNil(logs.first?.gateLatencyMs)
        XCTAssertNotNil(logs.first?.captureLatencyMs)
    }

    // MARK: - Denied path

    func test_run_whenDenied_doesNotCapture_doesNotPresent_logsDenied() async {
        let checker = StubChecker(.denied)
        let ui = SpyUI()
        let gate = PermissionsGate(checker: checker, permissionUI: ui)
        let capture = SpyCapture(stub: makeStubScreenshot())
        let logService = LocalLogService(capacity: 16)

        var presented: [CapturedScreenshot] = []
        let handler = HotkeyInvocationHandler(
            permissionsGate: gate,
            screenCaptureService: capture,
            presentScreenshot: { presented.append($0) },
            logService: logService
        )

        await handler.run()

        let targets = await capture.observedTargets()
        XCTAssertTrue(targets.isEmpty)
        XCTAssertTrue(presented.isEmpty)

        let logs = await logService.recent(10)
        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(logs.first?.gateOutcome, .denied)
        XCTAssertNotNil(logs.first?.errorDescription)

        // The gate still surfaces the UI on missing permission.
        let shown = await ui.shownKinds
        XCTAssertEqual(shown, [.screenRecording])
    }

    // MARK: - Capture failure path

    func test_run_whenCaptureFails_logsErroredOutcome() async {
        let checker = StubChecker(.granted)
        let ui = SpyUI()
        let gate = PermissionsGate(checker: checker, permissionUI: ui)
        let capture = SpyCapture(stub: makeStubScreenshot())
        await capture.setError(ScreenCaptureError.captureFailed("simulated"))

        let logService = LocalLogService(capacity: 16)

        var presented: [CapturedScreenshot] = []
        let handler = HotkeyInvocationHandler(
            permissionsGate: gate,
            screenCaptureService: capture,
            presentScreenshot: { presented.append($0) },
            logService: logService
        )

        await handler.run()

        XCTAssertTrue(presented.isEmpty)
        let logs = await logService.recent(10)
        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(logs.first?.gateOutcome, .errored)
        XCTAssertEqual(logs.first?.errorDescription, "captureFailed(\"simulated\")")
    }
}
```

- [ ] **Step 3: Register the new files in the project**

If using XcodeGen, run `make xcodeproj` to pick up `HotkeyInvocationHandler.swift` and `HotkeyHandlerTests.swift` automatically. If hand-edited pbxproj, follow the same registration pattern as `LocalLogServiceTests.swift` from PR 1.

- [ ] **Step 4: Run only the new tests, confirm they pass**

```bash
xcodebuild test \
  -project TAELMacAgent/TAELMacAgent.xcodeproj \
  -scheme TAELMacAgent \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO \
  -only-testing:TAELMacAgentTests/HotkeyHandlerTests
```

Expected: 3 tests pass.

- [ ] **Step 5: Run the full suite**

```bash
xcodebuild -project TAELMacAgent/TAELMacAgent.xcodeproj \
  -scheme TAELMacAgent -configuration Debug \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test
```

Expected: 11 tests pass (5 PermissionsGate + 3 LocalLogService + 3 HotkeyHandler).

- [ ] **Step 6: Commit**

```bash
git add TAELMacAgent/TAELMacAgent/App/HotkeyInvocationHandler.swift \
        TAELMacAgent/TAELMacAgent/App/AppDelegate.swift \
        TAELMacAgent/TAELMacAgentTests/HotkeyHandlerTests.swift \
        TAELMacAgent/TAELMacAgent.xcodeproj/project.pbxproj
git commit -m "feat(app): extract HotkeyInvocationHandler + tests

Pulls the gate→capture→HUD+log pipeline out of AppDelegate into a
@MainActor struct that takes its collaborators as init parameters.
Lets us unit-test the wire-up without spinning up NSPanel or
ScreenCaptureKit.

Three tests covering: granted (capture + present + log granted),
denied (no capture, no present, log denied + gate UI shown), and
capture-failure (no present, log errored)."
```

---

## Last cleanup

### Task 9: Remove the `installPlaceholderBinding` deprecated alias

**Files:**

- Modify: `TAELMacAgent/TAELMacAgent/Hotkey/HotkeyManager.swift`

**Why:** Task 5's deprecated alias was scaffolding for clean per-task commits. Now that `AppDelegate` calls `installBinding()` directly (Task 6), the alias is dead.

- [ ] **Step 1: Remove the deprecated method**

In `TAELMacAgent/TAELMacAgent/Hotkey/HotkeyManager.swift`, delete:

```swift
    @available(*, deprecated, renamed: "installBinding")
    func installPlaceholderBinding() {
        installBinding()
    }
```

- [ ] **Step 2: Verify no references remain**

```bash
grep -rn "installPlaceholderBinding" TAELMacAgent/
```

Expected: zero matches.

- [ ] **Step 3: Build and test**

```bash
xcodebuild -project TAELMacAgent/TAELMacAgent.xcodeproj \
  -scheme TAELMacAgent -configuration Debug \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test
```

Expected: 11 tests pass, no warnings.

- [ ] **Step 4: Commit**

```bash
git add TAELMacAgent/TAELMacAgent/Hotkey/HotkeyManager.swift
git commit -m "chore(hotkey): remove installPlaceholderBinding deprecated alias

Existed only as a scaffold so Task 5's commit could build before
Task 6 updated the AppDelegate call site. Both tasks have landed."
```

---

## Documentation

### Task 10: Update `ManualTestChecklist.md` and `Week1Heartbeat.md`

**Files:**

- Modify: `docs/ManualTestChecklist.md`
- Modify: `docs/Week1Heartbeat.md`

**Why:** PR 2 changes what "manual test" means. Need to add the real heartbeat verification cases. Week1Heartbeat.md should mark the heartbeat as complete.

- [ ] **Step 1: Add PR-2 manual test cases**

Open `docs/ManualTestChecklist.md`. After the existing PR-1 cases, add a new section:

```markdown
## PR 2 — Week 1 heartbeat manual cases

PR-2.1 First-launch Screen Recording prompt
- Quit TAEL if running.
- `make tcc-reset` to clear ai.tael.macagent's TCC entries.
- `make run`.
- Press ⌘⇧T while Terminal is focused.
- Expected: PermissionGateView appears with "TAEL needs Screen Recording permission" and "Open System Settings" / "Cancel" buttons.

PR-2.2 Cancel button dismisses the gate
- From PR-2.1's gate, click "Cancel".
- Expected: panel disappears within ~100ms, no crash.

PR-2.3 Granted path captures and renders
- Click "Open System Settings" in the gate, grant Screen Recording for TAELMacAgent, quit/relaunch TAEL.
- Press ⌘⇧T.
- Expected: HUD appears within ~500ms showing the cursor display's screenshot at max 720x480 with caption "Captured WIDTHxHEIGHT — cursor display".
- Expected: HUD does not steal focus from Terminal/VS Code/Cursor.

PR-2.4 Multi-monitor — cursor display selection
- With two displays, move the cursor to the secondary display.
- Press ⌘⇧T.
- Expected: HUD shows the secondary display's content, caption says "cursor display".

PR-2.5 Multi-monitor — main display fallback
- Disconnect or disable the secondary display while the cursor was on it (edge case; requires a hotplug or display-arrangement change).
- Press ⌘⇧T.
- Expected: HUD shows the main display, caption says "main display (fallback)".

PR-2.6 Full-screen app
- Make a Terminal or VS Code window full-screen.
- Press ⌘⇧T.
- Expected: HUD appears as an overlay; full-screen app stays focused; HUD shows the captured screenshot.

PR-2.7 No screenshot persistence
- After PR-2.3, check `~/Library/Application Support/TAELMacAgent/` and the project root.
- Expected: no PNG/JPEG files created. Screenshots are in-memory only.

PR-2.8 Invocation log fields
- After several invocations, attach a debugger to TAELMacAgent and inspect `LocalLogService.recent()`.
- Expected: each row has hotkeyTimestamp, gateOutcome, gateLatencyMs, captureLatencyMs, targetDescription. Granted-path rows have all four numeric fields populated.
```

- [ ] **Step 2: Mark heartbeat complete in `docs/Week1Heartbeat.md`**

Add a status line near the top of `docs/Week1Heartbeat.md`:

```markdown
> **Status (2026-04-26): heartbeat shipped in PR 2.** Hotkey ⌘⇧T → PermissionsGate.withPermission(.screenRecording) → SCScreenshotManager.captureImage → non-activating NSPanel HUD with the captured CGImage. See `docs/ManualTestChecklist.md` PR-2.* cases for verification.
```

- [ ] **Step 3: Commit**

```bash
git add docs/ManualTestChecklist.md docs/Week1Heartbeat.md
git commit -m "docs(week1): document the shipped heartbeat and PR-2 manual cases

ManualTestChecklist.md gains 8 PR-2 cases covering first-launch
prompt, Cancel, granted path, multi-monitor cursor + fallback,
full-screen, no-persistence, and InvocationLog fields.

Week1Heartbeat.md marks the heartbeat as shipped."
```

---

## Wrap up (maestro only)

### Task 11: Open the PR

**Files:** none (orchestration)

**Why maestro-only:** `gh pr create` writes to a shared external system; the maestro keeps the user in the loop on what gets surfaced.

- [ ] **Step 1: Run the full clean test suite**

```bash
xcodebuild -project TAELMacAgent/TAELMacAgent.xcodeproj \
  -scheme TAELMacAgent -configuration Debug \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO clean test
```

Expected: 11 tests pass.

- [ ] **Step 2: Confirm the branch is ahead of develop**

```bash
git log origin/develop..HEAD --oneline
```

Expected: 10 commits (Task 1 + Tasks 2–10), one per task, conventional-commit format.

- [ ] **Step 3: Push**

```bash
git push origin feature/pr2-week1-heartbeat
```

- [ ] **Step 4: Open the PR**

```bash
gh pr create --base develop --head feature/pr2-week1-heartbeat \
  --title "feat: PR 2 — Week 1 heartbeat (hotkey → gate → capture → HUD)" \
  --body "$(cat <<'EOF'
## Summary

Ships the Week 1 heartbeat per v0.3 §1: \`global hotkey → PermissionsGate → SCScreenshotManager → non-activating NSPanel HUD with screenshot PNG\`.

Plan: \`docs/superpowers/plans/2026-04-26-pr2-week1-heartbeat.md\`. Codex-driven where the sandbox allowed; maestro-driven for SPM dep resolution and PR creation.

## What's in

- **KeyboardShortcuts SPM package** registered via XcodeGen (\`project.yml\`)
- **Real \`SCScreenshotManager.captureImage(contentFilter:configuration:)\`** capture with cursor-display resolution + main-display fallback (v0.3 §23.2)
- **\`DisplayScreenshotCapturing\` protocol** so the wire-up is unit-testable without TCC
- **\`HotkeyInvocationHandler\`** extracted from AppDelegate (testable struct)
- **\`HUDScreenshotView\`** rendering CGImage at max 720×480, aspect ratio preserved, caption with dimensions + target + timestamp
- **\`InvocationLog\`** rows recorded per invocation: gate outcome, gate latency, capture latency, target description, error description on failure
- **3 new tests** (\`HotkeyHandlerTests\`) covering granted / denied / capture-failure paths
- **8 new manual test cases** in \`docs/ManualTestChecklist.md\` (PR-2.1 through PR-2.8)

## Test plan

- [x] \`xcodebuild ... clean test\` — 11 tests, 0 failures (5 PermissionsGate + 3 LocalLogService + 3 HotkeyHandler)
- [ ] Manual PR-2.1 (first-launch Screen Recording prompt)
- [ ] Manual PR-2.2 (Cancel dismisses gate)
- [ ] Manual PR-2.3 (granted path captures and renders)
- [ ] Manual PR-2.4 (multi-monitor cursor display)
- [ ] Manual PR-2.5 (multi-monitor main fallback)
- [ ] Manual PR-2.6 (full-screen app)
- [ ] Manual PR-2.7 (no screenshot persistence)
- [ ] Manual PR-2.8 (InvocationLog fields populated)

## Out of scope

- AX tree (Week 2)
- Voice capture / WhisperKit (Week 3)
- Planner adapter (Week 4)
- Safe executor (Week 5)
- Skill matcher / hardcoded skills (Weeks 6–7)
- User-rebindable hotkey (post-PR 2)
- Disk-persisted invocation log (after executor lands)
EOF
)"
```

Expected: PR URL printed. Notify Ozzy.

---

## Self-review checklist

After writing the plan and before handing off:

**1. Spec coverage:**

- v0.3 §12.2 Week 1 deliverables: menubar app ✓ (PR 1), KeyboardShortcuts (Task 1), global hotkey works (Tasks 4–6), PermissionsChecker (PR 1), PermissionsGate (PR 1), Screen Recording gate (PR 1 + Task 6 wire-up), Week 1 screenshot target (Task 3 cursor + fallback), SCScreenshotManager.captureImage (Task 3), explicit width/height (Task 3 backingScaleFactor), NSPanel HUD displays image (Task 7). All covered.
- v0.3 §23.5 first-13 tickets: 6 (KeyboardShortcuts) → Tasks 1, 4, 5; 8 (ScreenCaptureService real) → Task 3; 9 (wire-up) → Task 6; 10 (HUD render) → Task 7; 11 (InvocationLog) → Task 6 wire + records via logService. All covered.

**2. Placeholder scan:** No "TBD", "implement later", "add appropriate error handling" patterns. Each step has concrete code or commands.

**3. Type consistency:**

- `DisplayScreenshotCapturing` is the protocol name in Tasks 2, 3, 6, 8. ✓
- `KeyboardShortcuts.Name.toggleTAEL` declared in Task 4, used in Task 5. ✓
- `HotkeyInvocationHandler` introduced in Task 8 (extraction); `AppDelegate.handleHotkeyInvocation` from Task 6 is replaced by the handler — Task 8 explicitly removes it. ✓
- `present(screenshot:)` stub introduced in Task 6, fleshed out in Task 7. ✓
- `installPlaceholderBinding` deprecated in Task 5, removed in Task 9. ✓
- `InvocationLog` initializer matches the existing struct (`hotkeyTimestamp`, `gateOutcome`, `gateLatencyMs`, `captureLatencyMs`, `targetDescription`, `errorDescription`). ✓
- `LocalLogService.record` is `async`. All call sites use `await`. ✓

---

## Notes for the executor

- **Task 1 is maestro-only** because SPM resolution needs network. Maestro: edit project.yml, `make xcodeproj`, `xcodebuild -resolvePackageDependencies`, commit. Codex resumes from Task 2.
- **Task 11 is maestro-only** for the PR creation step (`gh pr create` writes to GitHub).
- **Sandbox commit pattern:** Codex's sandbox blocks `.git/index.lock` writes. The maestro commits on Codex's behalf after each task, same pattern as PR 1 cleanup. Codex stages files via `git add` if it can; otherwise leaves the working tree dirty and the maestro stages + commits.
- **Test-runner sandbox issue:** Codex's sandbox blocks `~/Library/Developer/Xcode/DerivedData` and `testmanagerd.control`. Codex uses `-derivedDataPath /tmp/...` and confirms via `xcrun xctest` directly when needed. The maestro re-runs the canonical `xcodebuild ... test` outside the sandbox.
- **Manual verification gate:** Tasks 3, 6, 7 cannot be unit-tested end-to-end (real Screen Recording, real hotkey, real HUD render). PR 2 ships when all 11 unit tests pass AND PR-2.1, PR-2.3, PR-2.7 manual cases pass. PR-2.4, PR-2.5, PR-2.6, PR-2.8 are nice-to-have but not blocking.
- **Bot review gate:** open the PR, wait for Gemini + Copilot to review (CodeRabbit is rate-limited; will appear when it appears). Expect 5–15 minutes. If they flag anything substantial, batch a small follow-up commit on the same branch — don't open a separate PR for tiny bot fixes.
