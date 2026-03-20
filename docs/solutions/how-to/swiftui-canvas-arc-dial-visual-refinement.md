---
title: "Refine arc dial visual style: tick marks, opacity, line caps, knob color, and color palette"
category: how-to
date: 2026-03-20
tags:
  - arc-dial
  - visual-polish
  - swiftui-canvas
  - opacity
  - line-caps
component: ArcDialView
---

# SwiftUI Canvas Arc Dial Visual Refinement

## Problem

The arc dial in Epoch's menubar timer had several visual issues:

1. **Thin tick marks (1.5pt)** disappeared behind the opaque active arc when dragged over them
2. **Fully opaque arc** hid all visual reference marks underneath
3. **Round line caps on both ends** created a bulbous start at 12 o'clock
4. **Knob color changed per revolution**, making it harder to track visually
5. **Vivid, saturated colors** felt heavy for a calm utility app

## Solution

All changes confined to `Epoch/Views/ArcDialView.swift`.

### 1. Thicker, extended tick marks

Widened from 1.5pt to 2pt and extended 1pt beyond the track on each side (12pt total vs 10pt track width after 25% scale-down):

```swift
let innerR = radius - lineWidth / 2 - 1  // was: radius - lineWidth / 2
let outerR = radius + lineWidth / 2 + 1  // was: radius + lineWidth / 2
// ...
style: StrokeStyle(lineWidth: 2, lineCap: .butt)  // was: lineWidth: 1.5
```

### 2. Semi-transparent arc (70% opacity)

Applied `.opacity(0.7)` to arc strokes so tick marks show through:

```swift
context.stroke(arc, with: .color(color.opacity(0.7)), style: strokeStyle)
// was: .color(color)
```

### 3. Flat start cap via .butt + knob as round end

SwiftUI `StrokeStyle.lineCap` applies uniformly to both ends — no per-end control. The workaround: use `.butt` cap for flat ends everywhere, then rely on the knob circle (14pt diameter > 10pt track width after scale-down) to create the visual round endpoint at the drag position.

```swift
let strokeStyle = StrokeStyle(lineWidth: lineWidth, lineCap: .butt)  // was: .round
```

### 4. White knob in all states

```swift
context.fill(knobPath(...), with: .color(.white))
// was: .color(.accentColor) for idle, .color(revolutionColor(...)) for active
```

### 5. Muted color palette

```swift
case 0: Color(red: 0.30, green: 0.50, blue: 0.82) // cornflower blue (was .accentColor)
case 1: Color(red: 0.82, green: 0.50, blue: 0.50) // soft rose
case 2: Color(red: 0.75, green: 0.42, blue: 0.75) // orchid
default: Color(red: 0.50, green: 0.38, blue: 0.72) // muted purple
```

## Key Insights

### Opacity compounds in stacked layers

With `opacity(0.7)` per layer, stacked revolutions compound multiplicatively: 2 layers = 51% opaque, 3 layers = 34%. Ticks are most useful during the first revolution, so this degradation is acceptable.

### StrokeStyle.lineCap is uniform on both ends

There is no built-in way to set different caps per end. Use `.butt` globally and overlay a filled circle at the desired end to simulate a round cap. The existing knob circle already serves this purpose.

### Hardcoded colors vs. system accent color

Replacing `.accentColor` with hardcoded `Color` values removes system accent color integration. This is a conscious tradeoff for deterministic appearance in a utility app.

## Prevention Tips

- When changing Canvas drawing opacity on stacked layers, always test with the maximum expected number of layers (4+ revolutions).
- Cross-check CHANGELOG entries against actual code values — write the entry after finalizing code, not before.

## Related

- [Epoch architecture: macOS menubar countdown timer](macos-menubar-countdown-timer-swift.md) — covers ArcDialView Canvas rendering, drag handling, and revolution color logic
- [Brainstorm](../../brainstorms/2026-03-20-arc-dial-visual-refinement-brainstorm.md) — design decisions and reference mockup
- [Plan](../../plans/2026-03-20-001-feat-arc-dial-visual-refinement-plan.md) — implementation steps (completed)
