---
title: Epoch — macOS Menubar Countdown Timer
type: feat
status: completed
date: 2026-03-17
origin: docs/brainstorms/2026-03-17-countdown-timer-menubar-app-brainstorm.md
---

# ✨ Epoch — macOS Menubar Countdown Timer

## Enhancement Summary

**Deepened on:** 2026-03-17
**Research agents:** best-practices, performance-oracle, security-sentinel, architecture-strategist, race-conditions, simplicity-reviewer, spec-flow-analyzer

### Key Improvements Made

1. **Architecture corrected**: `TimerModel` must not touch `NSStatusItem` — use `withObservationTracking` in `AppDelegate` to drive all AppKit side-effects from published state
2. **Critical bug fixed**: Flash timer must be stored as a property and cancelled in both `cancel()` and `start()` — orphaned flash timer can silently destroy a newly-started timer's display state
3. **Security fix**: `NSUserNotificationUsageDescription` does not exist on macOS — removed. Notification permission deferred to first timer start
4. **Architecture simplified**: Use `@main class AppDelegate` directly; collapse file count and 6 phases → 3; remove `CenterLabelView.swift` and `dialAngle` from model
5. **Spec gaps resolved**: minimum duration, menubar format >60 min, 12/24-hour end time, cancel behavior, popover behavior at completion

---

## Overview

Build **Epoch**: a native macOS menubar app that implements a countdown timer with a tactile circular arc dial inspired by the TimeTimer. The app lives entirely in the menu bar — no Dock icon, no main window.

## Problem Statement

No existing lightweight, distraction-free macOS countdown timer offers the tactile satisfaction of a draggable arc dial that visually represents remaining time at a glance.

## Proposed Solution

A Swift + SwiftUI/AppKit hybrid app with three states (inactive → running → finished), a custom `Canvas`-based arc dial, and system integrations (notifications, sound) — zero third-party dependencies.

(see brainstorm: docs/brainstorms/2026-03-17-countdown-timer-menubar-app-brainstorm.md)

---

## Technical Approach

### Architecture

```
Epoch/
├── AppDelegate.swift           # @main; NSStatusItem + NSPopover; model observation
├── TimerModel.swift            # @Observable state machine + countdown logic (no AppKit)
├── Views/
│   ├── PopoverContentView.swift # Root SwiftUI view inside the popover
│   └── ArcDialView.swift        # Canvas arc + DragGesture + snapping + center labels
└── Resources/
    ├── Info.plist               # LSUIElement=YES, NSPrincipalClass
    └── Epoch.entitlements       # App sandbox; ENABLE_HARDENED_RUNTIME in build settings
```

**No `EpochApp.swift`** — use `@main class AppDelegate` directly (pure AppKit lifecycle). Delete the Xcode-generated `@main App` struct and `ContentView`.

**No `CenterLabelView.swift`** — the center label stack is a private view struct inside `ArcDialView.swift`. Not reused anywhere; a separate file adds indirection with no benefit.

**Minimum deployment target:** macOS 14 (Sonoma) — required for `@Observable` macro. (`Canvas` + `DragGesture` technically require only macOS 12, but `@Observable` is the bigger driver here.)

**No SwiftPM packages** — all APIs are in system frameworks.

### Timer State Machine

```
           drag-release (duration ≥ 1 min)
inactive ────────────────────────────────► running
    ▲                                          │
    │ cancel                                   │ reaches 0
    └──────────────────────────────────────────┤
    ◄─── auto (after flash sequence finishes) ◄┘
                                           finished
```

**Resolved: minimum duration = 1 minute.** Drag-release below 1 min is a no-op (no timer started, popover stays open).

