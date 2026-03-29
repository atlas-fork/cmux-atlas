# Upstream Merge Guide

How to review and integrate `upstream/main` without destabilizing the Atlas release line.

This replaces the older "merge directly into fork main" approach. `main` is now the stable Atlas line. Upstream review happens on a separate branch.

## Current Branch Roles

- `main`: stable Atlas release line
- `review/upstream-sync-YYYYMMDD`: temporary branch for upstream assessment and merge work
- `archive/merged-upstream-attempt-20260328`: preserved failed large merge attempt

## Rules

1. Never merge `upstream/main` directly into `main`.
2. Do not refactor the app first "to make the merge easier". Review the actual merge surface first.
3. Keep the release line shippable. All risky merge work stays on the review branch.
4. Prefer cherry-picking high-value upstream fixes if the full merge still touches too many shared-runtime files.

## Recommended Flow

### 1. Start from stable `main`

```bash
git checkout main
git fetch upstream
git pull --ff-only origin main
git switch -c review/upstream-sync-$(date +%Y%m%d)
```

### 2. Measure the gap first

```bash
git rev-list --left-right --count HEAD...upstream/main
git log --oneline $(git merge-base HEAD upstream/main)..upstream/main
git log --oneline upstream/main..HEAD
```

Questions to answer before touching code:

- How many upstream commits are we behind?
- Which shared runtime files are hot?
- Which of our fork-only commits are Atlas-specific versus upstreamable?

### 3. Dry-run the merge in an isolated worktree

Do not dirty the review branch just to inspect conflicts.

```bash
tmpdir=$(mktemp -d /tmp/cmux-merge-review-XXXXXX)
git worktree add --detach "$tmpdir" HEAD
cd "$tmpdir"
git merge --no-commit --no-ff upstream/main || true
git diff --name-only --diff-filter=U
```

When finished:

```bash
cd /Users/timapple/Documents/guest/cmux-fork
git worktree remove --force "$tmpdir"
```

### 4. Classify the result before merging anything

Use these buckets.

#### Bucket A: Mechanical fork policy files

These usually need "keep ours, manually carry upstream additions".

- `.github/workflows/*.yml`
- `scripts/reload.sh`
- `tests/test_ci_self_hosted_guard.sh`
- release/nightly pipeline files
- branding-sensitive shell integration files

#### Bucket B: Shared runtime files

These are the real risk. Do not pretend they are mechanical.

- `CLI/cmux.swift`
- `Sources/AppDelegate.swift`
- `Sources/TabManager.swift`
- `Sources/Workspace.swift`
- `Sources/GhosttyTerminalView.swift`
- `Sources/ContentView.swift`
- `Sources/Panels/TerminalPanel.swift`

If these files have wide conflict blocks, assume the work is an integration project, not a quick sync.

#### Bucket C: Additive upstream files

These are often worth taking even if the full merge is deferred.

- `Sources/CmuxConfig.swift`
- `Sources/CmuxConfigExecutor.swift`
- `Sources/CmuxDirectoryTrust.swift`
- new tests
- docs and localization additions

#### Bucket D: Project and submodule drift

- `GhosttyTabs.xcodeproj/project.pbxproj`
- `vendor/bonsplit`
- `ghostty` submodule pointer if applicable

Treat these separately. Do not bury them inside source conflict work.

## Decision Tree

### If the merge is mostly Bucket A + C

Proceed with the merge on the review branch.

### If the merge is heavy in Bucket B

Do not start with a broad refactor. Do one of these instead:

1. Build a cherry-pick shortlist of upstream fixes with high value and low merge risk.
2. Merge only after deciding which runtime behaviors we are willing to change.
3. Keep the review branch open until CI is green. `main` stays untouched.

## Less Invasive Strategy

The default strategy should be:

1. Review from stable `main`.
2. Dry-run merge.
3. Cherry-pick a shortlist first.
4. Only do a full upstream merge if the shortlist is not enough.

This is intentionally less invasive than the old approach. It avoids a large pre-merge refactor that can create its own regressions.

## What Usually Belongs Upstream

Good upstream candidates are small, generic fixes that are not Atlas-branded:

- generic crash guards
- generic session/state restore fixes
- context menu improvements that are not Atlas-specific
- generic signing or release fixes if they are not tied to our fork infrastructure

Poor upstream candidates:

- Atlas branding
- AI session resume
- editor sync
- Atlas-specific release/update channel logic
- fork-specific CI runner setup

## When Doing the Real Merge

If you choose to merge on the review branch:

```bash
git merge --no-commit --no-ff upstream/main
```

Then resolve in this order:

1. mechanical fork policy files
2. additive upstream files
3. shared runtime files
4. project/submodule drift

Do not trust old `rerere` resolutions blindly for shared-runtime files. They can replay decisions from a bad prior merge attempt.

## Validation

Do not run the full test suite locally.

Local validation:

```bash
./scripts/reload.sh --tag upstream-review
```

Then push the review branch and use GitHub Actions for:

- unit tests
- UI regressions
- nightly/build workflows
- compatibility runs

## Release Rule

Nothing from upstream reaches users until it lands cleanly on `main` and the release line is healthy again.
