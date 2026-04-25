# Protected API call policy

No ScreenCaptureKit call, AX read, microphone access, Apple Events call, keyboard/mouse event synthesis, subprocess action, or clipboard write may bypass the appropriate policy/gate.

## Active in Week 1

Only Screen Recording is active in Week 1.

ScreenCaptureKit work must go through `PermissionsGate` with `.screenRecording`, and the protected screenshot service must require a `PermissionGrant`.

Required call shape:

```swift
let image = try await permissionsGate.withPermission(.screenRecording) { grant in
    try await screenCaptureService.captureDisplayScreenshot(grant)
}
```

`ScreenCaptureService` must assert that the grant is for Screen Recording:

```swift
precondition(grant.kind == .screenRecording)
```

## Future policy entries

These are policy placeholders only until their milestones:

- Accessibility and AX tree reads
- Microphone capture
- Apple Events
- Input Monitoring
- keyboard and mouse event synthesis
- clipboard writes
- subprocess actions

Do not add real calls for these paths in PR 1.

## Screenshot API rule

For macOS 14.0+, screenshot capture must use:

```text
SCScreenshotManager.captureImage(contentFilter:configuration:)
```

Do not use `captureImage(in:)` unless the deployment target intentionally moves to macOS 15.2+.
