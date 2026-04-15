# Atlas Test Practice

Atlas behavior does not fit a single code coverage number.

- Shell wrapper tests live in `atlas-tests/shell/`
- CLI/socket regression tests live in `atlas-tests/socket/`
- Swift runtime seams live in `cmuxTests/AtlasFeatureTests.swift`

Use **feature coverage** for Atlas-specific functionality:

`covered Atlas feature areas / total Atlas feature areas`

## Current matrix

| Atlas feature area | Tier | Status | Coverage |
| --- | --- | --- | --- |
| Claude wrapper behavior | shell | covered | `atlas-tests/shell/test_claude_wrapper_atlas.py` |
| Codex wrapper behavior | shell | covered | `atlas-tests/shell/test_codex_wrapper.py` |
| Auto-resume on exit hooks | socket | covered | `atlas-tests/socket/test_auto_resume_on_exit.py` |
| Terminal local-file routing (Finder vs external vs cmux browser) | swift | covered | `cmuxTests/AtlasFeatureTests.swift` |
| Atlas-specific settings defaults | swift | covered | `cmuxTests/AtlasFeatureTests.swift` |
| Quick-launch terminal behavior (new pane + command + cwd) | swift | covered | `cmuxTests/AtlasFeatureTests.swift` |
| Quick-launch menu shortcuts / menu wiring | swift/menu | covered | `cmuxTests/AtlasFeatureTests.swift` |
| Early main-window autosave sanitizer (`NSScreen` startup regression seam) | swift/startup | covered | `cmuxTests/AtlasFeatureTests.swift` |
| Memory diagnostics / Atlas CLI inspection flows | swift/socket | covered | `cmuxTests/AtlasFeatureTests.swift` |
| Tracked workspace memory accounting / footer meter | unit | covered outside Atlas harness | `cmuxTests/TabManagerUnitTests.swift` |

Current practical Atlas feature coverage for these areas is:

`10 / 10 = 100.0%`

Adjacent regressions that still matter but are not part of the Atlas-specific denominator:

| Related feature area | Tier | Status | Coverage |
| --- | --- | --- | --- |
| Workspace stale-selection regressions | non-atlas | not in Atlas harness | already better suited to existing unit/UI suites |

Treat this as a working baseline, not a release metric.

## Rules for new Atlas changes

1. If the behavior is wrapper logic, add or update a shell Atlas test.
2. If the behavior is a CLI hook or socket-visible side effect, add or update a socket Atlas test.
3. If the behavior is pure Swift logic, expose a small runtime seam and test it from `AtlasFeatureTests`.
4. If the behavior is UI-only or startup-only, either:
   - cover it in the existing UI/unit suites, or
   - document why an Atlas test is not practical yet.
5. Do not count grep-style tests, project-file assertions, or source-shape tests as Atlas coverage.

## Recommended local workflow

1. Run `./scripts/test-atlas.sh --shell`
2. Build a tagged app with `./scripts/reload.sh --tag <tag>`
3. Run `./scripts/test-atlas.sh --tag <tag>`
4. If the Atlas matrix changed, update this document in the same branch
