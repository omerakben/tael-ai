# Summary

<!-- 1-3 bullets: what changed, why now. Link the milestone in v0.3. -->

-

## Scope check (v0.3)

- [ ] Inside the v0.3 milestone scope (no scope creep)
- [ ] No protected macOS API call bypasses `PermissionsGate`
- [ ] Week 1 only: Screen Recording is the only real permission check
- [ ] Screenshot path uses `SCScreenshotManager.captureImage(contentFilter:configuration:)`
      (not `captureImage(in:)`) when applicable
- [ ] No screenshot, audio, or transcript persisted to disk unless the
      milestone explicitly added it
- [ ] No new third-party package without an entry in `docs/Architecture.md`

## Permissions impact

<!-- If this PR touches any TCC-protected surface (Screen Recording,
     Accessibility, Microphone, Apple Events, Input Monitoring), describe
     the gate path, the failure UX, and the recovery path. Otherwise: N/A. -->

-

## Test plan

- [ ] `xcodebuild ... clean build` succeeds locally on macOS 14.0+
- [ ] `xcodebuild ... test` passes
- [ ] App launches as menubar utility and quits cleanly from menu
- [ ] Manual checks from `docs/ManualTestChecklist.md` relevant to this PR

## Out of scope / follow-ups

-

## Risk

- [ ] Low — purely additive, behind a feature
- [ ] Medium — touches PermissionsGate / capture path
- [ ] High — touches signing, entitlements, or executor

## Screenshots / recordings

<!-- Optional. Drag in a HUD screenshot or short clip for UI changes. -->

---

🤖 Generated with [Claude Code](https://claude.com/claude-code)