```swift
// TimerModel.swift
// No AppKit imports in this file.

enum TimerState { case inactive, running, finished }

@Observable @MainActor
final class TimerModel {
    var state: TimerState = .inactive
    var totalDuration: TimeInterval = 0     // set at start
    var remaining: TimeInterval = 0         // updated each tick
    var endDate: Date?

    private var countdownTimer: Timer?

    func start(duration: TimeInterval) {
        guard duration >= 60 else { return }   // minimum 1 minute
        countdownTimer?.invalidate()            // guard against double-start
        countdownTimer = nil
        state = .running
        totalDuration = duration
        remaining = duration
        endDate = Date.now.addingTimeInterval(duration)
        // Schedule on .common so tick fires even during drag tracking
        countdownTimer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(countdownTimer!, forMode: .common)
    }

    func cancel() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        state = .inactive
        remaining = 0
        endDate = nil
    }

    func adjustRemaining(to duration: TimeInterval) {
        guard state == .running else { return }
        if duration <= 0 {
            countdownTimer?.invalidate()
            countdownTimer = nil
            finishCountdown()
            return
        }
        endDate = Date.now.addingTimeInterval(duration)
        remaining = duration
    }

    private func tick() {
        guard state == .running, let endDate else { return }
        remaining = max(0, endDate.timeIntervalSinceNow)
        if remaining == 0 {
            countdownTimer?.invalidate()
            countdownTimer = nil
            finishCountdown()
        }
    }

    private func finishCountdown() {
        state = .finished
        // Sound: try Glass, then Purr, then system beep — treat fallback as mandatory
        if let sound = NSSound(named: "Glass") ?? NSSound(named: "Purr") {
            sound.play()
        } else {
            NSSound.beep()
        }
        scheduleNotification()
    }

    private func scheduleNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Timer finished"
        content.sound = .default
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        )
    }
}
```

> **Note:** `NSSound` and `UNUserNotificationCenter` are system I/O with no UI coupling — acceptable at the model layer. All `NSStatusItem` mutation lives in `AppDelegate`.

### AppDelegate — Status Item, Popover, and Model Observation

```swift
// AppDelegate.swift
import AppKit
import SwiftUI
import UserNotifications

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    let timerModel = TimerModel()

    // Flash timer lives here, NOT in TimerModel
    private var flashTimer: Timer?
    private var flashCount = 0
    private let timerIcon = NSImage(systemSymbolName: "timer",
                                    accessibilityDescription: "Epoch")!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // Status item: use squareLength for icon, variableLength for text
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = timerIcon
            button.action = #selector(togglePopover)
            button.target = self
        }

        popover = NSPopover()
        popover.contentSize = NSSize(width: 240, height: 280)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: PopoverContentView(model: timerModel)
        )

        // Observe model state → drive statusItem + popover
        observeModel()
    }

    @objc func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)  // ensure keyboard works in popover
        }
    }

    // MARK: — Model Observation

    private func observeModel() {
        withObservationTracking {
            updateStatusItem()          // reads timerModel.state + timerModel.remaining
            handleStateTransitions()    // reads timerModel.state for one-shot effects
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.observeModel()    // re-arm after each change
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
            let m = Int(timerModel.remaining) / 60
            let s = Int(timerModel.remaining) % 60
            // Format: MM:SS below 60 min, H:MM above 60 min
            let label = m >= 60
                ? String(format: "%d:%02d", m / 60, m % 60)
                : String(format: "%d:%02d", m, s)
            statusItem.length = 56  // fixed width prevents status bar reflow
            statusItem.button?.image = nil
            statusItem.button?.title = " \(label)"
        case .finished:
            break  // flash timer handles this state
        }
    }

    private func handleStateTransitions() {
        if timerModel.state == .running && popover.isShown {
            // Defer by one run-loop turn to avoid closing during gesture handler
            DispatchQueue.main.async { [weak self] in
                self?.popover.close()
            }
        }
        if timerModel.state == .finished {
            startFlashSequence()
        }
    }

    // MARK: — Flash Sequence

    private func startFlashSequence() {
        flashTimer?.invalidate()    // guard against double-start
        flashCount = 0
        // Cache image before loop; 8Hz × 2s = 16 NSImage lookups otherwise
        flashTimer = Timer.scheduledTimer(withTimeInterval: 0.125, repeats: true) {
            [weak self] t in
            guard let self else { t.invalidate(); return }
            flashCount += 1
            statusItem.button?.image = flashCount.isMultiple(of: 2) ? timerIcon : nil
            if flashCount >= 16 {
                t.invalidate()
                flashTimer = nil
                timerModel.cancel()         // resets state to .inactive
            }
        }
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = self
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler handler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        handler([.banner, .sound])   // show banner even when app is frontmost
    }
}
```

**Known limitation — NSPopover `.transient` double-toggle:** When `.transient` dismisses the popover on an outside click, it also fires the button's action. At that point `isShown == false`, so `togglePopover` falls into the `else` branch and immediately re-opens the popover. The `togglePopover` code shown above does **not** prevent this.

The robust fix is to use `NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown])` to detect outside clicks and close the popover yourself, combined with `popover.behavior = .applicationDefined`. Implement this during Phase 3 polish if the re-open flicker is noticeable in testing.

