# TODO for Ozzy

## Signing and identity

- Set the Apple Developer Team ID in Xcode for `TAELMacAgent`.
- Confirm the preferred local Apple Development signing identity.
- Keep the intended dev path on Apple Development signing, not ad-hoc signing.

## Repository and project ownership

- Decide later whether this repo should remain `tael-ai` or move to `tael-mac-agent`. This run keeps `tael-ai` because the task explicitly required it.
- Week 1 GitHub Issues were created by CLI as `#1` through `#13`. Decide whether future issues should be managed manually or by CLI.

## Local validation

- If a regular signed Xcode build fails locally, set `DEVELOPMENT_TEAM` in `TAELMacAgent/TAELMacAgent.xcodeproj`.
- Use `scripts/reset-tcc-dev.sh` only after the bundle ID and signing identity are stable.
