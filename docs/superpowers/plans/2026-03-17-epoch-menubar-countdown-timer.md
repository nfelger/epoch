# Epoch Menubar Countdown Timer — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build Epoch, a native macOS menubar countdown timer with a tactile arc dial UI, three-state model, and completion effects.

**Architecture:** SwiftUI/AppKit hybrid — `NSStatusItem` + `NSPanel` manage menubar presence; `@Observable TimerModel` is a pure state machine with wall-clock `endDate`; SwiftUI `Canvas` + `DragGesture` handle the arc dial; `AppDelegate` drives all side effects via `withObservationTracking`.

**Tech Stack:** Swift 5.9, SwiftUI (Canvas, DragGesture, @Observable), AppKit (NSStatusItem, NSPanel, NSSound), UserNotifications, XcodeGen, macOS 14+

---

## Overview

Build **Epoch**: a native macOS menubar app that implements a countdown timer with a tactile circular arc dial inspired by the TimeTimer. The app lives entirely in the menu bar — no Dock icon, no main window.

## Problem Statement

No existing lightweight, distraction-free macOS countdown timer offers the tactile satisfaction of a draggable arc dial that visually represents remaining time at a glance.

## Proposed Solution

A Swift + SwiftUI/AppKit hybrid app with three states (inactive → running → finished), a custom `Canvas`-based arc dial, and system integrations (notifications, sound) — zero third-party dependencies.

(see brainstorm: docs/superpowers/brainstorms/2026-03-17-countdown-timer-menubar-app.md)

---

## Technical Approach

### Architecture

```
Epoch/
├── EpochApp.swift              # @main SwiftUI App with @NSApplicationDelegateAdaptor
├── AppDelegate.swift           # NSStatusItem + NSPopover; model observation; flash sequence
├── TimerModel.swift            # @Observable state machine + countdown logic (no AppKit UI)
├── Views/
│   ├── PopoverContentView.swift # Root SwiftUI view inside the popover
│   └── ArcDialView.swift        # Canvas arc + DragGesture + center labels
└── Resources/
    ├── Info.plist               # LSUIElement=YES
    └── Epoch.entitlements       # App sandbox; ENABLE_HARDENED_RUNTIME in build settings
```

**`EpochApp.swift`** — `@main struct EpochApp: App` with `@NSApplicationDelegateAdaptor(AppDelegate.self)`. Uses a `Settings { EmptyView() }` scene since all UI is in the popover.

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

Key design decisions:

- **`@MainActor` on class** — required because `TimerModel.init()` is main-actor-isolated
- **`lastObservedState` tracking** — state transitions (popover close, flash start) fire only once per transition, not on every tick
- **`FirstMouseHostingView`** — NSHostingView subclass that overrides `acceptsFirstMouse` so the drag gesture works immediately without a click-to-focus first
- **`MainActor.assumeIsolated`** in Timer closures — satisfies Swift concurrency from `@Sendable` context
- **`@preconcurrency UNUserNotificationCenterDelegate`** — silences concurrency warning on delegate conformance

**Menubar format:** `M:SS` below 60 min, `H:MM:SS` at 60 min and above (wider status item: 72px). Previous `H:MM` format was too easily confused with `MM:SS`.

**Flash sequence:** On completion, shows "0:00" in the menubar alternating between red text on default background and white text on red background, at 300ms intervals for 10 cycles (3 seconds total), then auto-resets to inactive. Replaces the previous icon-flash approach which looked like a bug.

**Known limitation — NSPopover `.transient` double-toggle:** When `.transient` dismisses the popover on an outside click, it also fires the button's action. At that point `isShown == false`, so `togglePopover` falls into the `else` branch and immediately re-opens the popover. The robust fix is `NSEvent.addLocalMonitorForEvents` with `.applicationDefined` behavior.

### Arc Dial — Design & Rendering

**Angle-to-duration mapping:**
- 0 radians = 12 o'clock (top). Clockwise = more time.
- `duration (seconds) = (cumulativeAngle / (2π)) × 3600`
- No hard cap; each full revolution = 60 more minutes

**Affordances:**
- **Knob always visible** — blue dot sits at 12 o'clock even before any interaction; grows from 18px to 22px during drag
- **"Drag to set" hint text** — shown in center when idle and untouched
- **Tick marks on track** — 12 marks at 5-minute intervals spanning the full track width (inner edge to outer edge), with `butt` line caps
- **Pointing hand cursor** on hover via `.onHover` + `NSCursor.pointingHand`

