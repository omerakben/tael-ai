---
name: Implementation ticket
about: Track one scoped implementation step
title: "[Week 1] "
labels: implementation
assignees: ""
---

## Goal

What should this ticket deliver?

## Acceptance criteria

- [ ]

## Scope limits

- No AI planner.
- No speech capture.
- No AX tree.
- No executor.
- No screenshot persistence.

## Validation

Commands or manual checks required before closing:

```sh
xcodebuild -project TAELMacAgent/TAELMacAgent.xcodeproj -scheme TAELMacAgent -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```
