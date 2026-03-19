# Brainstorm: App Bundle Icon

**Date:** 2026-03-18
**Status:** Draft

## What We're Building

A macOS app icon for Epoch that visually echoes the in-app arc dial UI. The icon will be monochrome (black/white/gray), hand-crafted as SVG or programmatic drawing, and included in the app bundle via an asset catalog.

Even though Epoch is a menubar-only app (LSUIElement), the icon appears in Finder, Spotlight, Activity Monitor, Force Quit, and the About dialog. A proper icon replaces the generic "app" placeholder and gives Epoch a recognizable identity.

## Why This Approach

- **Arc/dial concept** — Maintains visual continuity between the icon and the app's primary UI element. Users who see the icon in Finder will immediately associate it with the circular timer they interact with.
- **Monochrome palette** — Fits the macOS system aesthetic, ages well across light/dark mode, and keeps the design simple.
- **Hand-crafted in code/SVG** — No external design tool dependencies. Easy to iterate and version-control friendly. Aligns with the project's zero-dependency philosophy.

## Key Decisions

1. **Visual concept:** Arc/dial inspired — echoes the app's circular countdown UI
2. **Color palette:** Monochrome (black, white, gray)
3. **Creation method:** Hand-crafted SVG or programmatic generation — no external design tools
4. **Arc state:** Flexible — optimize for legibility at small sizes (16x16 through 1024x1024)

## Design Considerations

- macOS app icons need sizes: 16, 32, 64, 128, 256, 512, 1024 (with @1x and @2x variants)
- The icon must read clearly at 16x16 — fine details will be lost, so the arc stroke needs to be bold enough
- Monochrome icons should have good contrast in both light and dark Finder backgrounds
- The rounded-rect mask is applied automatically by macOS — design within the full square canvas
## Open Questions

1. **Asset pipeline:** SVG-to-PNG conversion at build time requires a tool (e.g. `rsvg-convert`), adding a dependency. Alternative: author the SVG once, render PNGs at all required sizes, and commit the PNGs directly. The SVG stays in the repo as the editable source but the PNGs are the actual build input. Which approach to use is a planning decision.
