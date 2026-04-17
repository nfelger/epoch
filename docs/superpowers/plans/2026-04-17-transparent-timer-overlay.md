# Transparent Timer Overlay Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a floating, semi-transparent overlay panel that keeps the arc dial timer visible while the timer runs, rather than hiding the UI behind a menubar countdown.

**Architecture:** A new `NSPanel` owned by `AppDelegate`, created at launch alongside the existing popover panel. It reuses `ArcDialView` via a new SwiftUI wrapper (`OverlayContentView`) that adds a pulsing red border on completion. The overlay is togglable via UserDefaults and a right-click context menu item. ArcDialView gains an `isOverlayMode` flag so that only arc-track drags adjust the timer — non-arc drags fall through to the panel for window movement via `isMovableByWindowBackground`.

**Tech Stack:** Swift 5.9, AppKit (NSPanel), SwiftUI, UserDefaults

**Spec:** `docs/superpowers/specs/2026-04-17-transparent-timer-overlay-design.md`

---

## File Structure

| Action | File | Responsibility |
|--------|------|----------------|
| Create | `Epoch/Views/OverlayContentView.swift` | SwiftUI wrapper: ArcDialView + pulsing red border on finished state |
| Modify | `Epoch/Views/ArcDialView.swift` | Add `isOverlayMode` flag to restrict drag gesture content shape to arc ring |
| Modify | `Epoch/AppDelegate.swift` | Overlay panel creation, lifecycle, position tracking, context menu toggle, UserDefaults |

No changes to `TimerModel.swift`, `PopoverContentView.swift`, `EpochApp.swift`, or `project.yml` (XcodeGen auto-includes new Swift files from `Epoch/`).

---

### Task 1: Add `isOverlayMode` to ArcDialView

**Why:** In the overlay, only drags near the arc knob/track should adjust the timer. Drags elsewhere must fall through to AppKit so `isMovableByWindowBackground` can move the panel. The popover retains its current full-area drag behavior.

**Files:**
- Modify: `Epoch/Views/ArcDialView.swift`

- [ ] **Step 1: Add the `isOverlayMode` property**

Add a stored property to `ArcDialView`, defaulting to `false` so the popover is unaffected:

```swift
struct ArcDialView: View {
    @Bindable var model: TimerModel
    var isOverlayMode: Bool = false
    // ... existing @State properties unchanged
```

- [ ] **Step 2: Extract arc geometry constants**

The arc radius and line width are computed inside `drawArc` but needed for the content shape too. Extract them as computed properties so both can share them:

```swift
// Add below the existing computed properties (rawSeconds, roundedDuration, arcAngle)

private func arcRadius(in size: CGSize) -> CGFloat {
    min(size.width, size.height) / 2 - 15
}

private let arcLineWidth: CGFloat = 10
```

Update `drawArc` to use these instead of local `let radius` and `let lineWidth`:

```swift
private func drawArc(context: GraphicsContext, size: CGSize) {
    let center = CGPoint(x: size.width / 2, y: size.height / 2)
    let radius = arcRadius(in: size)
    let startAngle = Angle.degrees(-90)
    let strokeStyle = StrokeStyle(lineWidth: arcLineWidth, lineCap: .butt)
    // ... rest unchanged, but replace local `lineWidth` references with `arcLineWidth`
```

In `drawTickMarks`, change the parameter name from `lineWidth` to use `arcLineWidth` directly, or keep the parameter — either works. The simplest change: just pass `arcLineWidth` at the call site instead of the old local `lineWidth`.

- [ ] **Step 3: Add a ring-shaped content shape for overlay mode**

Create a custom `Shape` that defines the interactive hit-test area as a ring around the arc track, with generous tolerance (24pt total width: the 10pt arc line + 7pt padding on each side) so the knob (14–16pt diameter) is fully covered:

