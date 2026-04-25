# tael-ai

Native macOS menubar utility scaffold for the TAEL AI mac agent.

The source of truth for this implementation pass is `TAEL_AI_mac_agent_build_plan_v0_3.md`. Older planning files are historical context only when they conflict with v0.3.

## PR 1 scope

PR 1 creates the native macOS foundation only:

- macOS app target in `TAELMacAgent/`
- stable bundle ID `ai.tael.macagent`
- macOS deployment target `14.0`
- SwiftUI app with AppKit menubar utility shell
- quit action from the menubar
- Week 1 permission boundary types
- protected API policy docs
- manual test checklist and Week 1 heartbeat checklist

PR 1 does not implement screenshot capture, speech capture, AX reads, executor paths, AI planner work, packaging, analytics, or product naming work.

## Build

Open `TAELMacAgent/TAELMacAgent.xcodeproj` in Xcode and set the Apple Development Team before regular local development builds.

For compile validation without signing:

```sh
xcodebuild \
  -project TAELMacAgent/TAELMacAgent.xcodeproj \
  -scheme TAELMacAgent \
  -configuration Debug \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Run tests:

```sh
xcodebuild \
  -project TAELMacAgent/TAELMacAgent.xcodeproj \
  -scheme TAELMacAgent \
  -configuration Debug \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO \
  test
```

## Week 1 heartbeat

The Week 1 heartbeat is:

```text
global hotkey -> PermissionsGate -> SCScreenshotManager.captureImage(contentFilter:configuration:) -> non-activating NSPanel HUD with screenshot PNG
```

The screenshot target will be the display containing the cursor, with fallback to the main display.

## Protected API boundary

No protected macOS API call may bypass `PermissionsGate`. Protected services require a `PermissionGrant`, and the grant is only issued inside the gate.

See `docs/ProtectedAPICallPolicy.md`.
