# Manual test checklist

PR-by-PR, run the rows that apply. Anything new and risky should add a
row here.

Legend: pass, pass with note, fail, not applicable

## PR 1 scaffold only

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

## Week 1 heartbeat, shipped in PR 2

These are retained as the baseline heartbeat checks.

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

## PR 2 Week 1 heartbeat manual cases

### PR-2.1 First-launch Screen Recording prompt

- Quit TAEL if running.
- `scripts/reset-tcc-dev.sh` to clear ai.tael.macagent's TCC entries.
- Open `TAELMacAgent/TAELMacAgent.xcodeproj` in Xcode and Run, or `xcodebuild -project TAELMacAgent/TAELMacAgent.xcodeproj -scheme TAELMacAgent -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build` then launch the built `.app`.
- Press ⌘⇧T while Terminal is focused.
- Expected: PermissionGateView appears with "TAEL needs Screen Recording permission" and "Open System Settings" / "Cancel" buttons.

### PR-2.2 Cancel button dismisses the gate

- From PR-2.1's gate, click "Cancel".
- Expected: panel disappears within ~100ms, no crash.

### PR-2.3 Granted path captures and renders

- Click "Open System Settings" in the gate, grant Screen Recording for TAELMacAgent, quit/relaunch TAEL.
- Press ⌘⇧T.
- Expected: HUD appears within ~500ms showing the cursor display's screenshot at max 720x480 with caption "Captured WIDTHxHEIGHT - cursor display".
- Expected: HUD does not steal focus from Terminal/VS Code/Cursor.

### PR-2.4 Multi-monitor cursor display selection

- With two displays, move the cursor to the secondary display.
- Press ⌘⇧T.
- Expected: HUD shows the secondary display's content, caption says "cursor display".

### PR-2.5 Multi-monitor main display fallback

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
W1.3-W1.5. Some macOS 14 builds need a quit+relaunch for the new
state to take effect.

## PR 5 focused-window metadata

| # | Check | Expected |
|---|---|---|
| PR-5.1 | Grant Screen Recording, do not grant Accessibility, press `Command-Shift-T` from Terminal | Screenshot HUD appears; focused-window area says metadata is unavailable; no Accessibility gate interrupts the heartbeat |
| PR-5.2 | Grant Screen Recording and Accessibility, press `Command-Shift-T` from Terminal | HUD shows screenshot plus Terminal app name and focused-window title when available |
| PR-5.3 | Press `Command-Shift-T` from VS Code or Cursor | HUD shows screenshot plus app name and a best-effort focused-window title |
| PR-5.4 | Press `Command-Shift-T` from Safari or another sandboxed app | HUD still appears; metadata may be partial but app must not crash |
| PR-5.5 | Press `Command-Shift-T` from a full-screen app | HUD appears without stealing focus; metadata degrades gracefully |
| PR-5.6 | Revoke Accessibility while app is running, then press `Command-Shift-T` | Screenshot still appears; focused-window metadata is omitted |
| PR-5.7 | Inspect project root and `~/Library/Application Support/TAELMacAgent/` | No screenshot or AX context files are created |

## Alpha DMG smoke test

| # | Check | Expected |
|---|---|---|
| A.1 | Run `./scripts/package-alpha-dmg.sh` without required env vars | Script exits with a clear prerequisite error |
| A.2 | Package with Developer ID identity and notary profile | DMG is created, notarized, stapled, and Gatekeeper-checked |
| A.3 | Install from the DMG on a clean user or fresh Mac | App launches as a menubar utility |
| A.4 | Grant Screen Recording and invoke the hotkey | Screenshot HUD appears |
| A.5 | Grant Accessibility and invoke the hotkey | Focused-window metadata appears when available |
| A.6 | Quit from menubar | App exits cleanly |
