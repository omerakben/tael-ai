# TODO for Ozzy

Items that require owner input before this repo is truly buildable
on a real Mac. Nothing here blocks PR 1, but PR 2 will start to feel
the pain if these are not resolved.

## Signing and identity

- [ ] **Set Apple Developer Team ID in Xcode.**
  The project ships with `DEVELOPMENT_TEAM` left blank. Open
  `TAELMacAgent/TAELMacAgent.xcodeproj` → project → `TAELMacAgent` target →
  Signing & Capabilities → set Team. Do **not** select "Sign to Run Locally"
  (ad-hoc) for daily dev — TCC permissions are keyed to bundle identity
  and signing requirements; ad-hoc signing makes Screen Recording /
  Accessibility / Microphone debugging noisy and irreproducible.
- [ ] **Choose preferred local signing identity.**
  Apple Development is correct for Debug builds. Confirm which
  developer account / identity is used so the team can avoid
  flapping TCC entries. Document it in `docs/PermissionNotes.md`
  once chosen.
- [ ] **Confirm bundle ID `ai.tael.macagent` is acceptable long-term.**
  Used as the stable TCC identity. Changing it later resets all
  granted permissions on every dev machine.

## Repo and naming

- [ ] **Confirm repo name `tael-ai` should remain, or move to
  `tael-mac-agent` later.** The macOS app is `TAELMacAgent` regardless,
  but the repo name is flexible until the wider TAEL surface area
  (`tuel-ai`, `toel-ai`) starts existing.
- [ ] **Confirm GitHub Issues should be created manually or via CLI.**
  Maestro Claude does not have `gh` access and does not auto-open
  Issues from this run. Week 1 ticket checklist lives in
  [`docs/Week1Heartbeat.md`](docs/Week1Heartbeat.md). If you want a
  one-issue-per-ticket layout, tell Claude/Codex on the next run and
  it can be created via the GitHub MCP server.

## Branches

- [ ] **Confirm branch model.** The plan says:
  - `main` — frozen plan + scaffold
  - `dev-claude` — Maestro Claude
  - `dev-codex` — Codex
  
  This run created `dev-claude` from `main` and developed there.
  PR is opened against `main` as a draft per repo policy.

## Build / test status from PR 1

- [ ] **Run `xcodebuild` locally.**
  This run was performed in a Linux container with no Xcode toolchain.
  `xcodebuild`, `swift build`, and `swiftformat` were not available, so
  the project was not compiled here. Source files follow the v0.3 layout
  and the `PermissionsGate` tokenized pattern, but a real Xcode build
  on macOS 14.0+ is the only ground truth. To verify:

  ```bash
  xcodebuild -project TAELMacAgent/TAELMacAgent.xcodeproj \
             -scheme TAELMacAgent \
             -configuration Debug \
             -destination 'platform=macOS' \
             clean build
  xcodebuild -project TAELMacAgent/TAELMacAgent.xcodeproj \
             -scheme TAELMacAgent \
             -destination 'platform=macOS' \
             test
  ```

  Expected: clean build, all `TAELMacAgentTests` pass, app launches as a
  menubar utility, Quit menu works.

## Future, intentionally deferred

These are *not* PR 1 problems but Ozzy-side decisions that will land soon:

- [ ] Decide product name. v0.3 is explicit: do this **after** the
  Week 1 heartbeat works.
- [ ] Decide release signing model (Developer ID + notarization).
- [ ] Decide on KeyboardShortcuts package source (sindresorhus/KeyboardShortcuts)
  vs hand-rolled. PR 2 will need to add it via SPM.
- [ ] Decide on a HUD design language. PR 1 ships an intentionally
  ugly placeholder.