### Arc Dial — Math & Rendering

**Angle-to-duration mapping:**
- 0 radians = 12 o'clock (top). Clockwise = more time.
- `duration (seconds) = (cumulativeAngle / (2π)) × 3600`
- No hard cap; each full revolution = 60 more minutes

**Drag gesture — the gesture attaches to the VIEW wrapping Canvas, not inside Canvas closure:**

```swift
// ArcDialView.swift
struct ArcDialView: View {
    @Bindable var model: TimerModel
    @State private var cumulativeAngle: Double = 0   // in radians
    @State private var lastAngle: Double = 0
    @State private var isDragging = false
    @State private var snapPulse = false

    private var arcAngle: Double {
        guard model.totalDuration > 0 else { return cumulativeAngle }
        return model.state == .inactive
            ? cumulativeAngle
            : (model.remaining / model.totalDuration) * cumulativeAngle
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Canvas { context, size in
                    drawArc(context: context, size: size)
                }
                .scaleEffect(snapPulse ? 1.03 : 1.0)
                .animation(.spring(duration: 0.12), value: snapPulse)

                centerLabel(geo: geo)
            }
            .gesture(
                // coordinateSpace: .local is essential on macOS for correct coordinates
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { [self] value in
                        handleDragChanged(value, in: geo.size)
                    }
                    .onEnded { [self] value in
                        handleDragEnded(value)
                    }
            )
        }
        .aspectRatio(1, contentMode: .fit)
    }
}
```

**Angle accumulation (wrap-safe):**

```swift
private func handleDragChanged(_ value: DragGesture.Value, in size: CGSize) {
    let center = CGPoint(x: size.width / 2, y: size.height / 2)
    let dx = value.location.x - center.x
    let dy = value.location.y - center.y
    var angle = atan2(dx, -dy)              // 0 = top, clockwise positive
    if angle < 0 { angle += 2 * .pi }      // normalize [0, 2π]

    if isDragging {
        // Compute shortest-path delta to handle 0/2π wrap-around
        var delta = angle - lastAngle
        if delta > .pi  { delta -= 2 * .pi }
        if delta < -.pi { delta += 2 * .pi }
        cumulativeAngle = max(0, cumulativeAngle + delta)
        applySnap()
    } else {
        isDragging = true
    }
    lastAngle = angle

    // Update model's running remaining if adjusting mid-timer
    if model.state == .running {
        let newDuration = (cumulativeAngle / (2 * .pi)) * 3600
        model.adjustRemaining(to: newDuration)
    }
}

private func handleDragEnded(_ value: DragGesture.Value) {
    isDragging = false
    if model.state == .inactive {
        let duration = (cumulativeAngle / (2 * .pi)) * 3600
        if duration >= 60 {
            model.start(duration: duration)    // AppDelegate observes .running → closes popover
        } else {
            cumulativeAngle = 0               // no-op: reset arc
        }
    }
}
```

**Soft snap (5-minute increments = π/6 radians per 5-min slot):**

```swift
private func applySnap() {
    let snapInterval: Double = .pi / 6       // 30° = 5 minutes
    let snapThreshold: Double = .pi / 36     // ±5° tolerance
    let nearest = round(cumulativeAngle / snapInterval) * snapInterval
    if nearest > 0 && abs(cumulativeAngle - nearest) < snapThreshold {
        cumulativeAngle = nearest
        if !snapPulse {
            snapPulse = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                self.snapPulse = false
            }
        }
    }
}
```

**Canvas drawing — single sweep (no multi-revolution ghost rings):**

The arc angle = `cumulativeAngle mod 2π` for the setting state; for the running state, `(remaining / totalDuration) * cumulativeAngle`. A single depleting arc correctly represents all durations without stacked-ring complexity.

