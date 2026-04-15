# Atlas Feature Inventory

This is the current Atlas-owned product surface we intentionally carry on top of upstream cmux.

## App identity and coexistence

- `cmux Atlas` branding, separate bundle identity, and tagged debug runs that can coexist with upstream/dev builds
- Atlas-specific release line, update channel, and fork packaging

## Agent workflow layer

- Claude wrapper integration with hook injection and session tracking
- Codex wrapper integration with PATH-based resolution and session-end handling
- Auto-resume helpers for supported agent sessions when exit hooks or saved state indicate a resumable conversation
- Quick-launch entry points for Claude Code and Codex from both the titlebar and the File menu
- Editor sync affordances for opening the current workspace in a linked editor
- Workspace-scoped AI resume refresh and recovery diagnostics

## Memory tracking and diagnostics

- Per-workspace tracked memory meter in the sidebar/footer
- Persistent memory diagnostics history, incident records, and archived MetricKit payload metadata
- CLI/socket inspection commands:
  - `cmux memory-history`
  - `cmux memory-incidents`
  - `cmux memory-metrickit`
  - `cmux memory-dump`

## Local file and link handling

- Browser-link toggle for deciding whether terminal links open inside cmux or externally
- Atlas local-file routing rules so non-renderable files reveal in Finder instead of incorrectly opening in the embedded browser
- Working-directory path actions such as `Reveal in Finder` and external-editor handoff
- Native markdown panel workflows for markdown/file-link handling

## Atlas-owned docs/tests/process

- Atlas feature-coverage matrix and local Atlas test workflow
- Atlas regression harness:
  - `atlas-tests/shell/`
  - `atlas-tests/socket/`
  - `cmuxTests/AtlasFeatureTests.swift`
- Atlas devlog and architecture notes under `atlas-docs/`

## Notes

- Not every cmux capability is Atlas-specific. The embedded browser, general workspace model, and most core terminal behavior are still upstream/shared product surface.
- If a future upstream change lands the same behavior natively, remove it from this list instead of keeping a stale “Atlas-only” claim around.
