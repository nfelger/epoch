# Adding a macOS App Icon with XcodeGen and Asset Catalogs

## Problem

Epoch had no app icon — Finder, Spotlight, and Activity Monitor showed the generic macOS placeholder. The project uses XcodeGen (`project.yml`) so the asset catalog needed to be wired up correctly.

## Key Findings

### XcodeGen: xcassets must go under `sources`, not `resources`

The `resources` stanza in `project.yml` was effectively empty (only contained entitlements, which were excluded). XcodeGen did not generate a `PBXResourcesBuildPhase` at all, and adding the xcassets path there had no effect — `xcodegen generate` silently ignored it.

**Fix:** Add the xcassets path as a `sources` entry. XcodeGen auto-detects `.xcassets` folders and assigns them to the resources build phase:

```yaml
sources:
  - path: Epoch
    excludes:
      - Resources
  - path: Epoch/Resources/Epoch.xcassets
```

You also need the build setting:

```yaml
settings:
  base:
    ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon
```

This must be in `project.yml` (not just the generated pbxproj) so it survives `xcodegen generate`. The `actool` compiler then automatically injects `CFBundleIconFile` and `CFBundleIconName` into the compiled Info.plist — no manual plist edits needed.

### macOS does NOT auto-mask app icons

Unlike iOS, macOS does **not** apply the rounded-rectangle (squircle) mask to app icons. You must bake the shape into your PNG assets. A full-bleed square icon will look out of place next to every other app in Finder.

Apple's icon grid for the 1024x1024 canvas:
- **Shape size:** 824x824 centered (100px transparent gutter on all sides)
- **Corner radius:** ~185px (22.5% of shape width)
- **Lighting:** Top-lit gradient (lighter at top, darker at bottom)

### Icon generation pipeline (zero dependencies)

A standalone Swift script (`scripts/generate_icon.swift`) draws the icon using CoreGraphics — no external tools needed. `sips` (ships with macOS) handles resizing the 1024px master to all 9 smaller sizes. A `make icon` target orchestrates both steps.

Required sizes (10 slots in `Contents.json`): 16, 32, 32, 64, 128, 256, 256, 512, 512, 1024 — covering @1x and @2x for 16pt through 512pt.

## Prevention

- When adding resources to an XcodeGen project, verify the generated `project.pbxproj` actually references them (`grep` for the filename). XcodeGen silently drops resources it can't resolve.
- Always check the built `.app/Contents/Resources/` directory to confirm assets are compiled into the bundle.
- After deploying a new icon, run `killall Finder` to clear the icon cache.
