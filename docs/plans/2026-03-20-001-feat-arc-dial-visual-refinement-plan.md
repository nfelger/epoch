---
title: "feat: Arc dial visual refinement"
type: feat
status: completed
date: 2026-03-20
origin: docs/brainstorms/2026-03-20-arc-dial-visual-refinement-brainstorm.md
---

# feat: Arc dial visual refinement

## Overview

Polish the arc dial's visual appearance with six targeted changes: thicker/longer ticks, semi-transparent arc, flat start cap, white knob, and a muted color palette. All changes are confined to `Epoch/Views/ArcDialView.swift`.

## Proposed Solution

All changes happen in the `drawArc`, `drawTickMarks`, and `revolutionColor` methods of `ArcDialView.swift`. No new files or architectural changes needed.

## Acceptance Criteria

- [x] Tick marks are 3pt stroke width (up from 1.5pt)
- [x] Tick marks extend 1pt beyond the track on both inner and outer edges (16pt total span vs 14pt track)
- [x] Active arc is drawn at 80% opacity so ticks are visible through it
- [x] Arc uses `.butt` line cap (flat at 12 o'clock origin); the knob provides the round-end appearance
- [x] Knob is fully opaque white in all states (idle, dragging, running countdown)
- [x] Revolution colors use a muted/desaturated palette for all four tiers
- [x] Visual appearance matches the reference mockup provided in the brainstorm

## Implementation Steps

### Step 1: Thicker, longer tick marks

**File:** `Epoch/Views/ArcDialView.swift`, `drawTickMarks` method (lines 102-118)

- Change tick stroke width from `1.5` to `3` (line 116)
- Adjust `innerR` from `radius - lineWidth / 2` to `radius - lineWidth / 2 - 1` (1pt inner protrusion)
- Adjust `outerR` from `radius + lineWidth / 2` to `radius + lineWidth / 2 + 1` (1pt outer protrusion)

### Step 2: Semi-transparent active arc

**File:** `Epoch/Views/ArcDialView.swift`, `drawArc` method

- On full revolution arc strokes (line 162): change `.color(color)` to `.color(color.opacity(0.8))`
- On partial arc stroke (line 173): same change — `.color(color.opacity(0.8))`
- Background track and ticks remain at current opacity (no change)

**Note:** At 2+ stacked revolutions, tick visibility diminishes (0.8^2 = 64% opaque, 0.8^3 = 51%). This is acceptable — ticks are most useful during the first revolution. (see brainstorm: docs/brainstorms/2026-03-20-arc-dial-visual-refinement-brainstorm.md)

### Step 3: Flat line cap (butt cap)

**File:** `Epoch/Views/ArcDialView.swift`, shared `StrokeStyle` (line 135)

- Change `lineCap: .round` to `lineCap: .butt`
- The knob circle at the arc endpoint already provides the visual round-end appearance (18pt diameter > 14pt track width)
- No separate round-cap element needed

### Step 4: White opaque knob

**File:** `Epoch/Views/ArcDialView.swift`

- Zero-angle knob (line 150): change `.color(.accentColor)` to `.color(.white)`
- Active knob (line 180): change `.color(revolutionColor(revolution: fullRevolutions))` to `.color(.white)`

### Step 5: Muted color palette

**File:** `Epoch/Views/ArcDialView.swift`, `revolutionColor` method (lines 184-191)

Replace current vivid colors with softer, desaturated versions:

| Revolution | Current | New (approximate) |
|---|---|---|
| 0 (0-60min) | `.accentColor` (system blue) | Cornflower/muted blue — e.g. `Color(red: 0.55, green: 0.68, blue: 0.85)` |
| 1 (60-120min) | `(0.85, 0.25, 0.3)` vivid red | Soft rose — e.g. `Color(red: 0.82, green: 0.50, blue: 0.50)` |
| 2 (120-180min) | `(0.7, 0.15, 0.5)` vivid magenta | Gentle mauve — e.g. `Color(red: 0.70, green: 0.48, blue: 0.62)` |
| 3+ (180min+) | `(0.45, 0.1, 0.6)` deep purple | Muted purple — e.g. `Color(red: 0.55, green: 0.42, blue: 0.68)` |

These are starting values — expect iteration after visual review.

## Testing

- `make lint` and `make test` must pass
- Manual visual verification:
  - Open popover, verify ticks are visible and extend slightly beyond track
  - Drag arc to ~180°, confirm ticks show through the semi-transparent arc
  - Verify flat start at 12 o'clock, knob provides rounded end
  - Drag past 360° to verify muted color progression across revolutions
  - Verify white knob in idle state, during drag, and during countdown
  - Check appearance in both light mode and dark mode (white knob may need future adjustment for light mode)

## Sources

- **Origin brainstorm:** [docs/brainstorms/2026-03-20-arc-dial-visual-refinement-brainstorm.md](docs/brainstorms/2026-03-20-arc-dial-visual-refinement-brainstorm.md) — key decisions: 80% arc opacity, 3pt ticks extending beyond track, butt cap + knob approach, white knob in all states, muted palette
- **Primary file:** `Epoch/Views/ArcDialView.swift` — all changes confined here