```swift
private struct ArcRingShape: Shape {
    let radius: CGFloat
    let lineWidth: CGFloat
    let tolerance: CGFloat = 7

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outer = radius + lineWidth / 2 + tolerance
        let inner = max(0, radius - lineWidth / 2 - tolerance)
        var path = Path()
        path.addEllipse(in: CGRect(
            x: center.x - outer, y: center.y - outer,
            width: outer * 2, height: outer * 2
        ))
        path.addEllipse(in: CGRect(
            x: center.x - inner, y: center.y - inner,
            width: inner * 2, height: inner * 2
        ))
        return path
    }
}
```

Note: SwiftUI uses the even-odd fill rule by default, so the inner ellipse cuts a hole — making a ring.

- [ ] **Step 4: Conditionally apply the content shape**

Replace the existing `.contentShape(Rectangle())` in the `body`:

```swift
// Replace:
.contentShape(Rectangle())

// With:
.contentShape(
    isOverlayMode
        ? AnyShape(ArcRingShape(radius: arcRadius(in: geo.size), lineWidth: arcLineWidth))
        : AnyShape(Rectangle())
)
```

Note: `AnyShape` requires macOS 14+, which matches our deployment target.

Move `.contentShape(...)` inside the `GeometryReader` closure (after the `ZStack`) so `geo.size` is available. It should be applied to the `ZStack`, before the `.gesture(...)` modifier. The current code already has this structure — `.contentShape(Rectangle())` is on the ZStack.

- [ ] **Step 5: Also move `.onHover` inside the conditional**

The `.onHover` cursor change should only apply to the interactive area. Wrap it so it only fires over the arc ring in overlay mode:

```swift
// The .onHover stays on the ZStack, after .contentShape — no change needed.
// .contentShape already controls the hover hit-test area.
```

Actually, `.contentShape` with the `.hoverEffect` interaction type would be needed to control hover separately, but since `.contentShape(_:)` (single argument) controls both gestures and hover in SwiftUI, the ring shape already restricts hover to the arc area in overlay mode. No additional change.

- [ ] **Step 6: Build and verify**

```bash
make lint && make build-debug
```

Expected: Clean build. The popover behavior is unchanged because `isOverlayMode` defaults to `false`.

- [ ] **Step 7: Commit**

```bash
git add Epoch/Views/ArcDialView.swift
git commit -m "feat: add isOverlayMode to ArcDialView for restricted drag area"
```

---

### Task 2: Create OverlayContentView

**Why:** The overlay needs its own SwiftUI wrapper that adds the pulsing red border effect on the finished state. This is separate from `PopoverContentView` because the overlay has different visual treatment (pulsing border, no cancel button).

**Files:**
- Create: `Epoch/Views/OverlayContentView.swift`

- [ ] **Step 1: Create the file with the basic view**

```swift
import SwiftUI

struct OverlayContentView: View {
    @Bindable var model: TimerModel
    @State private var borderOpacity: Double = 0.4

    var body: some View {
        ArcDialView(model: model, isOverlayMode: true)
            .frame(width: 142, height: 142)
            .padding(16)
            .overlay(pulsingBorder)
    }

    @ViewBuilder
    private var pulsingBorder: some View {
        if model.state == .finished {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.red, lineWidth: 3)
                .opacity(borderOpacity)
                .onAppear {
                    withAnimation(
                        .easeInOut(duration: 1.0)
                            .repeatForever(autoreverses: true)
                    ) {
                        borderOpacity = 1.0
                    }
                }
                .onDisappear {
                    borderOpacity = 0.4
                }
        }
    }
}
```

- [ ] **Step 2: Build and verify**

```bash
make lint && make build-debug
```

Expected: Clean build. The view isn't wired up yet but compiles.

- [ ] **Step 3: Commit**

```bash
git add Epoch/Views/OverlayContentView.swift
git commit -m "feat: add OverlayContentView with pulsing red border"
```

---

### Task 3: Create and configure the overlay NSPanel

**Why:** The overlay is a separate `NSPanel` with different style and behavior from the existing popover panel. This task creates the panel and its visual effect backdrop, but doesn't wire up lifecycle yet.

**Files:**
- Modify: `Epoch/AppDelegate.swift`

