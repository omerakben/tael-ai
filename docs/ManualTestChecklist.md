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

## PR 2 — Week 1 heartbeat manual cases

### PR-2.1 First-launch Screen Recording prompt

- Quit TAEL if running.
- `make tcc-reset` to clear ai.tael.macagent's TCC entries.
- `make run`.
- Press ⌘⇧T while Terminal is focused.
- Expected: PermissionGateView appears with "TAEL needs Screen Recording permission" and "Open System Settings" / "Cancel" buttons.

### PR-2.2 Cancel button dismisses the gate

- From PR-2.1's gate, click "Cancel".
- Expected: panel disappears within ~100ms, no crash.

### PR-2.3 Granted path captures and renders

- Click "Open System Settings" in the gate, grant Screen Recording for TAELMacAgent, quit/relaunch TAEL.
- Press ⌘⇧T.
- Expected: HUD appears within ~500ms showing the cursor display's screenshot at max 720x480 with caption "Captured WIDTHxHEIGHT — cursor display".
- Expected: HUD does not steal focus from Terminal/VS Code/Cursor.

### PR-2.4 Multi-monitor — cursor display selection

- With two displays, move the cursor to the secondary display.
- Press ⌘⇧T.
- Expected: HUD shows the secondary display's content, caption says "cursor display".

### PR-2.5 Multi-monitor — main display fallback

- Disconnect or disable the secondary display while the cursor was on it (edge case; requires a hotplug or display-arrangement change).
- Press ⌘⇧T.
- Expected: HUD shows the main display, caption says "main display (fallback)".

### PR-2.6 Full-screen app

- Make a Terminal or VS Code window full-screen.
- Press ⌘⇧T.
- Expected: HUD appears as an overlay; full-screen app stays focused; HUD shows the captured screenshot.

### PR-2.7 No screenshot persistence

- After PR-2.3, check `~/Library/Application Support/TAELMacAgent/` and the project root.
- Expected: no PNG/JPEG files created. Screenshots are in-memory only.

### PR-2.8 Invocation log fields

- After several invocations, attach a debugger to TAELMacAgent and inspect `LocalLogService.recent()`.
- Expected: each row has hotkeyTimestamp, gateOutcome, gateLatencyMs, captureLatencyMs, targetDescription. Granted-path rows have all four numeric fields populated.

## TCC reset for clean re-test

```bash
./scripts/reset-tcc-dev.sh
```

After running, **quit the app and relaunch** before re-testing
W1.3–W1.5. Some macOS 14 builds need a quit+relaunch for the new
state to take effect.
