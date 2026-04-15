# Upstream Merge Guide

This is a lightweight process note for future upstream sync work on the Atlas fork.

## Before starting

1. Review the current Atlas delta in `docs/atlas-commit-classification.md`.
2. Review the current product surface in `atlas-docs/feature-inventory.md`.
3. Review the current doc map in `atlas-docs/doc-map.md`.
4. Separate:
   - Atlas-owned product behavior
   - fork/release/CI plumbing
   - generic fixes that should be upstreamed instead of carried

## Merge workflow

1. Fetch `upstream/main`.
2. Create a dedicated review branch for the sync.
3. Land compile/merge repair changes separately from Atlas product changes whenever possible.
4. Re-run the tagged local build flow:
   - `./scripts/reload.sh --tag <merge-tag>`
5. Re-run Atlas verification as appropriate:
   - `./scripts/test-atlas.sh --shell`
   - `./scripts/test-atlas.sh --tag <merge-tag>`

## Documentation obligations after a merge

If the carried Atlas behavior changed, review and update:

- `atlas-docs/feature-inventory.md`
- `README.md`
- `CLI/cmux.swift` (`cmux welcome`)
- `docs/atlas-test-practice.md`
- `docs/cvm-cmux-codex-interplay.md`
- `CHANGELOG.md`

Also add a devlog entry under `atlas-docs/devlog/`.

## Rule

Do not treat old merge-repair commits as product requirements by default. Re-evaluate them against the current Atlas product surface first.
