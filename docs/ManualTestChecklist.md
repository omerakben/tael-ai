# Manual test checklist

## PR 1 shell

- [ ] Open `TAELMacAgent/TAELMacAgent.xcodeproj`.
- [ ] Set the Apple Development Team ID in Xcode.
- [ ] Build the `TAELMacAgent` scheme.
- [ ] Launch the app.
- [ ] Confirm the app appears as a menubar utility.
- [ ] Confirm no normal app window opens on launch.
- [ ] Open the menubar menu.
- [ ] Select `Show HUD placeholder`.
- [ ] Confirm the HUD appears without switching focus unnecessarily.
- [ ] Select `Quit TAEL AI`.
- [ ] Confirm the app exits cleanly.

## Week 1 heartbeat

- [ ] Press the hotkey while Terminal is focused.
- [ ] Confirm HUD appears without switching app focus unnecessarily.
- [ ] Deny Screen Recording and confirm the permission gate appears.
- [ ] Grant Screen Recording and confirm the screenshot appears.
- [ ] Confirm the screenshot is not persisted to disk.
- [ ] Confirm invocation timing is logged locally.
- [ ] Confirm the app does not crash if permission is denied.
- [ ] Confirm the app does not crash in full-screen mode.
- [ ] Confirm display-containing-cursor targeting works.
- [ ] Confirm fallback to main display works.
- [ ] Confirm the app can be quit cleanly from the menubar.
