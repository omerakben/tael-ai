# Repository Guidelines

## Project structure and module organization

This repository is planning-first. The tracked files are the TAEL AI mac agent build plans:

- `TAEL_AI_mac_agent_build_plan.md`: original plan.
- `TAEL_AI_mac_agent_build_plan_v0_2.md`: implementation freeze notes.
- `TAEL_AI_mac_agent_build_plan_v0_3.md`: current repo-ready source of truth.

The planned native app root is `TAELMacAgent/`. When source is added, keep the structure from the v0.3 plan: `App/`, `Hotkey/`, `Permissions/`, `HUD/`, `Capture/`, `Voice/`, `Planner/`, `Skills/`, `Executor/`, `Logging/`, `Settings/`, and `Resources/`. Keep policy docs under `TAELMacAgent/docs/`.

## Build, test, and development commands

There are no committed build scripts, package manager files, or runnable Xcode project files yet. Do not invent commands in documentation or PR notes.

Useful current checks:

- `git status --short --branch`: confirm branch and local changes.
- `git diff --check`: catch whitespace issues before committing.
- `git diff -- TAEL_AI_mac_agent_build_plan_v0_3.md`: review plan edits.

Once Swift source is committed, document the real Xcode scheme and `xcodebuild` command in this file.

## Coding style and naming conventions

Markdown should use sentence-case headings, concise sections, and concrete file or command examples. Keep the v0.3 plan as the implementation authority unless a newer plan explicitly supersedes it.

For future Swift code, use native Swift and SwiftUI with AppKit where needed. Prefer one primary type per file, `UpperCamelCase` for types, `lowerCamelCase` for methods and properties, and four-space indentation. Protected macOS APIs must route through `PermissionsGate`; no ScreenCaptureKit, Accessibility, microphone, Apple Events, or executor path should bypass it.

## Testing guidelines

No automated test framework is committed yet. For documentation-only changes, validate by reading the rendered Markdown intent and checking `git diff --check`.

For app work, add or update `ManualTestChecklist.md` with concrete cases: permission missing state, permission retry, global hotkey, screenshot capture, HUD display, latency, and blocked or confirm-required actions.

## Commit and pull request guidelines

Existing history uses conventional-style commits, for example `chore: initialize TAEL AI planning repo`. Continue with `type: concise summary`, such as `docs: add contributor guide` or `chore: scaffold mac app`.

Pull requests should include the changed files, validation performed, and known gaps. For UI or HUD changes, include screenshots or a short screen recording. For permission or executor changes, call out the safety path and any manual TCC reset steps used.

## Agent-specific instructions

Preserve the v0.3 implementation freeze unless the user explicitly changes direction. Do not add production dependencies, YAML skill registries, broad automation, or raw shell execution paths without confirmation. Hardcoded Swift skills come before YAML.

## Workflow (agreed 2026-04-25)

Three-tier collaboration under Ozzy:

```text
Ozzy (final arbiter)
  └─ Claude Opus 4.7 (maestro) — talks to Ozzy directly
       ├─ Sonnet 4.6 high   — small/bounded tasks
       └─ Codex (gpt-5.5)   — build tasks
```

Codex is a **delegated worker** in this workflow. The maestro (Claude Opus 4.7) selects tasks for Codex, reviews output before integration, and surfaces contested calls to Ozzy. Codex does not converse with Ozzy directly during normal operation.

Branch flow:

```text
main ← develop ← feature/*
```

`develop` is the integration target. Feature branches PR into `develop`; `develop` PRs into `main`. The original `dev-codex` and `dev-claude` parallel branches were a one-off experiment and are being retired after the first integration.

Codex profile rule (see `.codex/config.toml`):

| Profile     | Model     | Effort   | Use for                           |
| ----------- | --------- | -------- | --------------------------------- |
| default     | `gpt-5.5` | `high`   | build, refactor, debug, test      |
| `fast`      | `gpt-5.5` | `medium` | review and check passes ONLY      |
| `thorough`  | `gpt-5.5` | `xhigh`  | hardest architectural decisions   |

Never invoke `fast` for building. Never invoke the default for trivial review-only passes.

The full source of truth for the workflow lives in Claude's per-project memory under `~/.claude/projects/.../memory/` (`feedback_workflow.md`, `project_role_hierarchy.md`, `feedback_codex_model_selection.md`, `project_branches.md`). This AGENTS.md mirror exists so Codex sessions get the same context.