```swift
private func drawArc(context: GraphicsContext, size: CGSize) {
    let center = CGPoint(x: size.width / 2, y: size.height / 2)
    let radius = min(size.width, size.height) / 2 - 20
    let startAngle = Angle.degrees(-90)                     // 12 o'clock

    // 1. Background track ring
    var track = Path()
    track.addArc(center: center, radius: radius,
                 startAngle: startAngle, endAngle: .degrees(270), clockwise: false)
    context.stroke(track,
                   with: .color(.secondary.opacity(0.2)),
                   style: StrokeStyle(lineWidth: 14, lineCap: .round))

    // 2. Filled arc
    let sweepDeg = (arcAngle.truncatingRemainder(dividingBy: 2 * .pi)) / (2 * .pi) * 360
    guard sweepDeg > 0 else { return }
    var arc = Path()
    arc.addArc(center: center, radius: radius,
               startAngle: startAngle,
               endAngle: .degrees(-90 + sweepDeg),
               clockwise: false)
    // NOTE: clockwise: false draws VISUALLY clockwise due to SwiftUI's flipped Y-axis
    context.stroke(arc,
                   with: .color(.accentColor),
                   style: StrokeStyle(lineWidth: 14, lineCap: .round))

    // 3. Knob dot at arc endpoint
    let endRad = Angle.degrees(-90 + sweepDeg).radians
    let knobCenter = CGPoint(x: center.x + radius * cos(endRad),
                             y: center.y + radius * sin(endRad))
    let knob = Path(ellipseIn: CGRect(x: knobCenter.x - 9, y: knobCenter.y - 9,
                                      width: 18, height: 18))
    context.fill(knob, with: .color(.accentColor))
}
```

**Center label — private struct inside ArcDialView (no separate file):**

```swift
@ViewBuilder
private func centerLabel(geo: GeometryProxy) -> some View {
    let duration = (cumulativeAngle / (2 * .pi)) * 3600   // seconds
    let effectiveRemaining = model.state == .running ? model.remaining : duration
    let totalMin = Int(effectiveRemaining) / 60
    let totalSec = Int(effectiveRemaining) % 60

    VStack(spacing: 2) {
        if duration >= 60 || model.state == .running {
            // End time — respects system 12/24-hour setting
            Text(endTimeLabel)
                .font(.caption2)
                .foregroundStyle(.blue)
        }
        if model.state == .running && totalMin >= 60 {
            Text("\(totalMin / 60)h \(totalMin % 60)m")
                .font(.title2.bold())
        } else {
            Text("\(totalMin)m")
                .font(.title2.bold())
        }
        if model.state == .running {
            Text("\(totalSec)s")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

private var endTimeLabel: String {
    guard let end = model.endDate ?? {
        let d = (cumulativeAngle / (2 * .pi)) * 3600
        return d >= 60 ? Date.now.addingTimeInterval(d) : nil
    }() else { return "" }
    let fmt = DateFormatter()
    fmt.timeStyle = .short      // respects system 12/24-hour preference
    fmt.dateStyle = .none
    return fmt.string(from: end)
}
```

### Notification Permission — Deferred to First Timer Start

```swift
// In AppDelegate, called from model observation when state transitions to .running for the first time
private func requestNotificationPermissionIfNeeded() {
    UNUserNotificationCenter.current().getNotificationSettings { settings in
        if settings.authorizationStatus == .notDetermined {
            UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
    }
}
```

Call this in `handleStateTransitions()` when `timerModel.state == .running`.

### Entitlements & Info.plist

**Info.plist keys:**
```xml
<key>LSUIElement</key><true/>
<!-- No NSUserNotificationUsageDescription — this key does not exist on macOS.
     The notification permission dialog text is system-generated. -->
```

**Epoch.entitlements:**
```xml
<key>com.apple.security.app-sandbox</key><true/>
```

**Required Xcode build settings for notarization:**
- `ENABLE_HARDENED_RUNTIME = YES`
- `CODE_SIGN_IDENTITY = Developer ID Application: ...`
- `CODE_SIGN_ENTITLEMENTS = Epoch/Epoch.entitlements`

---

## Implementation Phases (3, down from 6)

### Phase 1: App Shell + Timer Model + Basic Popover

- [x] Create Xcode project: macOS App, Swift, target macOS 14, bundle ID `de.nfelger.epoch`
- [x] Delete generated `ContentView.swift` and `@main App` struct boilerplate
- [x] Add `@main` to `EpochApp.swift` with `@NSApplicationDelegateAdaptor`; `NSPrincipalClass` not needed with SwiftUI App entry point
- [x] Set `LSUIElement = YES` in Info.plist (Application is agent)
- [x] Implement `NSStatusItem` with timer SF Symbol + `NSPopover` with stub content
- [x] Implement `TimerModel` with state machine, `start()`, `cancel()`, `tick()`, `adjustRemaining()`
- [x] Implement `AppDelegate.observeModel()` with `withObservationTracking`; drive status item from model state
- [x] Enable `ENABLE_HARDENED_RUNTIME = YES` in target build settings
- [x] Add `UNUserNotificationCenter.current().delegate = self` in `applicationWillFinishLaunching`

