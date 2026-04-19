# Overlay Panel Replacement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the two-panel architecture (popover + overlay) with a single overlay panel that handles all timer states.

**Architecture:** Remove the popover panel (`panel: NSPanel`) and all supporting code from `AppDelegate`. Simplify `ArcDialView` by removing the `isOverlayMode` flag — always use ring-only hit area and always draw the contrast disc. Add `setFrameAutosaveName` so AppKit persists the overlay's position across launches automatically.

**Tech Stack:** Swift 5.9, AppKit, SwiftUI, xcodebuild. Build with `make build`, lint with `make lint`, test with `make test`.

---

### Task 1: Simplify `ArcDialView` and update `OverlayContentView`

Remove the `isOverlayMode` parameter from `ArcDialView`. Always use the ring-only hit area (`ArcRingShape`) and always draw the contrast disc. Update the one call site in `OverlayContentView`.

> Note: `PopoverContentView` also calls `ArcDialView` (without `isOverlayMode`), so it still compiles after this task. It is deleted in Task 3.

**Files:**
- Modify: `Epoch/Views/ArcDialView.swift`
- Modify: `Epoch/Views/OverlayContentView.swift`

- [ ] **Step 1: Remove `isOverlayMode` property from `ArcDialView`**

In `Epoch/Views/ArcDialView.swift`, delete line 6:
```swift
var isOverlayMode: Bool = false
```

- [ ] **Step 2: Make content shape always use `ArcRingShape`**

Replace the conditional `.contentShape(...)` in `ArcDialView.body` (currently lines 48–51):
```swift
// Remove this:
.contentShape(
    isOverlayMode
        ? AnyShape(ArcRingShape(radius: arcRadius(in: geo.size), lineWidth: arcLineWidth))
        : AnyShape(Rectangle())
)
```
with:
```swift
.contentShape(AnyShape(ArcRingShape(radius: arcRadius(in: geo.size), lineWidth: arcLineWidth)))
```

- [ ] **Step 3: Always draw the contrast disc in `drawArc`**

Replace the conditional disc block in `drawArc` (currently lines 149–158):
```swift
// Remove this:
if isOverlayMode {
    let discRadius = radius + arcLineWidth / 2 + 4
    var disc = Path()
    disc.addEllipse(in: CGRect(
        x: center.x - discRadius, y: center.y - discRadius,
        width: discRadius * 2, height: discRadius * 2
    ))
    context.fill(disc, with: .color(Color(red: 0.96, green: 0.95, blue: 0.93).opacity(0.9)))
}
```
with (unconditional):
```swift
// Contrast disc
let discRadius = radius + arcLineWidth / 2 + 4
var disc = Path()
disc.addEllipse(in: CGRect(
    x: center.x - discRadius, y: center.y - discRadius,
    width: discRadius * 2, height: discRadius * 2
))
context.fill(disc, with: .color(Color(red: 0.96, green: 0.95, blue: 0.93).opacity(0.9)))
```

- [ ] **Step 4: Update `OverlayContentView` call site**

In `Epoch/Views/OverlayContentView.swift` line 10, change:
```swift
ArcDialView(model: model, isOverlayMode: true)
```
to:
```swift
ArcDialView(model: model)
```

- [ ] **Step 5: Build and lint**

```bash
make build
make lint
```
Expected: clean build, no lint warnings.

- [ ] **Step 6: Commit**

```bash
git add Epoch/Views/ArcDialView.swift Epoch/Views/OverlayContentView.swift
git commit -m "refactor: remove isOverlayMode from ArcDialView, always use ring hit area and contrast disc"
```

---

### Task 2: Refactor `AppDelegate` — remove popover panel, simplify all affected code

This is the main removal task. Replace the entire `AppDelegate.swift` content. The full file after changes is shown below — copy it exactly.

**Files:**
- Modify: `Epoch/AppDelegate.swift`

- [ ] **Step 1: Replace `AppDelegate.swift` with the simplified version**

Write the following content to `Epoch/AppDelegate.swift`:

