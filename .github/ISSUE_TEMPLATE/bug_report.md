---
name: Bug report
about: Report something that does not work in the TAEL macOS agent
title: "[bug] "
labels: ["bug"]
assignees: []
---

## Summary

<!-- One sentence: what is broken. -->

## Environment

- macOS version:
- Mac model / chip:
- App version / commit SHA:
- Bundle ID (should be `ai.tael.macagent`):
- Signing identity (Apple Development / Developer ID / ad-hoc):

## Steps to reproduce

1.
2.
3.

## Expected behavior

## Actual behavior

## Permission state at time of bug

- [ ] Screen Recording granted
- [ ] Screen Recording denied
- [ ] Screen Recording prompt never appeared
- [ ] N/A (bug is not permission-related)

If the bug involves TCC weirdness, paste the output of:

```bash
./scripts/reset-tcc-dev.sh --dry-run
```

## Logs / evidence

<!-- Paste relevant `LocalLogService` lines, screenshots, or
     console output. Do NOT paste any personal info from screenshots. -->

## Severity guess

- [ ] Crash / data loss
- [ ] Heartbeat broken (hotkey → screenshot → HUD)
- [ ] Recoverable, blocks current milestone
- [ ] Cosmetic