- [ ] **Step 1: Add the overlay panel property**

Add to AppDelegate's property declarations, near the existing `panel` property:

```swift
var overlayPanel: NSPanel!
```

- [ ] **Step 2: Create the overlay panel in `applicationDidFinishLaunching`**

Add after the existing panel setup block (after `panel.contentView = visualEffect`), before `observeModel()`:

```swift
// Overlay panel
let overlayPanel = NSPanel(
    contentRect: NSRect(origin: .zero, size: panelSize),
    styleMask: [.titled, .closable, .nonactivatingPanel, .fullSizeContentView],
    backing: .buffered,
    defer: false
)
overlayPanel.titlebarAppearsTransparent = true
overlayPanel.titleVisibility = .hidden
overlayPanel.backgroundColor = .clear
overlayPanel.isOpaque = false
overlayPanel.hasShadow = true
overlayPanel.level = .floating
overlayPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
overlayPanel.isMovableByWindowBackground = true
overlayPanel.animationBehavior = .utilityWindow

let overlayVisualEffect = NSVisualEffectView(frame: NSRect(origin: .zero, size: panelSize))
overlayVisualEffect.material = .popover
overlayVisualEffect.blendingMode = .behindWindow
overlayVisualEffect.state = .active
overlayVisualEffect.wantsLayer = true
overlayVisualEffect.layer?.cornerRadius = 12
overlayVisualEffect.layer?.masksToBounds = true

let overlayHostingView = FirstMouseHostingView(rootView: OverlayContentView(model: timerModel))
overlayHostingView.frame = NSRect(origin: .zero, size: panelSize)
overlayHostingView.autoresizingMask = [.width, .height]
overlayVisualEffect.addSubview(overlayHostingView)
overlayPanel.contentView = overlayVisualEffect
self.overlayPanel = overlayPanel
```

Key differences from the popover panel:
- `.titled` + `.closable` + `.fullSizeContentView` (not `.borderless`) — gives us the red close button
- `.floating` level (not `.popUpMenu`) — above normal windows but below popover
- `isMovableByWindowBackground = true` — drags outside the arc ring move the panel
- `collectionBehavior` for all-spaces visibility
- `titlebarAppearsTransparent` + `titleVisibility = .hidden` — hides the title bar chrome except the close button

- [ ] **Step 3: Handle the close button via NSWindowDelegate**

Make `AppDelegate` conform to `NSWindowDelegate` and set it as the overlay panel's delegate. Override `windowShouldClose` to hide the overlay instead of destroying it:

Add `overlayPanel.delegate = self` after `self.overlayPanel = overlayPanel`.

Add a new extension at the bottom of the file:

```swift
extension AppDelegate: NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if sender === overlayPanel {
            hideOverlay()
            return false
        }
        return true
    }
}
```

Also add the `hideOverlay()` helper (it will be fleshed out in Task 5, but define the stub now):

```swift
private func hideOverlay() {
    overlayPanel.orderOut(nil)
}
```

- [ ] **Step 4: Build and verify**

```bash
make lint && make build-debug
```

Expected: Clean build. The overlay panel exists but is never shown yet.

- [ ] **Step 5: Commit**

```bash
git add Epoch/AppDelegate.swift
git commit -m "feat: create overlay NSPanel with floating style and close button"
```

---

### Task 4: Add UserDefaults preference and context menu toggle

**Why:** The overlay is on by default but togglable via a right-click menu item. The preference persists across launches.

**Files:**
- Modify: `Epoch/AppDelegate.swift`

- [ ] **Step 1: Add the UserDefaults property**

Add to AppDelegate's property declarations:

```swift
private var showTimerOverlay: Bool {
    get {
        // UserDefaults returns false for unregistered keys, so we check if
        // the key has ever been set. If not, default to true (on by default).
        if UserDefaults.standard.object(forKey: "showTimerOverlay") == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: "showTimerOverlay")
    }
    set {
        UserDefaults.standard.set(newValue, forKey: "showTimerOverlay")
    }
}
```

