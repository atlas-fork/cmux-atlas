# Release

Prepare a new fork release for cmux Atlas. This command updates the changelog, bumps the build number, commits, tags, and pushes.

## Fork Versioning Scheme

cmux Atlas keeps `MARKETING_VERSION` aligned with upstream (manaflow-ai/cmux). Fork releases use the tag scheme:

```
v{upstream-version}-atlas.{N}
```

Examples: `v0.62.2-atlas.1`, `v0.62.2-atlas.2`, `v0.63.0-atlas.1`

- **MARKETING_VERSION** stays at the upstream version (e.g., `0.62.2`)
- **CURRENT_PROJECT_VERSION** (build number) increments each fork release for Sparkle auto-update
- When upstream bumps their version and we sync, reset the atlas suffix to `.1`

## Steps

1. **Determine the next atlas tag**
   - Find the latest tag: `git describe --tags --abbrev=0`
   - If latest is `v0.62.2-atlas.1`, next is `v0.62.2-atlas.2`
   - If upstream version was bumped since last release, use `v{new-upstream}-atlas.1`

2. **Gather changes since the last release**
   - Get commits since that tag: `git log --oneline <last-tag>..HEAD --no-merges`
   - **Filter for end-user visible changes only** - ignore developer tooling, CI, docs, tests
   - Categorize changes into: Added, Changed, Fixed, Removed

3. **Update the changelog**
   - Add a new section at the top of `CHANGELOG.md` with the atlas tag and today's date
   - **Only include changes that affect the end-user experience**
   - Write clear, user-facing descriptions (not raw commit messages)

4. **Bump the build number**
   - Run: `./scripts/bump-version.sh build`
   - This increments `CURRENT_PROJECT_VERSION` while keeping `MARKETING_VERSION` aligned with upstream
   - Sparkle uses the build number to detect updates

5. **Commit and tag**
   - Stage: `CHANGELOG.md`, `GhosttyTabs.xcodeproj/project.pbxproj`, and any changed source files
   - Commit message: `release: v0.62.2-atlas.2`
   - Tag: `git tag v0.62.2-atlas.2`
   - Push: `git push origin main --tags`

6. **Monitor the release workflow**
   - Watch: `gh run watch --repo atlascodesai/cmux-atlas`
   - Verify the release appears at: https://github.com/atlascodesai/cmux-atlas/releases
   - Check that the DMG and appcast.xml are attached to the release

7. **Verify auto-update**
   - Existing cmux Atlas installs should detect the update via Sparkle
   - The appcast at `https://github.com/atlascodesai/cmux-atlas/releases/latest/download/appcast.xml` should reflect the new build number

8. **Notify**
   - On success: `say "cmux atlas release complete"`
   - On failure: `say "cmux atlas release failed"`

## Changelog Guidelines

**Include only end-user visible changes:**
- New features users can see or interact with
- Bug fixes users would notice (crashes, UI glitches, incorrect behavior)
- Performance improvements users would feel
- UI/UX changes
- Breaking changes or removed features

**Exclude internal/developer changes:**
- Setup scripts, build scripts, reload scripts
- CI/workflow changes
- Documentation updates (README, CONTRIBUTING, CLAUDE.md)
- Test additions or fixes
- Internal refactoring with no user-visible effect
- Dependency updates (unless they fix a user-facing bug)

**Writing style:**
- Use present tense ("Add feature" not "Added feature")
- Group by category: Added, Changed, Fixed, Removed
- Be concise but descriptive
- Focus on what the user experiences, not how it was implemented

## Example Changelog Entry

```markdown
## [0.62.2-atlas.2] - 2026-03-25

### Fixed
- Reduce memory usage and CPU spikes from AI session detection scanning large files
- Improve Cmd+Shift+T to restore closed terminal tabs with AI session resume
```
