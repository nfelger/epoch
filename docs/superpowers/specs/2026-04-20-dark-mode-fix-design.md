# Dark Mode Fix: Material Disc + Warm Arc Palette

## Problem

The arc dial UI uses hardcoded light-mode colors (cream disc, white knob, cool-toned arcs) that look broken in dark mode. 6 of 10 color values don't adapt to the system appearance.

## Design

### Material Disc

Replace the Canvas-drawn cream disc with a SwiftUI `Circle` clipped view using `.ultraThinMaterial`. This sits behind the Canvas (which draws arcs, tick marks, and knob) as a ZStack layer.

- The Canvas background becomes transparent — it no longer draws the cream disc fill
- The material circle is sized to match the current disc radius (`arcRadius + arcLineWidth/2 + 4`)
- Materials automatically adapt to light/dark mode and blur the content behind the window

### Knob

Replace the hardcoded `.white` knob with a color that contrasts on both material surfaces:

- Use `.primary` with moderate opacity, or a light/dark adaptive approach via `Color(nsColor: .controlBackgroundColor)` which is white in light mode and dark gray in dark mode
- Given the knob sits on a material that's already adaptive, a semi-opaque white with a subtle border/shadow may work better — this needs visual testing

Recommendation: start with `Color(nsColor: .controlBackgroundColor)` and adjust during implementation.

### Arc Colors — Warm Analogous Gradient

Replace the four distinct-hue revolution colors with a warm analogous progression:

| Revolution | Color | Approx RGB |
|-----------|-------|------------|
| 0 | Amber | `(0.90, 0.65, 0.20)` |
| 1 | Orange | `(0.92, 0.50, 0.20)` |
| 2 | Coral | `(0.90, 0.38, 0.35)` |
| 3+ | Rose | `(0.88, 0.30, 0.45)` |

These are warm, saturated tones that should read well on both the light frosted and dark frosted material surfaces. The opacity stays at 0.7 as currently implemented. Exact values should be tuned visually during implementation.

### Unchanged Elements

These already adapt and need no changes:

- Track ring (`.secondary.opacity(0.2)`)
- Tick marks (`.secondary.opacity(0.4)`)
- Center text (`.secondary`, `.blue`)
- Finished border (`.red`)

## Architecture

The change is contained entirely within `ArcDialView.swift` and requires no changes to the model, AppDelegate, or OverlayContentView.

**Current ZStack structure:**
```
ZStack {
    Canvas { ... }  // draws disc, track, ticks, arcs, knob
    centerLabel()
}
```

**New ZStack structure:**
```
ZStack {
    Circle()                    // material disc (new)
        .fill(.ultraThinMaterial)
        .frame(...)
    Canvas { ... }              // draws track, ticks, arcs, knob (no disc)
    centerLabel()
}
```

The Canvas `drawArc` method loses the disc-drawing code (lines 157–163) and gains updated revolution colors and knob color.

## Testing

- Visual verification in light mode and dark mode
- Verify the material disc aligns with the arc track radius
- Verify arc colors are legible on both material surfaces
- Verify knob is visible on both surfaces
- Run existing unit tests (`make test`) to confirm no regressions
- Run `make lint` to confirm code style