- [ ] **Step 2: Add the toggle menu item to `buildContextMenu()`**

Add the "Show Timer Overlay" item to the context menu, before "About Epoch":

```swift
private func buildContextMenu() -> NSMenu {
    let menu = NSMenu()
    if timerModel.state == .running || timerModel.state == .finished {
        menu.addItem(NSMenuItem(title: "Cancel Timer", action: #selector(cancelTimer), keyEquivalent: ""))
        menu.addItem(.separator())
    }

    let overlayItem = NSMenuItem(
        title: "Show Timer Overlay",
        action: #selector(toggleOverlaySetting),
        keyEquivalent: ""
    )
    overlayItem.state = showTimerOverlay ? .on : .off
    menu.addItem(overlayItem)
    menu.addItem(.separator())

    menu.addItem(NSMenuItem(title: "About Epoch", action: #selector(showAbout), keyEquivalent: ""))
    menu.addItem(.separator())
    menu.addItem(NSMenuItem(
        title: "Quit Epoch",
        action: #selector(NSApplication.terminate(_:)),
        keyEquivalent: "q"
    ))
    return menu
}
```

- [ ] **Step 3: Add the toggle action**

```swift
@objc func toggleOverlaySetting() {
    showTimerOverlay.toggle()
    if showTimerOverlay {
        if timerModel.state == .running || timerModel.state == .finished {
            showOverlay()
        }
    } else {
        hideOverlay()
    }
}
```

Add a stub `showOverlay()` method (will be fleshed out in Task 5):

```swift
private func showOverlay() {
    // Will be implemented in Task 5
    overlayPanel.makeKeyAndOrderFront(nil)
}
```

- [ ] **Step 4: Build and verify**

```bash
make lint && make build-debug
```

Expected: Clean build. The menu item appears in the right-click menu. Toggling it persists to UserDefaults.

- [ ] **Step 5: Commit**

```bash
git add Epoch/AppDelegate.swift
git commit -m "feat: add UserDefaults toggle and context menu for overlay"
```

---

### Task 5: Implement overlay lifecycle

**Why:** This is the core behavior — showing/hiding the overlay based on timer state, user actions, and the preference toggle. All seven lifecycle scenarios from the spec are implemented here.

**Files:**
- Modify: `Epoch/AppDelegate.swift`

- [ ] **Step 1: Implement `showOverlay()` with positioning**

Replace the stub `showOverlay()` with the full implementation. On first show (or when the panel has no previous position), position it below the menubar icon — same logic as `showPanel()`. On subsequent shows, use the panel's current frame (user may have dragged it):

```swift
private var hasShownOverlayOnce = false

private func showOverlay() {
    guard showTimerOverlay else { return }

    if !hasShownOverlayOnce {
        positionOverlayBelowMenubar()
        hasShownOverlayOnce = true
    }

    overlayPanel.orderFront(nil)
    updateOverlayOpacity()
}

private func positionOverlayBelowMenubar() {
    guard let button = statusItem.button, let buttonWindow = button.window else { return }

    let buttonRectInWindow = button.convert(button.bounds, to: nil)
    let buttonRectOnScreen = buttonWindow.convertToScreen(buttonRectInWindow)

    let panelWidth = overlayPanel.frame.width
    let panelHeight = overlayPanel.frame.height
    var panelX = buttonRectOnScreen.midX - panelWidth / 2
    let panelY = buttonRectOnScreen.minY - panelHeight - 6

    if let screen = buttonWindow.screen ?? NSScreen.main {
        panelX = max(screen.visibleFrame.minX, min(panelX, screen.visibleFrame.maxX - panelWidth))
    }

    overlayPanel.setFrameOrigin(NSPoint(x: panelX, y: panelY))
}
```

- [ ] **Step 2: Implement `updateOverlayOpacity()`**

```swift
private func updateOverlayOpacity() {
    switch timerModel.state {
    case .inactive:
        break
    case .running:
        overlayPanel.alphaValue = 0.5
    case .finished:
        overlayPanel.alphaValue = 1.0
    }
}
```

