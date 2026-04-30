# Alpha release checklist

This checklist is for the internal alpha DMG only. It is not the public
launch process.

## Prerequisites

- Apple Developer Program account has a Developer ID Application certificate.
- The certificate is installed in the local login keychain.
- A notary profile exists:

```bash
xcrun notarytool store-credentials tael-notary
```

- `security find-identity -v -p codesigning` shows the Developer ID identity.
- Screen Recording and Accessibility flows have passed the manual checklist.

## Build and package

```bash
DEVELOPER_ID_APPLICATION="Developer ID Application: OMER FARUK AKBEN (...)" \
NOTARYTOOL_PROFILE="tael-notary" \
VERSION="0.1.0-alpha.1" \
./scripts/package-alpha-dmg.sh
```

The script archives the Release app, signs with Developer ID, notarizes and
staples the app, creates a DMG, notarizes and staples the DMG, and runs
Gatekeeper checks.

## Required validation

- `git diff --check`
- `make xcodeproj`
- `make test`
- `make build`
- `codesign --verify --deep --strict --verbose=2 <path>/TAELMacAgent.app`
- `xcrun stapler validate <path>/TAELMacAgent-<version>.dmg`
- `spctl -a -vvv <path>/TAELMacAgent.app`
- `spctl -a -vvv --type open <path>/TAELMacAgent-<version>.dmg`

## Manual install smoke test

- Open the DMG from a clean user account or fresh Mac.
- Drag `TAELMacAgent.app` to Applications.
- Launch the app and confirm the menubar item appears.
- Press `Command-Shift-T` from Terminal or VS Code.
- Grant Screen Recording, quit and relaunch, then verify screenshot HUD.
- Grant Accessibility and verify focused-window app/title metadata appears.
- Revoke Screen Recording and verify TAEL shows the permission gate.
- Confirm no screenshots or AX context files are written to disk.

## Known alpha constraints

- Manual DMG only. Sparkle auto-update is deferred.
- App Sandbox remains off for alpha while ScreenCaptureKit, hotkey, and AX
  behavior are still being proven together.
- Developer ID certificate and notary credentials are local machine
  prerequisites and are not committed to the repo.