**No snapping** — dragging is fully smooth. Duration rounds to whole minutes only on drag release (for starting a timer) and for display (center label, end time label). During running timer adjustment, the rounded value is fed to `adjustRemaining`.

**`arcAngle` computation:**
- **Inactive:** returns `cumulativeAngle` directly
- **Running + dragging:** returns `cumulativeAngle` (synced to remaining on drag start)
- **Running + not dragging:** returns `(model.remaining / 3600) * 2π` — computed directly from remaining time, not from `totalDuration` ratio (which breaks when adjusting)

**Drag start sync:** When a drag begins on a running timer, `cumulativeAngle` is set to `(model.remaining / 3600) * 2π` so the knob position matches the current remaining time.

**Multi-revolution arc coloring:**
Each full revolution draws as a stacked layer. The partial remainder draws on top. Color progression:
- Revolution 0 (0–60min): `.accentColor`
- Revolution 1 (60–120min): red (0.85, 0.25, 0.3)
- Revolution 2 (120–180min): red-purple (0.7, 0.15, 0.5)
- Revolution 3+ (180min+): deep purple (0.45, 0.1, 0.6)

Knob color matches the current (topmost) revolution.

**Center label:**
- Shows "Drag to set" when idle and untouched
- Duration display rounds to whole minutes: `((rawSeconds / 60).rounded() * 60)`
- "Xh Ym" format shows immediately when dragging past 60 min (not only when running)
- End time uses `DateFormatter.timeStyle = .short` for locale-correct 12/24h
- Running state adds seconds display below the main label

**`.contentShape(Rectangle())`** on the ZStack enables gesture hit-testing across the full area.

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
- [x] Smooth dragging with duration rounded to whole minutes on release
- [x] Affordances: always-visible knob, "Drag to set" hint, tick marks on track, pointing hand cursor
- [x] Multi-revolution arc with color progression (accent → red → purple)
- [x] Drag-release → `model.start()` if rounded duration ≥ 60s; else reset arc to 0
- [x] Running state: `arcAngle = (remaining / 3600) * 2π`; syncs `cumulativeAngle` on drag start for adjustment
- [x] Center label: end time (blue) + Xm or Xh Ym (large, during drag too) + Xs (gray, running only)
- [x] End time uses `DateFormatter.timeStyle = .short` for locale-correct 12/24h
- [x] Cancel button in `PopoverContentView` → `model.cancel()`; AppDelegate closes popover via state observation

**Success criteria:** Full drag-set-and-start flow. Smooth arc follows finger. Running arc drains. Multi-revolution shows color layers. Cancel returns to inactive.

### Phase 3: Completion Effects + Polish

- [x] `NSSound(named: "Glass")` with `NSSound(named: "Purr")` fallback in `TimerModel.finishCountdown()`
- [x] `UNUserNotificationCenter` notification on completion
- [x] Request notification permission on first timer start (not on launch)
- [x] Flash sequence: "0:00" text color alternation (red ↔ white-on-red) at 300ms, 10 cycles (3s)
- [x] Ensure `timerModel.cancel()` in flash sequence → auto-return to inactive
- [x] State transition tracking via `lastObservedState` — popover close and flash only fire once per transition
- [x] `FirstMouseHostingView` — immediate drag without click-to-focus
- [x] Fix NSPopover double-toggle — `NSPopoverDelegate.popoverDidClose` records timestamp; `togglePopover` suppresses re-open within 200ms
- [x] Adjust popover content size and padding — tightened to 230×240, 190×190 dial, balanced padding
- [x] Test on both light and dark menubar — all colors use semantic SwiftUI tokens (`.secondary`, `.accentColor`) and `NSColor.systemRed`

**Success criteria:** Timer hits 0 → chime + notification + 3-second text flash → returns to timer icon. User can start a new timer immediately after.

---

## System-Wide Impact

### Interaction Graph

`DragGesture.onEnded` → `model.start()` → `state = .running` → `withObservationTracking` fires in AppDelegate → `updateStatusItem()` switches to `MM:SS` title + fixed width → `popover.close()` deferred by one run-loop turn.

Each second: `Timer.tick()` → `model.remaining` updated → `withObservationTracking` fires → `updateStatusItem()` updates title.

At t=0: `tick()` → `model.finishCountdown()` → `state = .finished` + `NSSound.play()` + `UNNotificationRequest` → `withObservationTracking` fires → `handleStateTransitions()` detects `.finished` transition (via `lastObservedState`) → `startFlashSequence()` → 10-step timer at 0.3s alternating "0:00" text colors → `model.cancel()` → `state = .inactive` → `updateStatusItem()` restores icon.

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