```swift
import AppKit
import SwiftUI
import UserNotifications

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var overlayPanel: NSPanel!
    var overlayBackground: NSVisualEffectView!
    let timerModel = TimerModel()

    private var flashTimer: Timer?
    private var lastObservedState: TimerState = .inactive
    private var overlayDragStartOrigin: CGPoint?
    private let timerIcon = NSImage(systemSymbolName: "timer", accessibilityDescription: "Epoch")!

    private func buildContextMenu() -> NSMenu {
        let menu = NSMenu()
        if timerModel.state == .running || timerModel.state == .finished {
            menu.addItem(NSMenuItem(title: "Cancel Timer", action: #selector(cancelTimer), keyEquivalent: ""))
            menu.addItem(.separator())
        }
        menu.addItem(NSMenuItem(title: "About Epoch", action: #selector(showAbout), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(
            title: "Quit Epoch", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"
        ))
        return menu
    }

    @objc func cancelTimer() {
        stopFlashAnimation()
        hideOverlay()
        timerModel.cancel()
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = self
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = timerIcon
            button.action = #selector(togglePanel)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        setupOverlayPanel()
        observeModel()
    }

    @objc func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    @objc func togglePanel() {
        guard let button = statusItem.button else { return }
        if NSApp.currentEvent?.type == .rightMouseUp {
            buildContextMenu().popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height), in: button)
            return
        }
        if overlayPanel.isVisible { hideOverlay() } else { showOverlay() }
    }

    // MARK: - Model Observation

    private func observeModel() {
        withObservationTracking {
            updateStatusItem()
            handleStateTransitions()
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.observeModel()
            }
        }
    }

    private func updateStatusItem() {
        switch timerModel.state {
        case .inactive:
            statusItem.length = NSStatusItem.squareLength
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
            statusItem.length = NSStatusItem.variableLength
            statusItem.button?.image = nil
            statusItem.button?.title = " \(label)"
        case .finished:
            statusItem.length = NSStatusItem.variableLength
            statusItem.button?.image = nil
        }
        updateOverlayOpacity()
    }

    private func handleStateTransitions() {
        let currentState = timerModel.state
        let previousState = lastObservedState
        lastObservedState = currentState
        if currentState == .running, previousState != .running {
            requestNotificationPermissionIfNeeded()
        }
        if currentState == .finished, previousState != .finished {
            playCompletionSound()
            scheduleCompletionNotification()
            startFlashSequence()
            updateOverlayOpacity()
        }
        if currentState == .inactive, previousState != .inactive {
            if previousState == .finished { stopFlashAnimation() }
            hideOverlay()
        }
    }
}

// MARK: - Panel Management

extension AppDelegate {
    private func setupOverlayPanel() {
        let panelSize = NSSize(width: 174, height: 174)
        let newPanel = NSPanel(
            contentRect: NSRect(origin: .zero, size: panelSize),
            styleMask: [.titled, .closable, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        newPanel.titlebarAppearsTransparent = true
        newPanel.titleVisibility = .hidden
        newPanel.backgroundColor = .clear
        newPanel.isOpaque = false
        newPanel.hasShadow = true
        newPanel.level = .floating
        newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        newPanel.animationBehavior = .utilityWindow
        newPanel.setFrameAutosaveName("OverlayPanel")
        let container = NSView(frame: NSRect(origin: .zero, size: panelSize))
        let background = makeVibrancyView(size: panelSize)
        background.material = .hudWindow
        let overlayHostingView = FirstMouseHostingView(rootView: OverlayContentView(
            model: timerModel,
            onDragChanged: { [weak self] in self?.overlayPanelDragChanged($0) },
            onDragEnded: { [weak self] in self?.overlayDragStartOrigin = nil }
        ))
        overlayHostingView.frame = NSRect(origin: .zero, size: panelSize)
        overlayHostingView.autoresizingMask = [.width, .height]
        container.addSubview(background)
        container.addSubview(overlayHostingView)
        newPanel.contentView = container
        newPanel.delegate = self
        overlayPanel = newPanel
        overlayBackground = background
    }

    private func makeVibrancyView(size: NSSize) -> NSVisualEffectView {
        let view = NSVisualEffectView(frame: NSRect(origin: .zero, size: size))
        view.material = .popover
        view.blendingMode = .behindWindow
        view.state = .active
        view.wantsLayer = true
        view.layer?.cornerRadius = 12
        view.layer?.masksToBounds = true
        return view
    }

    private func positionPanelBelowMenubar(_ targetPanel: NSPanel) {
        guard let button = statusItem.button, let buttonWindow = button.window else { return }
        let buttonRectInWindow = button.convert(button.bounds, to: nil)
        let buttonRectOnScreen = buttonWindow.convertToScreen(buttonRectInWindow)
        var panelX = buttonRectOnScreen.midX - targetPanel.frame.width / 2
        let panelY = buttonRectOnScreen.minY - targetPanel.frame.height - 6
        if let screen = buttonWindow.screen ?? NSScreen.main {
            panelX = max(screen.visibleFrame.minX, min(panelX, screen.visibleFrame.maxX - targetPanel.frame.width))
        }
        targetPanel.setFrameOrigin(NSPoint(x: panelX, y: panelY))
    }

    private func showOverlay() {
        if overlayPanel.frame.origin == .zero {
            positionPanelBelowMenubar(overlayPanel)
        }
        overlayPanel.orderFront(nil)
        updateOverlayOpacity()
    }

    private func hideOverlay() {
        overlayPanel.orderOut(nil)
    }

    private func overlayPanelDragChanged(_ translation: CGSize) {
        if overlayDragStartOrigin == nil { overlayDragStartOrigin = overlayPanel.frame.origin }
        guard let origin = overlayDragStartOrigin else { return }
        overlayPanel.setFrameOrigin(CGPoint(x: origin.x + translation.width, y: origin.y - translation.height))
    }

    private func updateOverlayOpacity() {
        overlayBackground.alphaValue = timerModel.state == .finished ? 1.0 : 0.75
    }
}

// MARK: - Completion Effects

extension AppDelegate {
    private func requestNotificationPermissionIfNeeded() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            if settings.authorizationStatus == .notDetermined {
                UNUserNotificationCenter.current()
                    .requestAuthorization(options: [.alert, .sound]) { _, _ in }
            }
        }
    }

    private func playCompletionSound() {
        let soundPath = "/System/Library/Components/CoreAudio.component" +
            "/Contents/SharedSupport/SystemSounds/system/burn complete.aif"
        let burnComplete = NSSound(contentsOfFile: soundPath, byReference: true)
        if let sound = burnComplete ?? NSSound(named: "Glass") ?? NSSound(named: "Purr") {
            sound.play()
        } else {
            NSSound.beep()
        }
    }

    private func scheduleCompletionNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Timer finished"
        content.sound = .default
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        )
    }

    private func startFlashSequence() {
        stopFlashAnimation()
        statusItem.length = NSStatusItem.squareLength
        statusItem.button?.title = ""
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
    }

    private func stopFlashAnimation() {
        flashTimer?.invalidate()
        flashTimer = nil
    }
}

extension AppDelegate: @preconcurrency UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler handler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        handler([.banner, .sound])
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if sender === overlayPanel {
            hideOverlay()
            return false
        }
        return true
    }
}

/// NSHostingView subclass that allows immediate drag interaction without click-to-focus.
class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override var mouseDownCanMoveWindow: Bool { false }
}
```

