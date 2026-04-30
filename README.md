# TAEL AI mac agent

Native macOS voice + screen + action assistant.

This repo contains the prototype implementation that follows the planning
freeze in [`TAEL_AI_mac_agent_build_plan_v0_3.md`](TAEL_AI_mac_agent_build_plan_v0_3.md).

> If older plan files (`TAEL_AI_mac_agent_build_plan.md`,
> `TAEL_AI_mac_agent_build_plan_v0_2.md`) conflict with v0.3, **v0.3 wins.**

## Status

Current internal alpha track:

- App launches as a native macOS menubar utility.
- Stable bundle ID `ai.tael.macagent`, deployment target macOS 14.0+.
- Global hotkey `Command-Shift-T` runs the heartbeat.
- `PermissionsGate` enforces a tokenized closure boundary for protected APIs.
- Screen Recording and Accessibility permission checks are active.
- `ScreenCaptureService` captures the display containing the cursor with
  `SCScreenshotManager.captureImage(contentFilter:configuration:)`.
- HUD renders the captured screenshot and, when Accessibility is granted,
  focused-window metadata.
- `LocalLogService` keeps an in-memory invocation log only.
- Internal alpha DMG packaging is scripted in `scripts/package-alpha-dmg.sh`,
  but Developer ID certificate and notary credentials are local prerequisites.

Still intentionally deferred:

- AI planner, speech capture, WhisperKit
- AX tree dump beyond focused-window metadata
- YAML skills, executor, clipboard, shell, AppleScript, CGEvent actions
- Settings UI, polished onboarding
- Sparkle updates, analytics, token tracking
- Screenshot or AX context persistence
- Public launch operations

See [`docs/Week1Heartbeat.md`](docs/Week1Heartbeat.md) for the Week 1
heartbeat and the Week 1 implementation ticket order.

## Layout

```text
tael-ai/
  README.md
  .gitignore
  TODO_FOR_OZZY.md
  TAEL_AI_mac_agent_build_plan_v0_3.md   (source of truth)
  .github/
    ISSUE_TEMPLATE/
    PULL_REQUEST_TEMPLATE.md
  docs/
    Architecture.md
    ProtectedAPICallPolicy.md
    PermissionNotes.md
    ManualTestChecklist.md
    Week1Heartbeat.md
  scripts/
    reset-tcc-dev.sh
  TAELMacAgent/
    TAELMacAgent.xcodeproj
    TAELMacAgent/
      App/
      Hotkey/
      Permissions/
      HUD/
      Capture/
      Logging/
      Resources/
    TAELMacAgentTests/
```

## Requirements

- macOS 14.0+
- Xcode 15.3+ (Swift 5.10+)
- Apple Development signing identity tied to a real Team ID
  (see [`TODO_FOR_OZZY.md`](TODO_FOR_OZZY.md))

## Building

```bash
make xcodeproj
make build
make test
```

For Xcode, open `TAELMacAgent/TAELMacAgent.xcodeproj`, select the
`TAELMacAgent` scheme, and press Run.

> Ad-hoc signing is **not** the intended dev path. TCC permissions are keyed
> to bundle identity and signing requirements; unstable signing makes
> permission debugging noisy. The real Team ID must be set before any
> Screen Recording / TCC work. See TODO.

## Alpha packaging

Internal alpha packaging is manual DMG only:

```bash
DEVELOPER_ID_APPLICATION="Developer ID Application: OMER FARUK AKBEN (...)" \
NOTARYTOOL_PROFILE="tael-notary" \
VERSION="0.1.0-alpha.1" \
./scripts/package-alpha-dmg.sh
```

See [`docs/AlphaReleaseChecklist.md`](docs/AlphaReleaseChecklist.md).

## Branches

- `main` is the production/release branch.
- `develop` is the integration branch.
- `feature/*` and `codex/*` branches PR into `develop`.

## License

Proprietary. All rights reserved. © TAEL AI.
