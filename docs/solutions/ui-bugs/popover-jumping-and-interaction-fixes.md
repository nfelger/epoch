---
title: "Fix popover jumping, auto-close, and flash-state drag blocking"
category: ui-bugs
date: 2026-03-20
tags:
  - popover
  - nsstatusitem
  - flash-sequence
  - drag-gesture
component: AppDelegate, ArcDialView
---

# Popover Jumping and Interaction Fixes

## Problems

Three related UX issues with the menubar popover:

1. **Popover jumped around** when the status bar item width changed (e.g., timer starting, crossing hour boundary, flash animation)
2. **Popover closed on timer start**, preventing immediate adjustments after setting a duration
3. **Arc dial was unresponsive during flash sequence** — couldn't drag to set a new timer while the finished-state flash was running

## Root Causes

### Popover jumping
`statusItem.length` was changed dynamically (between `squareLength`, `56`, and `72`) while the popover was anchored to the status item button. Each width change shifted the anchor point, causing the popover to jump.

### Auto-close
`handleStateTransitions()` explicitly closed the popover on `.inactive → .running` transition via `DispatchQueue.main.async { self?.popover.close() }`.

### Drag blocked during flash
`ArcDialView.handleDragEnded` only handled `.inactive` state. In `.finished` state (during flash), drags were ignored. Additionally, `model.cancel()` from the view didn't clean up the flash timer owned by `AppDelegate`.

## Solution

### Freeze status item width while popover is open

```swift
// In togglePopover(), before showing:
statusItem.length = 72  // max width, accommodates H:MM:SS

// In updateStatusItem(), skip length changes:
let frozen = popover.isShown
if !frozen { statusItem.length = NSStatusItem.variableLength }

// On popover close, restore correct width:
func popoverDidClose(_ notification: Notification) {
    syncStatusItemLength()
}

private func syncStatusItemLength() {
    if timerModel.state == .inactive {
        statusItem.length = NSStatusItem.squareLength
    } else {
        statusItem.length = NSStatusItem.variableLength
    }
}
```

Use `NSStatusItem.variableLength` instead of hardcoded widths (56/72) — AppKit sizes to fit the actual content.

### Remove auto-close

Delete the `popover.close()` call from `handleStateTransitions()`. The popover's `.transient` behavior already handles closing when the user clicks elsewhere.

### Allow drag during flash, centralize flash cleanup

```swift
// In ArcDialView, cancel model on drag start in .finished state:
if model.state == .finished {
    model.cancel()
}

// In AppDelegate, detect .finished → .inactive and clean up flash:
if currentState == .inactive, previousState == .finished {
    flashTimer?.invalidate()
    flashTimer = nil
}
```

This centralizes flash cleanup in `AppDelegate` (where the timer is owned) rather than requiring every cancel path to know about it.

## Key Insight

When an `NSPopover` is anchored to an `NSStatusItem` button, any change to `statusItem.length` repositions the popover. The fix is to freeze the width at the maximum needed value while the popover is shown, then restore dynamic sizing on close. `NSStatusItem.variableLength` is preferable to hardcoded widths for the non-frozen case.

## Prevention Tips

- When anchoring UI to a status item, never change `statusItem.length` while that UI is visible.
- When multiple code paths can cancel a timer/animation, centralize cleanup in the object that owns the timer rather than duplicating invalidation logic.

## Related

- [Epoch architecture](../how-to/macos-menubar-countdown-timer-swift.md) — AppDelegate coordinator pattern, observation loop
- [Arc dial visual refinement](../how-to/swiftui-canvas-arc-dial-visual-refinement.md) — companion visual changes made in the same session
