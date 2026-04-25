## Summary

-

## Scope

- [ ] Native macOS menubar utility scope only
- [ ] No protected API bypass added
- [ ] No out-of-scope Week 1 features added

## Validation

```sh
xcodebuild -project TAELMacAgent/TAELMacAgent.xcodeproj -scheme TAELMacAgent -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```

```sh
xcodebuild -project TAELMacAgent/TAELMacAgent.xcodeproj -scheme TAELMacAgent -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test
```

## Notes for reviewers

- Stable bundle ID: `ai.tael.macagent`
- Deployment target: macOS 14.0+
- `DEVELOPMENT_TEAM` may be blank until Ozzy sets the local team in Xcode.
