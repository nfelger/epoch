# Design: Replace Popover Panel with Overlay Panel

**Date:** 2026-04-19  
**Status:** Approved

## Summary

Replace the two-panel architecture (popover panel for timer-setting + overlay panel for running/finished) with a single overlay panel that handles all states. Remove the `isOverlayMode` flag from `ArcDialView` and the `showTimerOverlay` user preference entirely.

## What Gets Deleted

**File removed:**
- `Epoch/Views/PopoverContentView.swift`

**Properties removed from `AppDelegate`:**
- `panel: NSPanel!`
- `lastPanelCloseTime: Date`
- `eventMonitor: Any?`
- `hasShownOverlayOnce: Bool`
- `showTimerOverlay: Bool` (UserDefaults computed property)

**Methods removed from `AppDelegate`:**
- `setupPopoverPanel()`
- `showPanel()`
- `hidePanel()`
- `syncStatusItemLength()`
- `toggleOverlaySetting()`

**Simplified in `AppDelegate`:**
- `togglePanel()`: collapses from ~20 lines to right-click → menu, else toggle overlay
- `updateStatusItem()`: remove `frozen`/`panel.isVisible` guard and statusItem width-freeze at 72
- `handleStateTransitions()`: remove `showOverlay()` on `.running` (overlay already open), `hidePanel()`, and `hasShownOverlayOnce = false` reset
- `buildContextMenu()`: remove "Show Timer Overlay" item and its separator
- `applicationDidFinishLaunching()`: remove `setupPopoverPanel()` call

**Changes in `ArcDialView`:**
- Remove `isOverlayMode` parameter
- Remove `isOverlayMode` branch on content shape — always use `ArcRingShape`
- Remove `isOverlayMode` branch in `drawArc` — always draw the contrast disc

## What Gets Added

**Position persistence (one line):**

In `setupOverlayPanel()`, add:
```swift
newPanel.setFrameAutosaveName("OverlayPanel")
```

AppKit automatically saves and restores the overlay's frame to UserDefaults, including off-screen validation. No manual save/restore code needed.

## End-to-End Behavior

**Inactive (no timer running)**
- Overlay is hidden
- Left-click menubar → overlay appears at last saved position (below menubar on first launch)
- Arc ring drag → sets timer duration
- Drag ends → timer starts, overlay stays open at current position
- Background drag → moves the overlay window (AppKit auto-saves position)

**Running**
- Overlay was already open (user just set the timer from it), stays open
- Left-click menubar → toggle overlay visibility
- Arc ring drag → adjusts remaining time

**Finished**
- Pulsing border, completion effects, flash sequence — unchanged
- Left-click menubar → toggle overlay visibility
- Arc ring drag → cancels timer, overlay hides

**Timer cancelled (any state)**
- `cancelTimer()` calls `hideOverlay()` — unchanged

## Tradeoffs

1. **Ring-only hit area when setting a timer.** The popover allowed dragging from anywhere in the 174×174 square. The overlay requires targeting the ring (~17pt wide including tolerance). This is already how the running overlay works today — comfortable in practice.

2. **No click-outside-to-dismiss.** The overlay does not dismiss on outside click. The close button (X) and clicking the menubar icon are the dismissal paths.

3. **`OverlayContentView` name stays.** Now the only content view, "Overlay" is a slight misnomer, but renaming is cosmetic and out of scope.

## Files Changed

| File | Change |
|------|--------|
| `Epoch/AppDelegate.swift` | Remove panel code, simplify toggle/state/menu logic, add autosave name |
| `Epoch/Views/ArcDialView.swift` | Remove `isOverlayMode` parameter and all branches on it |
| `Epoch/Views/PopoverContentView.swift` | **Delete** |
| `Epoch/Views/OverlayContentView.swift` | No changes |
