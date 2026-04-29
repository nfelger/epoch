# Keyboard Support Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add URL scheme for external panel toggling and keyboard duration input for setting timers.

**Architecture:** Two independent features. Feature 1 adds `CFBundleURLTypes` to Info.plist and a URL handler in AppDelegate. Feature 2 makes the panel key-capable and adds `.onKeyPress` handling in ArcDialView to accept typed minutes.

**Tech Stack:** Swift 5.9, AppKit, SwiftUI (macOS 14+)

---

## File Map

- **Modify:** `Epoch/Info.plist` — add `CFBundleURLTypes` for `epoch` scheme
- **Modify:** `project.yml` — add `CFBundleURLTypes` to info properties (XcodeGen source of truth)
- **Modify:** `Epoch/AppDelegate.swift` — add URL handler, make panel key-capable, use `makeKeyAndOrderFront`
- **Modify:** `Epoch/Views/ArcDialView.swift` — add `typeBuffer` state, `.onKeyPress` handler, clear buffer on drag

---

### Task 1: URL Scheme Registration

**Files:**
- Modify: `Epoch/Info.plist`
- Modify: `project.yml`

- [ ] **Step 1: Add CFBundleURLTypes to Info.plist**

Add the URL type entry inside the top-level `<dict>`, before the closing `</dict>`:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>de.nfelger.epoch</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>epoch</string>
        </array>
    </dict>
</array>
```

- [ ] **Step 2: Add CFBundleURLTypes to project.yml**

In `targets.Epoch.info.properties`, add:

```yaml
CFBundleURLTypes:
  - CFBundleURLName: de.nfelger.epoch
    CFBundleURLSchemes:
      - epoch
```

- [ ] **Step 3: Regenerate Xcode project**

Run: `xcodegen generate`
Expected: `Epoch.xcodeproj` regenerated without errors.

- [ ] **Step 4: Commit**

```bash
git add Epoch/Info.plist project.yml Epoch.xcodeproj
git commit -m "feat: register epoch URL scheme"
```

---

### Task 2: URL Handler in AppDelegate

**Files:**
- Modify: `Epoch/AppDelegate.swift`

- [ ] **Step 1: Add application(_:open:) method**

Add this method to the main `AppDelegate` class body (after `togglePanel()`):

```swift
func application(_ application: NSApplication, open urls: [URL]) {
    for url in urls {
        guard url.scheme == "epoch" else { continue }
        switch url.host {
        case "toggle":
            if overlayPanel.isVisible { hideOverlay() } else { showOverlay() }
        case "open":
            showOverlay()
        case "close":
            hideOverlay()
        default:
            break
        }
    }
}
```

- [ ] **Step 2: Build and verify**

Run: `make build-debug`
Expected: Build succeeds.

- [ ] **Step 3: Manual test**

Run from terminal: `open epoch://toggle` — panel should appear. Run again — panel should hide.
Run: `open epoch://open` — panel appears. `open epoch://close` — panel hides.

- [ ] **Step 4: Commit**

```bash
git add Epoch/AppDelegate.swift
git commit -m "feat: handle epoch:// URL scheme for panel toggle"
```

---

### Task 3: Make Panel Key-Capable

**Files:**
- Modify: `Epoch/AppDelegate.swift`

- [ ] **Step 1: Create KeyablePanel subclass**

Add this class at the bottom of `AppDelegate.swift` (after `FirstMouseHostingView`):

```swift
class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}
```

- [ ] **Step 2: Change NSPanel to KeyablePanel in setupOverlayPanel()**

In `setupOverlayPanel()`, replace:

```swift
let newPanel = NSPanel(
```

with:

```swift
let newPanel = KeyablePanel(
```

- [ ] **Step 3: Change orderFront to makeKeyAndOrderFront in showOverlay()**

In `showOverlay()`, replace:

```swift
overlayPanel.orderFront(nil)
```

with:

