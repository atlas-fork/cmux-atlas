# Atlas Devlog

The devlog is commit-oriented, not release-oriented.

Use it to record what each commit is actually delivering while the work is fresh:

- feature slice landed
- regression fixed
- test coverage added
- doc/process change introduced

Monthly files keep the history small and easy to scan.

Helper:

```bash
./scripts/atlas-devlog.sh add "Short summary" --docs "none needed"
```

The repo git hook expects a staged update under `atlas-docs/devlog/` for each normal commit.
