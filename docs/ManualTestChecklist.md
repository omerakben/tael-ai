# Manual test checklist

PR-by-PR, run the rows that apply. Anything new and risky should add a
row here.

Legend: ✅ pass · ⚠️ pass with note · ❌ fail · — not applicable to this PR

## PR 1 — scaffold only

| # | Check | Expected | Result |
|---|---|---|---|
| 1 | Open `TAELMacAgent.xcodeproj` in Xcode 15.3+ on macOS 14.0+ | Project loads, no missing files | |
| 2 | Build `TAELMacAgent` Debug | Clean build, no warnings | |
| 3 | Run `TAELMacAgent` Debug | App launches | |
| 4 | App has no Dock icon | Menubar utility only | |
| 5 | Menubar icon appears | Statusbar item visible | |
| 6 | Click menubar icon → "Quit TAEL" | App exits cleanly | |
| 7 | Run `TAELMacAgentTests` | All tests pass | |
| 8 | Inspect `Info.plist` | `LSUIElement = YES`, `LSMinimumSystemVersion = 14.0`, `CFBundleIdentifier = ai.tael.macagent` | |
| 9 | Confirm no Screen Recording prompt appears on launch | We do not call any protected API on launch | |

## Week 1 (lands in PR 2 — `hotkey → screenshot → HUD`)

These are not expected to pass on PR 1. Listed here so they are ready
when PR 2 lands.

| # | Check | Expected |
|---|---|---|
| W1.1 | Press hotkey while Terminal is focused | HUD appears |
| W1.2 | HUD does not steal focus from Terminal | Terminal title bar remains active |
| W1.3 | Press hotkey when Screen Recording is denied | Permission gate sheet appears |
| W1.4 | Click "Open System Settings" in gate | System Settings → Privacy & Security → Screen Recording opens |
| W1.5 | Grant Screen Recording, quit and relaunch app, press hotkey | Screenshot of display containing cursor renders in HUD |
| W1.6 | Press hotkey with cursor on a secondary display | Screenshot is of the secondary display |
| W1.7 | Disconnect all displays except main, press hotkey | Falls back to main display |
| W1.8 | Verify on disk after invocation | No screenshot file written |
| W1.9 | Press hotkey from a full-screen app (e.g. full-screen VS Code) | App does not crash; HUD appears or fails gracefully |
| W1.10 | Revoke Screen Recording in System Settings while app is running, press hotkey | Gate appears; app does not crash |
| W1.11 | Press hotkey with cursor on a Cursor / VS Code window | Screenshot includes that window |
| W1.12 | Inspect `LocalLogService` after several invocations | Each invocation has a row with hotkey ts, gate result, capture timing, target display metadata |

## TCC reset for clean re-test

```bash
./scripts/reset-tcc-dev.sh
```

After running, **quit the app and relaunch** before re-testing
W1.3–W1.5. Some macOS 14 builds need a quit+relaunch for the new
state to take effect.
