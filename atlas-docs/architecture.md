# Atlas Architecture Notes

This document is intentionally high level. It is for orientation and maintenance, not line-by-line implementation detail.

## Design rule

Atlas-specific behavior should stay concentrated in narrow seams instead of spreading fork logic across every upstream hotspot.

Preferred pattern:

- additive files or small extension seams
- explicit Atlas-owned commands/services
- tests that verify runtime behavior instead of source shape

## Main Atlas-owned subsystems

## 1. Agent wrappers and hook lifecycle

Purpose:

- inject Claude/Codex integration behavior
- preserve session metadata
- surface notifications and auto-resume hooks

Primary surfaces:

- `atlas-tests/shell/test_claude_wrapper_atlas.py`
- `atlas-tests/shell/test_codex_wrapper.py`
- `atlas-tests/socket/test_auto_resume_on_exit.py`
- wrapper resources bundled into the app

## 2. Session persistence and resume helpers

Purpose:

- track restorable agent state
- recover compatible resume actions
- prevent stale session state from overriding newer live state

Primary surfaces:

- `Sources/SessionPersistence.swift`
- `Sources/Workspace.swift`
- `Sources/TabManager.swift`
- `Sources/TerminalNotificationStore.swift`

## 3. Quick launch and menu entry points

Purpose:

- launch Claude/Codex quickly into a new terminal surface with the right working directory and command shape

Primary surfaces:

- `Sources/EditorSyncTitlebarButton.swift`
- `Sources/cmuxApp.swift`
- `Sources/Workspace.swift`

## 4. Tracked memory subsystem

Purpose:

- attribute memory/process ownership to workspaces
- expose practical diagnostics for leaks, pressure, and incident review

Primary surfaces:

- `Sources/MemoryDiagnostics.swift`
- `Sources/TerminalController.swift`
- workspace/footer memory UI surfaces in `Sources/ContentView.swift`

## 5. Terminal local-file routing

Purpose:

- make local-file clicks behave sensibly in Atlas workflows
- keep archives, media, binaries, and other non-renderable files out of the embedded browser path

Primary surfaces:

- `Sources/GhosttyTerminalView.swift`

## 6. Atlas test surface

Purpose:

- verify Atlas functionality by behavior tier instead of pretending there is one meaningful line-coverage number

Primary surfaces:

- `docs/atlas-test-practice.md`
- `cmuxTests/AtlasFeatureTests.swift`
- `atlas-tests/shell/`
- `atlas-tests/socket/`

## Operational rule

When adding a new Atlas-only feature:

1. Put it in the smallest Atlas-owned seam available.
2. Add or extend Atlas coverage in the matching tier.
3. Update `atlas-docs/feature-inventory.md` if the user-facing behavior changed.
4. Update `README.md` and `cmux welcome` if the top-level product story changed.