- [ ] **Step 3: Update `hideOverlay()` to be complete**

Replace the stub:

```swift
private func hideOverlay() {
    overlayPanel.orderOut(nil)
}
```

(This is already the correct implementation — `orderOut` hides the panel without destroying it, preserving its frame position for next show.)

- [ ] **Step 4: Wire overlay into `handleStateTransitions()`**

Update `handleStateTransitions()` to show/hide the overlay based on timer state changes:

```swift
private func handleStateTransitions() {
    let currentState = timerModel.state
    let previousState = lastObservedState
    lastObservedState = currentState

    if currentState == .running, previousState != .running {
        requestNotificationPermissionIfNeeded()
        showOverlay()           // ← NEW: show overlay when timer starts
        hidePanel()             // ← NEW: hide popover when timer starts
    }
    if currentState == .finished, previousState != .finished {
        playCompletionSound()
        scheduleCompletionNotification()
        startFlashSequence()
        updateOverlayOpacity()  // ← NEW: snap to 100% opacity
    }
    if currentState == .inactive, previousState == .finished {
        stopFlashAnimation()
        hideOverlay()           // ← NEW: hide overlay when timer resets
        hasShownOverlayOnce = false  // ← NEW: reset position for next timer
    }
    if currentState == .inactive, previousState == .running {
        hideOverlay()           // ← NEW: hide overlay on cancel during running
        hasShownOverlayOnce = false
    }
}
```

- [ ] **Step 5: Update `cancelTimer()` to also hide the overlay**

```swift
@objc func cancelTimer() {
    stopFlashAnimation()
    hideOverlay()
    timerModel.cancel()
}
```

- [ ] **Step 6: Update `togglePanel()` to reshow overlay when hidden**

When the user clicks the menubar icon while the overlay is hidden but the timer is running, the overlay should reappear (spec point 6). Update the else-branch in `togglePanel()`:

```swift
@objc func togglePanel() {
    guard let button = statusItem.button else { return }
    if NSApp.currentEvent?.type == .rightMouseUp {
        buildContextMenu().popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height), in: button)
        return
    }

    if timerModel.state == .running || timerModel.state == .finished {
        // Timer is active — toggle the overlay visibility
        if overlayPanel.isVisible {
            hideOverlay()
        } else if showTimerOverlay {
            showOverlay()
        } else {
            // Overlay feature is off — toggle the popover as before
            if panel.isVisible {
                hidePanel()
            } else {
                guard Date.now.timeIntervalSince(lastPanelCloseTime) > 0.2 else { return }
                showPanel()
            }
        }
    } else {
        // Timer is inactive — toggle the popover to set a new timer
        if panel.isVisible {
            hidePanel()
        } else {
            guard Date.now.timeIntervalSince(lastPanelCloseTime) > 0.2 else { return }
            showPanel()
        }
    }
}
```

- [ ] **Step 7: Update `updateStatusItem()` to also observe overlay opacity**

The `updateStatusItem()` method is called inside `withObservationTracking`. Add a call to `updateOverlayOpacity()` inside it so the overlay alpha stays in sync during the running state:

```swift
private func updateStatusItem() {
    let frozen = panel.isVisible
    switch timerModel.state {
    case .inactive:
        if !frozen { statusItem.length = NSStatusItem.squareLength }
        statusItem.button?.image = timerIcon
        statusItem.button?.title = ""
    case .running:
        let total = Int(timerModel.remaining)
        let hrs = total / 3600
        let mins = (total % 3600) / 60
        let secs = total % 60
        let label = hrs > 0
            ? String(format: "%d:%02d:%02d", hrs, mins, secs)
            : String(format: "%d:%02d", mins, secs)
        if !frozen { statusItem.length = NSStatusItem.variableLength }
        statusItem.button?.image = nil
        statusItem.button?.title = " \(label)"
    case .finished:
        if !frozen { statusItem.length = NSStatusItem.variableLength }
        statusItem.button?.image = nil
    }
    updateOverlayOpacity()
}
```