1. Drag to 5m → release → popover closes → menubar shows `5:00` → counts to `0:01` → `0:00` → chime → 3s text flash → returns to timer icon
2. Start 10m timer → click menubar → popover stays open → drag arc to adjust to 15m → remaining updates → cancel → inactive
3. Drag arc smoothly — center label shows rounded minutes, arc follows finger precisely
4. Drag arc past 360° → center shows `1h 5m` and `[time+65min]` in blue; arc shows red layer underneath; start → menubar shows `1:04:XX` (H:MM:SS format)
5. Timer finishes while popover is open → chime + text flash → popover stays open → timer icon after 3s
6. Start timer → flash sequence starts → user starts new timer within 3s → new timer runs correctly (old flash cancelled)
7. Notification permission denied → timer still completes with chime + text flash only (notification silently omitted)
8. Open popover on running timer → drag immediately works (no click-to-focus required)

---

## Acceptance Criteria

### Functional

- [x] App launches with timer SF Symbol in menubar, no Dock entry, no App Switcher entry
- [x] Click menubar icon → popover with arc dial showing knob at 12 o'clock + "Drag to set" hint
- [x] Drag works immediately without click-to-focus (FirstMouseHostingView)
- [x] Drag arc clockwise → smooth arc follows finger; center shows rounded Xm + projected end time (blue)
- [x] Tick marks visible on track at 5-minute intervals
- [x] Drag past 360° → center switches to `Xh Ym`; arc layers with color progression (accent → red → purple)
- [x] Drag-release below 1 min → no timer started, popover stays open
- [x] Drag-release ≥ 1 min → duration rounds to nearest minute, timer starts, popover closes
- [x] Menubar shows `M:SS` for durations < 60 min; `H:MM:SS` for ≥ 60 min
- [x] Click menubar while running → draining arc + Cancel button + Xs label visible (popover stays open)
- [x] Arc adjustable while running — knob syncs to current remaining on drag start
- [x] Cancel → immediate inactive state + popover closes + timer icon
- [x] Timer reaches 0 → `burn complete.aif` chime (Glass → Purr → beep fallback)
- [x] macOS notification banner fires (if permission granted)
- [x] Notification permission requested on first timer start (not on launch)
- [x] Menubar shows "0:00" with alternating red/white text flash for 3 seconds then returns to timer icon
- [x] New timer can be set immediately after completion

### Non-Functional

- [x] App binary < 5 MB
- [x] No third-party Swift packages
- [x] Minimum macOS 14
- [x] Works in both light and dark menu bar modes — all colors use semantic SwiftUI tokens
- [x] Hardened Runtime enabled; builds cleanly for notarization with Developer ID

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

- **Brainstorm document:** [docs/superpowers/brainstorms/2026-03-17-countdown-timer-menubar-app.md](../brainstorms/2026-03-17-countdown-timer-menubar-app.md)
  Key decisions carried forward: arc scale (360°=60min, no cap), drag-release-to-start + auto-close popover, Glass chime + notification + icon flash on completion, cancel-only (no pause), no persistence.

### Apple Frameworks Used

- `AppKit` — `NSStatusItem`, `NSStatusBar`, `NSPopover`, `NSHostingController`, `NSSound`
- `SwiftUI` — `Canvas`, `DragGesture`, `GeometryReader`, `@Observable`, `@MainActor`, `withObservationTracking`
- `UserNotifications` — `UNUserNotificationCenter`, `UNMutableNotificationContent`, `UNUserNotificationCenterDelegate`
- `Foundation` — `Timer`, `Date`, `DateFormatter`, `RunLoop`

### Key Patterns

- `withObservationTracking` + re-arm pattern for AppKit observation of `@Observable` models
- `lastObservedState` tracking for one-shot state transition effects
- Delta-based cumulative angle tracking for multi-revolution drag gestures
- Smooth dragging with rounding only at output boundaries (release, display, model update)
- Multi-revolution Canvas rendering with layered color progression
- `FirstMouseHostingView` subclass for immediate drag interaction in NSPopover
- Flash timer ownership in AppDelegate (not TimerModel) to enable cancellation
- `MainActor.assumeIsolated` in Timer closures for Swift concurrency compliance
- `RunLoop.main.add(timer, forMode: .common)` for ticks during drag tracking
- `statusItem.length = fixed` to prevent status bar reflow on each tick
