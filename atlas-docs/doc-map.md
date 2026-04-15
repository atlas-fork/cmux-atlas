# Atlas Doc Map

This is the current map of Atlas-related documentation in the repo.

## Canonical current Atlas docs in `atlas-docs/`

- `atlas-docs/feature-inventory.md`
  - current Atlas-only product surface
- `atlas-docs/architecture.md`
  - high-level Atlas subsystem ownership
- `atlas-docs/devlog/`
  - commit-oriented delivery log
- `atlas-docs/doc-map.md`
  - this file

## Canonical current Atlas docs outside `atlas-docs/`

- `README.md`
  - public product summary
- `CHANGELOG.md`
  - release notes and current unreleased delta
- `CLI/cmux.swift`
  - `cmux welcome` text
- `docs/atlas-test-practice.md`
  - Atlas test matrix and coverage rules
- `docs/cvm-cmux-codex-interplay.md`
  - wrapper/session architecture for Claude, Codex, and cvm

## Historical Atlas docs still kept in `docs/`

- `docs/atlas-commit-classification.md`
  - current commit classification for the fork delta from `main`; keep as a maintained history/audit document
- `docs/fork-rebuild-plan.md`
  - historical plan for the clean rebuild effort; no longer the primary status doc
- `docs/upstream-merge-guide.md`
  - process note for future upstream sync work

## General cmux docs that are not Atlas-specific

- `docs/agent-browser-port-spec.md`
- `docs/ghostty-fork.md`
- `docs/notifications.md`
- `docs/remote-daemon-spec.md`
- `docs/v2-api-migration.md`

## Working notes and ideas

- `docs/ideas/`
- `docs/socket-focus-steal-audit.todo.md`

These are useful, but they are not the canonical top-level Atlas product story.

## Current audit status

As of `2026-04-13`, the current Atlas story is aligned across:

- `atlas-docs/feature-inventory.md`
- `README.md`
- `CLI/cmux.swift` (`cmux welcome`)
- `docs/atlas-test-practice.md`
- `docs/cvm-cmux-codex-interplay.md`

The main historical docs are still intentionally outside `atlas-docs/`, but they are now explicitly treated as historical/process references rather than the primary product summary.
