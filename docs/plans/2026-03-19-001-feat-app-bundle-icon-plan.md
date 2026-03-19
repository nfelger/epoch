---
title: "feat: Add app bundle icon"
type: feat
status: completed
date: 2026-03-19
origin: docs/brainstorms/2026-03-18-app-icon-brainstorm.md
---

# feat: Add App Bundle Icon

## Overview

Add a monochrome arc/dial app icon to the Epoch bundle so it shows a recognizable identity in Finder, Spotlight, Activity Monitor, and Force Quit — instead of the generic macOS app placeholder.

The icon echoes the app's arc dial UI: a thick circular arc stroke on an opaque background (see brainstorm: `docs/brainstorms/2026-03-18-app-icon-brainstorm.md`).

## Proposed Solution

### Asset pipeline

Author a 1024x1024 master PNG. Use `sips` (ships with macOS — no new dependency) to generate all smaller sizes. Keep the SVG as an editable source file but the PNGs are what Xcode compiles.

A `make icon` target automates the `sips` resizing from the master PNG.

### Icon design

- **Shape:** Circular arc (~270°) with round line caps, echoing ArcDialView's 14pt stroke weight (scaled proportionally). Faint background ring behind the arc, similar to the dial's secondary track.
- **Background:** Opaque dark fill (near-black, e.g. `#1C1C1E`) filling the full 1024x1024 canvas. macOS applies the rounded-rect mask automatically. This ensures contrast in both light and dark Finder backgrounds.
- **Foreground:** White/light gray arc and track. Monochrome as decided in brainstorm.
- **Small sizes:** Same design at all sizes — the arc shape is bold enough to read at 16x16. No simplified variant needed.

### Asset catalog structure

```
Epoch/Resources/Epoch.xcassets/
└── AppIcon.appiconset/
    ├── Contents.json
    ├── icon_16x16.png
    ├── icon_16x16@2x.png      (32px)
    ├── icon_32x32.png          (32px, same file as 16@2x)
    ├── icon_32x32@2x.png      (64px)
    ├── icon_128x128.png
    ├── icon_128x128@2x.png    (256px)
    ├── icon_256x256.png       (256px, same file as 128@2x)
    ├── icon_256x256@2x.png    (512px)
    ├── icon_512x512.png       (512px, same file as 256@2x)
    └── icon_512x512@2x.png   (1024px, the master)
```

10 slots total. Where pixel dimensions match (e.g. 16@2x = 32@1x), use distinct filenames pointing to the same pixel data — Xcode expects separate entries in `Contents.json` even if the file content is identical.

### project.yml change

Add to `settings.base`:

```yaml
ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon
```

This must be in `project.yml` (not just the generated pbxproj) so it survives `xcodegen generate`. The existing `resources` stanza already includes `Epoch/Resources/` — the xcassets directory will be picked up automatically.

## Acceptance Criteria

- [x] `make build` produces an `.app` with the custom icon visible in Finder (not the generic placeholder)
- [x] Icon renders legibly at 16x16 (Activity Monitor) through 512x512@2x (Finder gallery)
- [x] Icon is visible against both light and dark Finder backgrounds
- [x] `xcodegen generate && make build` succeeds cleanly (no asset catalog warnings)
- [x] `make icon` regenerates all PNG sizes from the 1024px master
- [x] `make lint` and `make test` still pass
- [x] CHANGELOG.md updated with entry under `[Unreleased]`

## Out of Scope

- **About dialog** — No existing code path to show it. Track separately if desired.
- **Finder icon cache busting** — Developer responsibility; not automated in `make deploy`.
- **Dark-mode variant icon** — Single opaque-background icon works in both modes.

## Implementation Steps

1. **Create the SVG source** — `Epoch/Resources/AppIcon.svg`, monochrome arc/dial design on dark background, 1024x1024 viewBox
2. **Render master PNG** — Export SVG to `icon_512x512@2x.png` (1024px) manually or via any tool
3. **Add `make icon` target** — Uses `sips -z` to resize the master into all 9 remaining sizes
4. **Create asset catalog** — `Epoch/Resources/Epoch.xcassets/AppIcon.appiconset/` with `Contents.json`
5. **Update `project.yml`** — Add `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon` to `settings.base`
6. **Regenerate & build** — `xcodegen generate && make build` to verify
7. **Update CHANGELOG.md** — Add entry under `[Unreleased]`

## Sources

- **Origin brainstorm:** [docs/brainstorms/2026-03-18-app-icon-brainstorm.md](docs/brainstorms/2026-03-18-app-icon-brainstorm.md) — Key decisions: arc/dial concept, monochrome palette, hand-crafted creation, no external dependencies
- **ArcDialView visual reference:** `Epoch/Views/ArcDialView.swift` — 14pt stroke, round caps, secondary track at 0.2 opacity, 12 tick marks
- **project.yml resource config:** `project.yml` — existing `resources` path covers `Epoch/Resources/`
