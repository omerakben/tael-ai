# Permission notes

## Stable identity

Screen Recording permission is tied to the app identity. Before TCC testing, keep these stable:

- bundle ID: `ai.tael.macagent`
- deployment target: macOS 14.0+
- signing identity: Apple Development
- Apple Development Team ID: set locally by Ozzy

`DEVELOPMENT_TEAM` is intentionally blank in the scaffold because the local team ID was not available in this environment.

## Screen Recording

Week 1 only implements real permission work for Screen Recording.

`PermissionsChecker` v0 reports `.screenRecording` with the macOS preflight path. Future permissions return `.unsupported` until their milestones.

## Missing permission behavior

When Screen Recording is missing, `PermissionsGate` must:

1. ask the permission UI to show the gate state,
2. throw `PermissionError.missing(.screenRecording)`,
3. avoid running the protected operation.

## TCC reset

After the bundle ID and signing identity are stable, reset local Screen Recording state with:

```sh
scripts/reset-tcc-dev.sh
```

Use this only for local development debugging.
