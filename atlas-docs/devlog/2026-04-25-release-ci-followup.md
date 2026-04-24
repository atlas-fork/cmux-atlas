# 2026-04-25

- Bumped the Atlas build number to cut `v0.63.1-atlas.21` on a non-`release:` commit subject so the normal GitHub CI workflows run on the release commit before the tag-triggered publish workflow.
- Updated the local release instructions in `AGENTS.md` and `CLAUDE.md` to stop using the `release:` commit prefix that suppresses CI on `main` pushes.
