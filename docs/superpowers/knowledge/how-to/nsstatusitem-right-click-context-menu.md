# Adding a Right-Click Context Menu to an NSStatusItem

## Problem

A menubar-only macOS app using `NSApp.setActivationPolicy(.accessory)` has no Dock icon or app menu, so users have no way to quit or access the About panel. The app needs a right-click context menu on the status bar icon while preserving left-click for toggling an NSPopover.

## Solution

### Gotcha 1: Receiving right-click events on NSStatusBarButton

`NSStatusBarButton`'s default `sendAction(on:)` only fires on left-click. You must explicitly configure it to also receive right-click events:

```swift
button.sendAction(on: [.leftMouseUp, .rightMouseUp])
```

Then inspect `NSApp.currentEvent?.type` in the action handler to branch:

```swift
@objc func togglePopover() {
    guard let button = statusItem.button else { return }
    if NSApp.currentEvent?.type == .rightMouseUp {
        contextMenu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height), in: button)
        return
    }
    // ... existing popover toggle logic ...
}
```

**Why not `statusItem.menu`?** Setting `statusItem.menu` hijacks left-click too — the menu shows on both click types, replacing your custom popover action.

### Gotcha 2: About panel invisible in accessory-mode apps

In apps using `.accessory` activation policy, `NSApp.orderFrontStandardAboutPanel(nil)` opens the About panel but it remains invisible because the app isn't active. You must activate the app first:

```swift
@objc func showAbout() {
    NSApp.activate(ignoringOtherApps: true)
    NSApp.orderFrontStandardAboutPanel(nil)
}
```

This applies to any window or panel presentation in accessory-mode apps — `NSWindow.makeKeyAndOrderFront`, `NSAlert.runModal`, etc.

### Full implementation

```swift
// Lazy context menu property
private lazy var contextMenu: NSMenu = {
    let menu = NSMenu()
    menu.addItem(NSMenuItem(title: "About Epoch", action: #selector(showAbout), keyEquivalent: ""))
    menu.addItem(.separator())
    let quit = NSMenuItem(
        title: "Quit Epoch",
        action: #selector(NSApplication.terminate(_:)),
        keyEquivalent: "q"  // Cmd+Q by default
    )
    menu.addItem(quit)
    return menu
}()

// In applicationDidFinishLaunching, after button.action and button.target:
button.sendAction(on: [.leftMouseUp, .rightMouseUp])

// About handler — must activate app first
@objc func showAbout() {
    NSApp.activate(ignoringOtherApps: true)
    NSApp.orderFrontStandardAboutPanel(nil)
}

// Modified togglePopover to handle right-click
@objc func togglePopover() {
    guard let button = statusItem.button else { return }
    if NSApp.currentEvent?.type == .rightMouseUp {
        contextMenu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height), in: button)
        return
    }
    // ... existing popover toggle logic unchanged ...
}
```

## Prevention

- **Always activate the app** before presenting any window or panel in accessory-mode apps
- **Use `sendAction(on:)` + event inspection** when you need different behavior for left-click vs right-click on a status bar button — don't set `statusItem.menu`
- **Test both click types** after any change to status item click handling

## Related

- [Building a macOS menubar countdown timer](macos-menubar-countdown-timer-swift.md) — covers the NSStatusItem/NSPopover architecture this builds on
