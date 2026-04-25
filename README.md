# TAEL AI mac agent

Native macOS voice + screen + action assistant.

This repo contains the prototype implementation that follows the planning
freeze in [`TAEL_AI_mac_agent_build_plan_v0_3.md`](TAEL_AI_mac_agent_build_plan_v0_3.md).

> If older plan files (`TAEL_AI_mac_agent_build_plan.md`,
> `TAEL_AI_mac_agent_build_plan_v0_2.md`) conflict with v0.3, **v0.3 wins.**

## Status

PR 1 scope: native macOS menubar scaffold + Week 1 policy/docs.

What works today:

- App launches as a native macOS menubar utility.
- Stable bundle ID `ai.tael.macagent`, deployment target macOS 14.0+.
- Quit cleanly from menubar.
- Permissions boundary types (`PermissionKind`, `PermissionStatus`,
  `PermissionError`, `PermissionGrant`) are in place.
- `PermissionsGate` enforces a tokenized closure boundary for protected APIs.
- `PermissionsChecker` v0 reports Screen Recording status only.
- `HUDPanelController` placeholder (non-activating `NSPanel`).
- `ScreenCaptureService` exists as a typed stub that requires a
  `PermissionGrant`; the real `SCScreenshotManager` call lands in PR 2.

What is intentionally NOT in PR 1:

- AI planner, speech capture, WhisperKit
- AX tree, focused-window metadata
- YAML skills, executor, clipboard / shell / AppleScript / CGEvent actions
- Settings UI, polished onboarding
- DMG packaging, Sparkle, analytics, token tracking
- Screenshot persistence
- Product naming / landing page

See [`docs/Week1Heartbeat.md`](docs/Week1Heartbeat.md) for the Week 1
heartbeat and the Week 1 implementation ticket order.

## Layout

```
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
open TAELMacAgent/TAELMacAgent.xcodeproj
```

In Xcode, select the `TAELMacAgent` scheme and press Run.

> Ad-hoc signing is **not** the intended dev path. TCC permissions are keyed
> to bundle identity and signing requirements; unstable signing makes
> permission debugging noisy. The real Team ID must be set before any
> Screen Recording / TCC work — see TODO.

## Branches

- `main` — frozen plan + scaffold
- `dev-claude` — Maestro Claude development branch (this branch)
- `dev-codex` — Codex development branch

## License

Proprietary. All rights reserved. © TAEL AI.
