# Week 1 heartbeat

## Definition of done

```text
Press hotkey while Terminal is focused.
HUD appears without switching app focus unnecessarily.
If Screen Recording is missing, permission gate appears.
If Screen Recording is granted, screenshot appears.
Screenshot is not persisted to disk.
Invocation timing is logged locally.
App does not crash if permission is denied.
App does not crash in full-screen mode.
App can be quit cleanly from menubar.
```

## Screenshot target

The Week 1 screenshot target is the display containing the cursor, with fallback to the main display.

The ScreenCaptureKit path must use:

```text
SCScreenshotManager.captureImage(contentFilter:configuration:)
```

Do not use `captureImage(in:)` for the macOS 14.0+ target.

## Implementation ticket checklist

- [ ] 0. Lock bundle ID, macOS 14.0+ target, signing team, and debug signing identity.
- [ ] 1. Create native macOS menubar shell.
- [ ] 2. Add ProtectedAPICallPolicy.md.
- [ ] 3. Add PermissionKind and PermissionStatus.
- [ ] 4. Implement PermissionsChecker v0 for Screen Recording only.
- [ ] 5. Implement PermissionsGate v0.
- [ ] 6. Add KeyboardShortcuts package.
- [ ] 7. Add HUDPanelController placeholder.
- [ ] 8. Add ScreenCaptureService.
- [ ] 9. Wire hotkey -> screen gate -> screenshot capture.
- [ ] 10. Render screenshot in HUD.
- [ ] 11. Add local invocation log.
- [ ] 12. Add manual test checklist.

## PR 1 status

PR 1 creates the shell, docs, boundary types, and placeholders. It does not implement screenshot capture or the real global hotkey.

## GitHub issues

- `#1` - 0. Lock bundle ID, macOS 14.0+ target, signing team, and debug signing identity.
- `#2` - 1. Create native macOS menubar shell.
- `#3` - 2. Add ProtectedAPICallPolicy.md.
- `#4` - 3. Add PermissionKind and PermissionStatus.
- `#5` - 4. Implement PermissionsChecker v0 for Screen Recording only.
- `#6` - 5. Implement PermissionsGate v0.
- `#7` - 6. Add KeyboardShortcuts package.
- `#8` - 7. Add HUDPanelController placeholder.
- `#9` - 8. Add ScreenCaptureService.
- `#10` - 9. Wire hotkey -> screen gate -> screenshot capture.
- `#11` - 10. Render screenshot in HUD.
- `#12` - 11. Add local invocation log.
- `#13` - 12. Add manual test checklist.
