# Flash Animation Redesign

**Date:** 2026-03-20

---

## Goal

Replace the current flash animation (which uses `.backgroundColor` on `NSAttributedString` — broken in the menu bar) with a 3-frame SF Symbol strobe cycle that fires when the countdown finishes.

### The Cycle (repeating, 0.3s per tick)

| Tick (mod 3) | Status item appearance |
|---|---|
| 0 | Completely empty — no image, no text, item collapses |
| 1 | `slowmo` SF Symbol, bright orange (`NSColor.systemOrange`) |
| 2 | `timelapse` SF Symbol, bright red (`NSColor.systemRed`) |

- **Duration:** ~3 seconds (10 ticks), then auto-cancel and revert to idle clock icon
- **Blank tick:** `button?.image = nil`, `button?.title = ""` — the item shrinks to near-zero width for dramatic pop-in effect
- **Post-flash state:** normal idle clock icon (same as current inactive state)

---

## Why This Approach

### Problems with current implementation
The current flash uses `.backgroundColor` on `NSMutableAttributedString` applied to `NSStatusBarButton.attributedTitle`. Background color attributes on menu bar text are unreliable — they render clipped, misaligned, or inconsistently across macOS versions and system appearances.

### Why the 3-frame strobe
- Avoids all attributed string / background color rendering: pure image swaps on `button?.image`
- The blank frame creates a stark visual contrast (item literally disappears and reappears), which is more eye-catching than a color toggle alone
- Two distinct symbols (`slowmo` → `timelapse`) carry implicit semantic meaning (time slowing → time elapsed) and provide motion-like progression within the cycle
- Bright orange + red progression reads as an escalating urgency signal without being alarming

### Why "middle ground" urgency
- Noticeable within a few seconds without being jarring
- 3-second auto-cancel keeps it brief — doesn't demand immediate action
- Reverts to idle icon, so there's no lingering "something is wrong" state

---

## Key Decisions

1. **Image-based, not text-based** — use `button?.image` with `NSImage(systemSymbolName:)`, not `attributedTitle`. Eliminates background color rendering issues.
2. **Colored (non-template) symbols** — use `NSImage.withSymbolConfiguration` with `NSImageSymbolConfiguration(paletteColors:)` or `init(hierarchicalColor:)` to force specific colors. Template images would render in the system tint and ignore the orange/red.
3. **Three-frame cycle** — `flashCount % 3` determines frame: 0 = blank, 1 = orange `slowmo`, 2 = red `timelapse`.
4. **`squareLength` during colored frames, `variableLength` or collapse during blank frame** — to allow the blank tick to actually collapse the item width.
5. **Same timer cadence** — 0.3s interval, 10 ticks, then `timerModel.cancel()`.

---

## Technical Notes

```swift
// Rendering a colored SF Symbol (non-template)
let config = NSImageSymbolConfiguration(paletteColors: [.systemOrange])
let image = NSImage(systemSymbolName: "slowmo", accessibilityDescription: nil)?
    .withSymbolConfiguration(config)
button?.image = image
button?.image?.isTemplate = false  // ensure it stays colored
```

The `isTemplate = false` flag must be set after applying the configuration, or AppKit may override the color with the system tint.