**Success criteria:** App shows timer icon in menubar, no Dock entry. `timerModel.start(duration: 10)` → menubar counts down → `timerModel.cancel()` → icon returns.

### Phase 2: Arc Dial

- [x] `ArcDialView` — `GeometryReader` + `Canvas` drawing background ring + filled arc + knob dot
- [x] `DragGesture` with cumulative angle tracking (wrap-safe delta computation)
- [x] Soft snap: ±5° tolerance, snap pulse via `scaleEffect` + `withAnimation`
- [x] Drag-release → `model.start()` if duration ≥ 60s; else reset arc to 0
- [x] Running state: arc fraction = `remaining / totalDuration`; dial still draggable → `model.adjustRemaining()`
- [x] Center label inline in `ArcDialView`: end time (blue) + Xm (large) + Xs (gray, running only)
- [x] End time uses `DateFormatter.timeStyle = .short` for locale-correct 12/24h
- [x] Cancel button in `PopoverContentView` → `model.cancel()`; AppDelegate closes popover via state observation

**Success criteria:** Full drag-set-and-start flow. Snap pulses at 5-min marks. Running arc drains. Cancel returns to inactive.

### Phase 3: Completion Effects + Polish

- [x] `NSSound(named: "Glass")` with `NSSound(named: "Purr")` fallback in `TimerModel.finishCountdown()`
- [x] `UNUserNotificationCenter` notification on completion
- [x] Request notification permission on first timer start (not on launch)
- [x] `AppDelegate.startFlashSequence()` — 16 alternations at 0.125s (2 seconds total); `[weak self]`; cached image
- [x] Ensure `timerModel.cancel()` in flash sequence → auto-return to inactive
- [ ] Fix NSPopover double-toggle (test `.transient` behavior manually; document workaround)
- [ ] Adjust popover content size and padding
- [ ] Test on both light and dark menubar

**Success criteria:** Timer hits 0 → chime + notification + 2-second flash → returns to timer icon. User can start a new timer immediately after.

---

## System-Wide Impact

### Interaction Graph

`DragGesture.onEnded` → `model.start()` → `state = .running` → `withObservationTracking` fires in AppDelegate → `updateStatusItem()` switches to `MM:SS` title + fixed width → `popover.close()` deferred by one run-loop turn.

Each second: `Timer.tick()` → `model.remaining` updated → `withObservationTracking` fires → `updateStatusItem()` updates title.

At t=0: `tick()` → `model.finishCountdown()` → `state = .finished` + `NSSound.play()` + `UNNotificationRequest` → `withObservationTracking` fires → `AppDelegate.startFlashSequence()` → 16-step timer at 0.125s → `model.cancel()` → `state = .inactive` → `updateStatusItem()` restores icon.

### Thread Safety

- `TimerModel` is `@MainActor` — all mutations on main thread
- `Timer` scheduled on `.main` RunLoop in `.common` mode (fires during drag tracking)
- Flash timer owned by `AppDelegate` — also on `.main` RunLoop
- `UNUserNotificationCenter.add()` is thread-safe from any thread
- `NSStatusItem` updated only from `AppDelegate.updateStatusItem()` — always on `@MainActor`

### State Lifecycle Risks

| Risk | Mitigation |
|---|---|
| Flash timer orphaned by `cancel()` | `flashTimer` stored as `AppDelegate` property; `timerModel.cancel()` (called from flash sequence) triggers `withObservationTracking` → `updateStatusItem` restores icon |
| Double-start via drag-release during flash | `start()` guards `duration >= 60`; flash timer is owned by AppDelegate separate from model |
| `adjustRemaining` called in non-running state | Guard `state == .running` at top of method |
| Drag reduces remaining to 0 | `adjustRemaining(to: 0)` calls `finishCountdown()` immediately |
| Timer drift on sleep/wake | `endDate`-based `tick()` is wall-clock correcting; completion fires on wake if expired |
| `popover.close()` during gesture handler | Deferred by `DispatchQueue.main.async` — one run-loop turn past gesture stack frame |

### Integration Test Scenarios

