# Arc Dial Visual Refinement

**Date:** 2026-03-20

## Goal

A visual polish pass on the arc dial to improve legibility and aesthetics. Four changes:

1. **Thicker ticks (3pt)** — increase from 1.5pt to 3pt stroke width for better visibility
2. **Ticks extend beyond track** — ticks protrude past the arc on both inner and outer edges, making them more prominent gauge marks
3. **Semi-transparent arc (80% opacity)** — the active arc becomes translucent so ticks show through underneath when the arc covers them
4. **Flat start, rounded end** — the arc origin at 12 o'clock uses a butt/square cap; the end near the drag handle keeps a round cap
5. **Fully opaque white drag handle** — the knob at the arc endpoint is solid white
6. **Custom muted color palette** — softer, less saturated colors for all revolution tiers instead of the current vibrant system accent and bold RGB values

## Why This Approach

The current design hides tick marks behind the active arc, making it hard to gauge duration at a glance once you've dragged past a few ticks. The vibrant system blue is visually heavy for a utility that should feel calm and unobtrusive. A semi-transparent arc with muted colors lets the dial feel lighter while keeping ticks always visible as reference marks — like a real gauge or clock face.

## Key Decisions

- **Ticks stay behind the arc in draw order** — visibility comes from arc transparency, not from drawing ticks on top. This keeps the visual layering natural (gauge marks beneath the fill).
- **80% opacity on active arc** — enough transparency to see ticks through, but still clearly reads as a filled region.
- **3pt tick width** — double the current 1.5pt. Combined with extending beyond the track, ticks become a prominent visual scaffold.
- **Flat cap at origin only** — achieved by drawing start and end segments separately or using a path-based approach. The arc doesn't "bulge" past 12 o'clock.
- **White opaque knob** — stands out clearly against the muted arc color.
- **Muted palette for all revolutions** — softer versions of blue, red, magenta, purple for the 1h/2h/3h/4h+ tiers.

## Reference

User-provided mockup showing: cornflower blue semi-transparent arc, 3pt ticks extending beyond track, white dot handle, flat start at noon position.
