# Atlas Commit Classification

This is the current review of the Atlas fork delta relative to `main`, using:

- merge base: `e9afc22353128d7c9fa273d8432cbf2fe0e36157`
- reviewed branch tip: `feat/rebuild-ai-resume-core` as of `2026-04-13`

The goal is to separate:

- Atlas product work we intentionally carry
- rebuild/parity work that was needed to land the line cleanly
- test/docs/process work
- pure release markers

## 1. Atlas Product Features And User-Facing Fixes

These commits materially define or refine Atlas behavior on the rebuilt line.

| Commit | Type | Summary |
| --- | --- | --- |
| `6345ad23` | feature | Establish Atlas branding, app identity, and release shell |
| `3ea7063b` | feature | Add AI session resume, editor sync, memory monitor, and markdown panel workflows |
| `f60ccdc1` | fix | Refresh memory state and avoid session-snapshot pasteboard recursion |
| `edb8c5f7` | fix | Restore editor sync and panel recovery parity |
| `aceeafc0` | fix | Restore workspace tab affordances and inline resume restore |
| `82c62af1` | fix | Restore terminal link and tab affordance parity |
| `eda6f17b` | fix/ui | Move organization actions to the menu bar and improve current-workspace organization affordances |
| `668319fc` | fix(atlas) | Respect the browser toggle when opening local terminal file links |
| `0acf308f` | fix(atlas) | Realign the Claude wrapper with upstream behavior while preserving Atlas hook/session behavior |
| `dc4005f2` | cleanup | Remove dead Atlas fork code that no longer contributes to product behavior |

Notes:

- This is the set to think of as the current Atlas product surface.
- `atlas-docs/feature-inventory.md` is the current user-facing summary of what this bucket contains.

## 2. Rebuild / Parity / Merge-Smoothing Work

These commits were necessary to make the rebuilt line function correctly on a fresh upstream base, but they are not the clearest expression of Atlas differentiation by themselves.

| Commit | Type | Summary |
| --- | --- | --- |
| `4de5a4f9` | rebuild-fix | Align AI resume core with the fresh upstream state |
| `f6df6884` | rebuild-fix | Restore resume observability and recovery behavior |
| `ac7d9e26` | rebuild-fix | Align resume recovery with the rebuilt upstream state |
| `6063afa2` | rebuild-fix | Avoid depending on newer Bonsplit-only tab-bar hooks |
| `84dc3c02` | rebuild-fix | Update Bonsplit for restored workspace tab affordances |

Notes:

- Some of this work protects real runtime behavior.
- Even so, this bucket mainly reflects the cost of carrying the rebuilt fork cleanly.

## 3. Tests, Docs, And Process

These commits improve confidence, maintainability, and workflow rather than shipping end-user features directly.

| Commit | Type | Summary |
| --- | --- | --- |
| `e7617daa` | test | Cover workspace tab path actions on the rebuilt line |
| `63577ead` | build | Remove a release build warning |
| `c0a9cbde` | ci | Stabilize release signing by setting the temporary keychain as default |
| `84977f80` | docs/process | Add upstream sync workflow and local ideas scratch |
| `5a45d79b` | test | Add the Atlas regression test harness |
| `00b848ad` | test | Add Atlas feature tests to the Swift test target |
| `2c49d7a2` | test | Fix Atlas test expectations and Swift failure parsing |

## 4. Release Markers

These commits are release/version markers rather than standalone feature work.

| Commit | Tag |
| --- | --- |
| `47683d67` | `v1.38.1-atlas.6` |
| `4469143f` | `v1.38.1-atlas.7` |
| `e764205e` | `v1.38.1-atlas.8` |
| `61cbb355` | `v0.63.1-atlas.1` |
| `2713d157` | `v0.63.1-atlas.2` |
| `36965896` | `v0.63.1-atlas.3` |
| `a68b4d86` | `v0.63.1-atlas.4` |
| `98122b98` | `v0.63.1-atlas.5` |
| `9d53c684` | `v0.63.1-atlas.6` |
| `a7ed34b6` | `v0.63.1-atlas.7` |
| `06feceaa` | `v0.63.1-atlas.8` |
| `46157faa` | `v0.63.1-atlas.9` |
| `53d1b911` | `v0.63.1-atlas.10` |
| `a8a68f6c` | `v0.63.1-atlas.11`, `v0.63.1-atlas.12`, `v0.63.1-atlas.13` |

## 5. Practical Read

When summarizing the fork:

1. Talk about section 1 as the current Atlas product.
2. Mention section 2 only when discussing rebuild cost, maintenance burden, or upstream-sync risk.
3. Mention section 3 when discussing release confidence, workflow, or repo quality.
4. Do not confuse section 4 with new feature delivery.