```swift
overlayPanel.makeKeyAndOrderFront(nil)
```

- [ ] **Step 4: Update overlayPanel type declaration**

Change the property declaration from:

```swift
var overlayPanel: NSPanel!
```

to:

```swift
var overlayPanel: KeyablePanel!
```

- [ ] **Step 5: Build and verify**

Run: `make build-debug`
Expected: Build succeeds. Panel should still work as before — appears on click, floats above other windows.

- [ ] **Step 6: Commit**

```bash
git add Epoch/AppDelegate.swift
git commit -m "feat: make overlay panel key-capable for keyboard input"
```

---

### Task 4: Keyboard Duration Input

**Files:**
- Modify: `Epoch/Views/ArcDialView.swift`

- [ ] **Step 1: Add typeBuffer state**

Add to the existing `@State` properties in `ArcDialView`:

```swift
@State private var typeBuffer: String = ""
```

- [ ] **Step 2: Add .onKeyPress modifier**

Add `.onKeyPress` after the existing `.onHover` modifier (inside the `GeometryReader`, on the `ZStack`). Place it before the closing brace of the `GeometryReader`:

```swift
.focusable()
.onKeyPress { press in
    guard model.state == .inactive else { return .ignored }

    if press.key == .return {
        if let minutes = Int(typeBuffer), minutes >= 1 {
            let duration = Double(minutes) * 60
            cumulativeAngle = duration / 3600 * 2 * .pi
            model.start(duration: duration)
            typeBuffer = ""
        }
        return .handled
    }

    if press.key == .delete {
        if !typeBuffer.isEmpty {
            typeBuffer.removeLast()
            if let minutes = Int(typeBuffer), minutes > 0 {
                cumulativeAngle = Double(minutes) / 60.0 * 2 * .pi
            } else {
                cumulativeAngle = 0
            }
        }
        return .handled
    }

    let char = press.characters
    if let digit = char.first, digit.isNumber, char.count == 1 {
        typeBuffer.append(digit)
        if let minutes = Int(typeBuffer), minutes > 0 {
            cumulativeAngle = Double(minutes) / 60.0 * 2 * .pi
        }
        return .handled
    }

    return .ignored
}
```

- [ ] **Step 3: Clear typeBuffer on drag**

In `handleDragChanged`, add `typeBuffer = ""` at the start of the `if isDragging` block's else branch (where `isDragging` is set to `true`):

```swift
} else {
    isDragging = true
    typeBuffer = ""
    if model.state == .finished {
```

- [ ] **Step 4: Build and verify**

Run: `make build-debug`
Expected: Build succeeds.

- [ ] **Step 5: Manual test**

1. Open panel, type `25` — dial should animate to 25 minutes
2. Hit Enter — timer starts at 25 minutes
3. Open panel (after cancel), type `5`, then backspace — dial returns to 0
4. Type `90`, hit Enter — timer starts at 90 minutes (1h30m)
5. Type `0`, hit Enter — nothing happens (must be >= 1)

- [ ] **Step 6: Commit**

```bash
git add Epoch/Views/ArcDialView.swift
git commit -m "feat: keyboard duration input — type minutes and press Enter to start"
```

---

### Task 5: Lint, Test, Changelog

**Files:**
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Run lint**

Run: `make lint`
Expected: No errors.

- [ ] **Step 2: Run tests**

Run: `make test`
Expected: All tests pass.

- [ ] **Step 3: Update CHANGELOG.md**

Add under the `[Unreleased]` section:

```markdown
### Added

- URL scheme (`epoch://toggle`, `epoch://open`, `epoch://close`) for external panel control — use with aerospace, Raycast, or any launcher
- Keyboard duration input: type minutes and press Enter to start a timer
```

- [ ] **Step 4: Run format**

Run: `make format`

- [ ] **Step 5: Commit**

```bash
git add CHANGELOG.md
git commit -m "docs: add keyboard support to changelog"
```
