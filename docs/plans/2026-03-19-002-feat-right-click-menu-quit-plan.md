---
title: "feat: Add right-click menu with Quit and About actions"
type: feat
status: completed
date: 2026-03-19
---

# feat: Add right-click menu with Quit and About actions

The app is menubar-only (`NSApp.setActivationPolicy(.accessory)`) with no Dock icon and no app menu, so there is currently no way to quit gracefully. Right-clicking the status bar icon should show an `NSMenu` with "About Epoch" and "Quit Epoch" items.

## Acceptance Criteria

- [x] Right-click on the menubar icon shows an `NSMenu` with two items: "About Epoch" and "Quit Epoch" (separated by a divider)
- [x] Left-click continues to toggle the popover exactly as before (including the 200ms debounce)
- [x] "Quit Epoch" calls `NSApp.terminate(nil)` immediately — no confirmation dialog, even if a timer is running
- [x] "About Epoch" shows the standard macOS About panel (`NSApp.orderFrontStandardAboutPanel`)
- [x] "Quit Epoch" menu item has `keyEquivalent: "q"` for keyboard accessibility
- [x] Popover dismisses naturally (`.transient` behavior) when the context menu appears — no special handling needed
- [x] Update `CHANGELOG.md` with the new feature

## Technical Approach

**Click detection mechanism:** Use `button.sendAction(on: [.leftMouseUp, .rightMouseUp])` on the status bar button, then inspect `NSApp.currentEvent?.type` in the action handler to branch:

- `.leftMouseUp` → toggle popover (existing behavior)
- `.rightMouseUp` → show context menu via `menu.popUp(positioning:at:in:)` relative to the button

This avoids setting `statusItem.menu` (which would hijack left-click) and keeps the existing target/action pattern intact.

**Menu construction:** Build the `NSMenu` lazily in AppDelegate with two items + separator:

1. "About Epoch" → `NSApp.orderFrontStandardAboutPanel(nil)`
2. Separator
3. "Quit Epoch" → `NSApp.terminate(nil)`, `keyEquivalent: "q"`

## MVP

All changes in `Epoch/AppDelegate.swift`:

1. In `applicationDidFinishLaunching`, after setting `button.action` and `button.target`, add:
   ```swift
   button.sendAction(on: [.leftMouseUp, .rightMouseUp])
   ```

2. Build context menu (lazy property or method):
   ```swift
   private lazy var contextMenu: NSMenu = {
       let menu = NSMenu()
       let aboutItem = NSMenuItem(title: "About Epoch", action: #selector(showAbout), keyEquivalent: "")
       menu.addItem(aboutItem)
       menu.addItem(.separator())
       let quitItem = NSMenuItem(title: "Quit Epoch", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
       menu.addItem(quitItem)
       return menu
   }()
   ```

3. Modify `togglePopover()` to check event type:
   ```swift
   @objc func togglePopover() {
       if NSApp.currentEvent?.type == .rightMouseUp {
           if let button = statusItem.button {
               contextMenu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height), in: button)
           }
           return
       }
       // ... existing popover toggle logic unchanged ...
   }
   ```

4. Add `showAbout` handler:
   ```swift
   @objc func showAbout() {
       NSApp.orderFrontStandardAboutPanel(nil)
   }
   ```

## Sources

- Existing AppDelegate: `Epoch/AppDelegate.swift` (lines 24-29 for status item setup, lines 43-53 for togglePopover)
- Learnings doc: `docs/solutions/how-to/macos-menubar-countdown-timer-swift.md` (200ms debounce gotcha)