1. Drag to 5m → release → popover closes → menubar shows `5:00` → counts to `0:01` → `0:00` → chime → 2s flash → returns to timer icon
2. Start 10m timer → click menubar → drag arc to adjust to 15m → remaining updates → cancel → inactive
3. Drag arc very slowly through 25:00 mark → snap fires, center shows `25m`
4. Drag arc past 360° → center shows `1h 5m` and `[time+65min]` in blue; start → menubar shows `1:04` (H:MM format)
5. Timer finishes while popover is open → chime + flash → popover closes → timer icon
6. Start timer → flash sequence starts → user starts new timer within 2s → new timer runs correctly (old flash cancelled)
7. Notification permission denied → timer still completes with chime + flash only (notification silently omitted)

---

## Acceptance Criteria

### Functional

- [ ] App launches with timer SF Symbol in menubar, no Dock entry, no App Switcher entry
- [ ] Click menubar icon → popover with blank arc dial + background ring visible as affordance
- [ ] Drag arc clockwise → center shows projected end time (blue, small, locale-correct) + Xm (large)
- [ ] Soft snap to 5-min marks with scale pulse animation
- [ ] Drag past 360° extends duration; center shows `Xh Ym` for >60 min
- [ ] Drag-release below 1 min → no timer started, popover stays open
- [ ] Drag-release ≥ 1 min → timer starts, popover closes automatically
- [ ] Menubar shows `MM:SS` for durations < 60 min; `H:MM` for ≥ 60 min
- [ ] Click menubar while running → draining arc + Cancel button + Xs label visible
- [ ] Arc adjustable while running (drag → `adjustRemaining`)
- [ ] Cancel → immediate inactive state + popover closes + timer icon
- [ ] Timer reaches 0 → Glass chime (Purr as fallback)
- [ ] macOS notification banner fires (if permission granted)
- [ ] Notification permission requested on first timer start (not on launch)
- [ ] Menubar icon flashes for 2 seconds then returns to timer icon
- [ ] New timer can be set immediately after completion

### Non-Functional

- [ ] App binary < 5 MB
- [ ] No third-party Swift packages
- [ ] Minimum macOS 14
- [ ] Works in both light and dark menu bar modes
- [ ] Hardened Runtime enabled; builds cleanly for notarization with Developer ID

---

## Dependencies & Risks

| Risk | Mitigation |
|---|---|
| `DragGesture` angle tracking wraps at ±π | Delta-based accumulation with `shortestAngleDelta` |
| `NSPopover` `.transient` double-toggle | Document and test; consider `NSEvent.addLocalMonitorForEvents` if annoying in practice |
| `UserNotifications` permission denied | Degrade gracefully — chime + flash still work |
| `NSSound(named: "Glass")` nil | Fallback to `NSSound(named: "Purr")`; then `NSSound.beep()` — treat fallback as mandatory code |
| Drag at 120Hz on ProMotion | `@State`-local angle accumulation in `ArcDialView`; propagate to model only on release if hitching observed |
| Timer drift on sleep/wake | Wall-clock `endDate` self-corrects; completion fires on wake if already past |
| `NSPrincipalClass` not set | Xcode template creates `@main App` struct; must delete it and set `NSPrincipalClass` or `@main` on `AppDelegate` |

---

## Sources & References

### Origin

- **Brainstorm document:** [docs/brainstorms/2026-03-17-countdown-timer-menubar-app-brainstorm.md](../brainstorms/2026-03-17-countdown-timer-menubar-app-brainstorm.md)
  Key decisions carried forward: arc scale (360°=60min, no cap), drag-release-to-start + auto-close popover, Glass chime + notification + icon flash on completion, cancel-only (no pause), no persistence.

### Apple Frameworks Used

- `AppKit` — `NSStatusItem`, `NSStatusBar`, `NSPopover`, `NSHostingController`, `NSSound`
- `SwiftUI` — `Canvas`, `DragGesture`, `GeometryReader`, `@Observable`, `@MainActor`, `withObservationTracking`
- `UserNotifications` — `UNUserNotificationCenter`, `UNMutableNotificationContent`, `UNUserNotificationCenterDelegate`
- `Foundation` — `Timer`, `Date`, `DateFormatter`, `RunLoop`

### Key Patterns

- `withObservationTracking` + re-arm pattern for AppKit observation of `@Observable` models
- Delta-based cumulative angle tracking for multi-revolution drag gestures
- Flash timer ownership in AppDelegate (not TimerModel) to enable cancellation
- `RunLoop.main.add(timer, forMode: .common)` for ticks during drag tracking
- `statusItem.length = fixed` to prevent status bar reflow on each tick
