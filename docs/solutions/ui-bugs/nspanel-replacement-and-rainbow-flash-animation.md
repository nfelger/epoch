---
title: NSPopover Arrow Removal and Rainbow Flash Animation
category: ui-bugs
date: 2026-03-20
tags:
  - nsstatusitem
  - nspopover
  - nspanel
  - flash-animation
  - sf-symbols
  - menu-bar-ui
  - variable-value
component: AppDelegate
symptom: >
  NSPopover arrow/tip cannot be hidden; NSStatusBarButton .backgroundColor
  attribute on attributed strings renders broken; NSImageView subview of
  NSStatusBarButton causes persistent vertical misalignment of SF Symbols
---

# NSPopover Arrow Removal and Rainbow Flash Animation

## Problem

Two related UI issues in the menu bar:

1. **NSPopover shows an arrow/tip** pointing to the status item. There is no public API to hide it. System menu bar panels (e.g., Battery) appear as flat rectangles with no arrow.

2. **Flash animation on timer finish looked broken.** The original implementation used `NSMutableAttributedString` with `.backgroundColor` on `NSStatusBarButton.attributedTitle`. Background color attributes render clipped and misaligned in the menu bar.

## Investigation

### NSPopover replacement

NSPopover has no `showsArrow` or equivalent property. The only public-API solution is to replace it with a manually managed `NSPanel`.

### Flash animation — failed approaches

**Attempt 1: NSImageView subview with `addSymbolEffect`**

Added an `NSImageView` as a subview of `NSStatusBarButton` with `.addSymbolEffect(.variableColor.iterative)`. The rainbow colors rendered correctly, but the icon was always mispositioned — too high in the button.

**Attempt 2: Manual frame math**

Tried computing the frame with `NSStatusBar.system.thickness`, centering with `(button.bounds.width - size) / 2`, and applying `y` offsets. Failed because:
- `button.bounds` can be stale (layout hasn't settled after `statusItem.length` change)
- The `rainbow` SF Symbol's bounding box includes text-baseline whitespace below the arc
- Manual `y` offsets are heuristic guesses that vary with point size

**Attempt 3: Auto Layout constraints**

Replaced manual frame math with `centerXAnchor`/`centerYAnchor` constraints on the NSImageView. Still appeared too high — Auto Layout correctly centers the *bounding box*, but the rainbow arc's visual center is above the bounding box center due to baseline whitespace.

### Root cause

**NSStatusBarButton has built-in image alignment logic for its `.image` property** that correctly handles SF Symbol bounding boxes in the menu bar context. This alignment does not apply to subviews. Any NSImageView added as a subview will position based on the symbol's full bounding box (including baseline whitespace), causing visual misalignment.

## Solution

### 1. NSPanel replacing NSPopover

Borderless `NSPanel` with `NSVisualEffectView` for the vibrancy/rounded-corner appearance:

```swift
let panelSize = NSSize(width: 174, height: 174)
panel = NSPanel(
    contentRect: NSRect(origin: .zero, size: panelSize),
    styleMask: [.borderless, .nonactivatingPanel],
    backing: .buffered,
    defer: false
)
panel.backgroundColor = .clear
panel.isOpaque = false
panel.hasShadow = true
panel.level = .popUpMenu

let visualEffect = NSVisualEffectView(frame: NSRect(origin: .zero, size: panelSize))
visualEffect.material = .popover
visualEffect.blendingMode = .behindWindow
visualEffect.state = .active
visualEffect.wantsLayer = true
visualEffect.layer?.cornerRadius = 12
visualEffect.layer?.masksToBounds = true
```

**Positioning:** Computed from the button's screen-coordinate rect, centered horizontally, 6pt gap below the menu bar. Clamped horizontally to the button's screen.

**Click-outside dismissal:** `NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown])`. Monitor stored and removed on panel close. Also removed in `applicationWillTerminate`.

**Re-open debounce:** 200ms `lastPanelCloseTime` guard to prevent the dismiss click from immediately re-opening the panel.

**Width freezing:** `statusItem.length = 72` while the panel is open, with a `frozen` guard in `updateStatusItem()` that skips length changes when `panel.isVisible`.

### 2. Rainbow flash animation using `button.image` with `variableValue`

Instead of an NSImageView subview, set `button.image` directly with `NSImage(systemSymbolName:variableValue:)` on a Timer:

```swift
let config = NSImage.SymbolConfiguration.preferringMulticolor()
let steps = 6
let interval = 0.175
let totalTicks = Int(8.0 / interval)
var tick = 0

flashTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] timer in
    MainActor.assumeIsolated {
        guard let self else { timer.invalidate(); return }
        let variableValue = Double(tick % steps) / Double(steps - 1)
        let image = NSImage(
            systemSymbolName: "rainbow",
            variableValue: variableValue,
            accessibilityDescription: nil
        )?.withSymbolConfiguration(config)
        image?.isTemplate = false
        self.statusItem.button?.image = image
        tick += 1
        if tick >= totalTicks {
            timer.invalidate()
            self.flashTimer = nil
            self.timerModel.cancel()
        }
    }
}
```

This works because NSStatusBarButton's `.image` rendering pipeline handles SF Symbol vertical alignment correctly for the menu bar context — no manual positioning needed.

## Prevention

1. **Never add subviews to NSStatusBarButton.** Use `button.image` and `button.title` exclusively. The button's internal layout handles SF Symbol bounding boxes; subviews bypass this.

2. **Never use `.backgroundColor` on attributed strings for menu bar text.** It renders broken. Use image-based approaches instead.

3. **Use `NSImage(systemSymbolName:variableValue:)` for animated SF Symbols in the menu bar.** It avoids the NSImageView subview requirement of `addSymbolEffect` while giving direct control over animation timing.

4. **When replacing NSPopover with NSPanel**, implement: click-outside dismissal via global event monitor, re-open debounce, width freezing, and monitor cleanup on termination.

## Related

- [Popover Jumping and Interaction Fixes](popover-jumping-and-interaction-fixes.md) — width freezing pattern, flash timer cleanup
- [NSStatusItem Right-Click Context Menu](../how-to/nsstatusitem-right-click-context-menu.md) — button event handling preserved through the migration
- [Building Epoch Architecture](../how-to/macos-menubar-countdown-timer-swift.md) — full architecture reference, double-toggle debounce pattern