Note: This call is cheap (just sets `alphaValue`) and ensures the overlay stays at the correct opacity as the timer ticks.

- [ ] **Step 8: Build and verify**

```bash
make lint && make build-debug
```

Expected: Clean build. All overlay lifecycle behavior is now wired up.

- [ ] **Step 9: Commit**

```bash
git add Epoch/AppDelegate.swift
git commit -m "feat: implement overlay lifecycle — show, hide, position, opacity"
```

---

### Task 6: Build, lint, test, and manual verification

**Why:** Final verification that everything compiles, passes lint/tests, and the feature works end-to-end.

**Files:**
- No new changes — verification only.

- [ ] **Step 1: Run linter**

```bash
make lint
```

Expected: No warnings or errors.

- [ ] **Step 2: Run tests**

```bash
make test
```

Expected: All existing `TimerModelTests` pass. No test changes needed — `TimerModel` is unchanged.

- [ ] **Step 3: Run format**

```bash
make format
```

Then check if formatting changed anything:

```bash
git diff
```

If there are changes, stage and commit them:

```bash
git add -A
git commit -m "style: apply SwiftFormat"
```

- [ ] **Step 4: Deploy and manual test**

```bash
make deploy
```

Open Epoch from `/Applications` and verify the following scenarios:

1. **Timer starts → overlay appears** below the menubar icon at 50% opacity
2. **Timer running → overlay stays visible**, menubar shows countdown text
3. **Drag the knob on overlay** → adjusts remaining time
4. **Drag elsewhere on overlay** → moves the panel
5. **Click overlay close button** → overlay hides, timer continues in menubar
6. **Click menubar icon while overlay hidden** → overlay reappears at last position
7. **Timer finishes → overlay snaps to 100% opacity**, red pulsing border appears, menubar flash plays
8. **Cancel timer via right-click menu** → overlay hides, everything resets
9. **Right-click menu → uncheck "Show Timer Overlay"** → overlay hides, timer continues
10. **Right-click menu → re-check "Show Timer Overlay" while running** → overlay reappears
11. **Quit and relaunch** → overlay preference persists

- [ ] **Step 5: Update the changelog**

Add to `CHANGELOG.md` under `[Unreleased]`:

```markdown
### Added

- Floating transparent timer overlay that keeps the arc dial visible while the timer runs
- Overlay appears at 50% opacity during countdown, snaps to 100% with pulsing red border when finished
- Draggable overlay panel — drag the knob to adjust time, drag anywhere else to reposition
- "Show Timer Overlay" toggle in the right-click context menu, persisted via UserDefaults
- Overlay visible across all spaces and in fullscreen mode
```

- [ ] **Step 6: Commit changelog**

```bash
git add CHANGELOG.md
git commit -m "docs: add transparent timer overlay to changelog"
```

---

## Design Decisions & Notes

**Why `isOverlayMode` on ArcDialView instead of a separate view?**
Duplicating ArcDialView would create a maintenance burden — it's 250 lines of canvas drawing and gesture handling. A single boolean flag cleanly separates the two content shape behaviors.

**Why `isMovableByWindowBackground` instead of custom `mouseDown`/`mouseDragged`?**
It's a one-line property that gives us standard macOS window-dragging behavior for free. Combined with the restricted content shape in overlay mode, drags outside the arc ring naturally fall through to the window background.

**Flash sequence auto-cancel interaction:**
The existing `startFlashSequence()` calls `timerModel.cancel()` after ~8 seconds, which will trigger the `.inactive` transition and hide the overlay. This means the overlay's finished state (pulsing border) only lasts as long as the flash animation. If the user wants the overlay to persist in the finished state longer, the flash auto-cancel behavior would need to change — but that's outside the scope of this spec.

**Why `.titled` instead of `.borderless` for the overlay?**
The spec lists `.borderless`, but `.borderless` panels don't render the standard window close button. Using `.titled` + `.closable` + `.fullSizeContentView` + `titlebarAppearsTransparent` gives us the red close button while keeping the panel visually borderless.