- [ ] **Step 2: Build and lint**

```bash
make build
make lint
```
Expected: clean build, no lint warnings. (`PopoverContentView.swift` still exists but is now unused — that's fine, it compiles independently.)

- [ ] **Step 3: Commit**

```bash
git add Epoch/AppDelegate.swift
git commit -m "refactor: remove popover panel, unify all UI into overlay panel"
```

---

### Task 3: Delete `PopoverContentView.swift`, update changelog, final verification

**Files:**
- Delete: `Epoch/Views/PopoverContentView.swift`
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Delete `PopoverContentView.swift`**

```bash
rm Epoch/Views/PopoverContentView.swift
```

- [ ] **Step 2: Add changelog entry**

In `CHANGELOG.md`, add the following under the `[Unreleased]` section:

```markdown
### Changed

- The overlay panel is now the single UI for both setting and monitoring the timer. The separate popover panel has been removed.
- The "Show Timer Overlay" menu option has been removed. The overlay is always used.
- The overlay remembers its position across app launches.
- When setting a timer, drag the arc ring on the overlay (ring-only hit area, same as when the timer is running).
```

(If a `### Changed` heading already exists in `[Unreleased]`, append under it rather than adding a duplicate heading.)

- [ ] **Step 3: Build, lint, and test**

```bash
make build
make lint
make test
```
Expected: clean build, no lint warnings, all tests pass.

- [ ] **Step 4: Manual smoke test**

Launch the app (`make deploy` or open from Xcode). Verify:
- Clicking the menubar icon shows the overlay below the menubar on first launch
- Dragging the arc ring sets a timer (timer starts on drag-end)
- Overlay stays open when timer starts
- Dragging the overlay background moves it; position persists after quit and relaunch
- Left-click menubar toggles overlay while timer runs
- Right-click menubar shows context menu (Cancel Timer when running, About, Quit — no "Show Timer Overlay")
- Timer completion: pulsing border, flash sequence, sound, notification all work
- Close button (X) hides the overlay
- Cancel Timer from context menu hides the overlay and resets state

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "refactor: delete PopoverContentView, update changelog"
```
