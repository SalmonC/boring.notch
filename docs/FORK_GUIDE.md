# Fork Maintenance Guide (SalmonC)

This repository is a fork of [TheBoredTeam/boring.notch](https://github.com/TheBoredTeam/boring.notch).

## 1. Upstream and License

- Upstream project: `TheBoredTeam/boring.notch`
- This fork continues to follow **GPL-3.0** (see `LICENSE` in repo root).
- Keep original copyright and license notices.
- New files/changes in this fork should include clear modification history when needed.

## 2. Versioning Policy for This Fork

To clearly distinguish fork builds from upstream:

- Marketing version format: `2.7.3-salmonc.N`
- Build number (`CURRENT_PROJECT_VERSION`) increments with each release build.

Example:

- `2.7.3-salmonc.15 (286)`

## 3. Documentation Policy for Fork Changes

For every functional change, document:

- What changed (feature/bugfix)
- Why it changed (user-visible issue)
- Scope and non-goals (what is intentionally not changed)
- License/attribution impact (if any third-party code/assets are added)

Recommended locations:

- High-level usage/install: `README.md`
- Fork governance/licensing/version policy: `docs/FORK_GUIDE.md`
- Release notes per version: section below (append new entries)

## 4. Fork Release Notes

### 2.7.3-salmonc.17 (288) - 2026-03-02

- Fixed clipped selection border in shelf items after adding `Clear` control.
- Adjusted shelf list padding to keep full highlight stroke visible.

### 2.7.3-salmonc.16 (287) - 2026-02-28

- Rebased fork changes onto `upstream/dev` for validation build.
- Fixed `ShelfStateViewModel` compatibility on `dev` branch (`resolveFileURL` mismatch).
- Built and packaged a dev-based test DMG for local installation.

### 2.7.3-salmonc.15 (286) - 2026-02-28

- Shelf `Remove` drag/drop behavior stabilized.
- Removed unnecessary state publications/re-renders in remove-zone targeting logic.
- No change to source-file deletion behavior: removing from shelf does not delete origin files.

### 2.7.3-salmonc.14 (285) - 2026-02-28

- Improved drag animation behavior when dragging shelf items into `Remove`.
- Avoided "fly back then disappear" in remove-path.

### 2.7.3-salmonc.12-13 (283-284) - 2026-02-28

- Fixed notch auto-close behavior after drag operations.
- Added robust remove-zone handling for shelf-internal drag/drop.

## 5. Packaging and Installation (Local)

Build release:

```bash
xcodebuild -project boringNotch.xcodeproj -scheme boringNotch -configuration Release -derivedDataPath build
```

Create DMG:

```bash
hdiutil create -volname "boringNotch" \
  -srcfolder build/Build/Products/Release/boringNotch.app \
  -ov -format UDZO \
  /absolute/path/to/boringNotch.dmg
```

Install to `/Applications`:

```bash
hdiutil attach /absolute/path/to/boringNotch.dmg -nobrowse
cp -R /Volumes/boringNotch/boringNotch.app /Applications/boringNotch.app
hdiutil detach /Volumes/boringNotch
```

## 6. Suggested Workflow for Future Fork Changes

1. Implement feature/fix.
2. Run local build validation.
3. Bump fork version (`salmonc.N` + build number).
4. Update `docs/FORK_GUIDE.md` release notes.
5. Commit with explicit scope and push.
