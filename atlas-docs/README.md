# Atlas Docs

This folder is the committed source of truth for Atlas-specific product notes that do not fit cleanly in the public README or the release-oriented changelog.

## What lives here

- `feature-inventory.md`
  - current Atlas-only functionality we intentionally carry in the fork
- `architecture.md`
  - the main Atlas-owned runtime seams, files, and subsystem boundaries
- `doc-map.md`
  - where Atlas-related docs live across the repo, and which ones are canonical vs historical
- `devlog/`
  - commit-by-commit delivery notes for active development

## Adjacent canonical docs

- [`docs/atlas-test-practice.md`](../docs/atlas-test-practice.md)
  - Atlas test matrix and feature-coverage rules
- [`docs/atlas-commit-classification.md`](../docs/atlas-commit-classification.md)
  - historical classification of Atlas-only commits
- [`CHANGELOG.md`](../CHANGELOG.md)
  - release notes
- [`README.md`](../README.md)
  - public product summary

## Freshness rules

1. If Atlas user-facing behavior changes, update `feature-inventory.md`.
2. If the high-level product summary changes, update both `README.md` and `cmux welcome`.
3. If Atlas runtime boundaries or ownership move, update `architecture.md`.
4. Every commit should add a short delivery note in `devlog/`.
5. Release notes still belong in `CHANGELOG.md`; the devlog is more granular and commit-oriented.

## Devlog workflow

The repo-managed git hook blocks commits that do not stage a devlog update.

Install hooks once per clone:

```bash
./scripts/install-git-hooks.sh
```

Append a devlog entry:

```bash
./scripts/atlas-devlog.sh add "Short summary of what this commit delivers" --docs "none needed"
```
