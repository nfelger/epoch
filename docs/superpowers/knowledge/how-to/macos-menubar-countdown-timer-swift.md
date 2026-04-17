# Building a macOS Menubar Countdown Timer with SwiftUI Arc Dial

## Architecture Overview

Epoch is a macOS menubar countdown timer built as a **Swift + SwiftUI/AppKit hybrid** with zero third-party dependencies, targeting macOS 14+.

**Why AppDelegate-based instead of pure SwiftUI?** `NSStatusItem` and `NSPopover` are AppKit-only APIs with no SwiftUI equivalent. The AppDelegate owns the status item, popover, and observation loop; SwiftUI is used only for the popover's content views.

**File layout (4 Swift files):**
- `EpochApp.swift` — `@main` entry point with `@NSApplicationDelegateAdaptor`; `Scene` body is `Settings { EmptyView() }` since all UI lives in the popover
- `AppDelegate.swift` — `NSStatusItem`, `NSPopover`, observation loop, completion effects (sound, notification, flash), `FirstMouseHostingView`
- `TimerModel.swift` — `@Observable` state machine (`inactive`/`running`/`finished`), countdown logic, no AppKit imports
- `Views/ArcDialView.swift` — Canvas-based circular dial with `DragGesture`, multi-revolution support, center label
- `Views/PopoverContentView.swift` — thin layout wrapper, conditionally shows Cancel button

**Observation bridge:** `withObservationTracking` in AppDelegate reads `@Observable` model properties, then re-arms itself in the `onChange` callback via `Task { @MainActor in self?.observeModel() }`. Inside the tracking closure, `updateStatusItem()` reads `state` and `remaining`, while `handleStateTransitions()` compares `state` against `lastObservedState` for one-shot effects.

## Key Technical Decisions

**Completion effects in AppDelegate, not TimerModel.** `finishCountdown()` in TimerModel only sets `state = .finished`. Sound (`NSSound`), notification (`UNUserNotificationCenter`), and flash animation are all triggered by AppDelegate detecting the `.finished` transition. This keeps the model free of AppKit/UI concerns and testable in isolation.

**`lastObservedState` for one-shot transitions.** Because `withObservationTracking` fires on every tick (since `remaining` changes each second), state-transition effects must fire only once. `handleStateTransitions()` compares current vs previous state.

**Timer on `.common` RunLoop mode.** `RunLoop.main.add(timer, forMode: .common)` ensures ticks fire even during drag tracking, which blocks `.default` mode timers.

**Wall-clock `endDate` for drift correction.** `remaining = max(0, endDate.timeIntervalSinceNow)` self-corrects after sleep/wake rather than decrementing a counter.

**Fixed status item width** (56px for `M:SS`, 72px for `H:MM:SS`) prevents menubar reflowing on each tick.

**Notification permission deferred to first timer start,** not app launch. `NSUserNotificationUsageDescription` does not exist on macOS — the dialog text is system-generated.

## Critical Bugs Fixed During Implementation

**1. Flash timer orphan destroying new timer state.** Flash timer not stored as a property meant an orphaned timer could fire `model.cancel()` and silently kill a newly-started countdown. Fix: `flashTimer` stored as property, invalidated at start of `startFlashSequence()`.

**2. Popover closing on every tick during running timer.** Initial code closed the popover whenever `state == .running`, not just on transition. Fix: `lastObservedState` tracking ensures close only on the `!= .running -> .running` transition.

**3. NSPopover `.transient` double-toggle.** When `.transient` auto-dismisses on outside click, the status bar button action also fires, immediately re-opening the popover. Fix: record `lastPopoverCloseTime` in `popoverDidClose`, suppress re-opens within 200ms.

**4. `arcAngle` broken for adjusted timers.** `remaining / totalDuration * cumulativeAngle` broke when the user adjusted a running timer. Fix: running-state `arcAngle` computed directly as `(model.remaining / 3600) * 2 * .pi`, independent of `totalDuration`.

**5. `popover.close()` during gesture handler.** Closing the popover inside a `DragGesture.onEnded` handler could cause issues. Fix: deferred by one run-loop turn via `DispatchQueue.main.async`.

## Arc Dial Interaction Model

**Angle system.** 0 radians = 12 o'clock. Clockwise = increasing angle = more time. Computed via `atan2(dx, -dy)`.

**Delta-based cumulative tracking.** Each drag change computes a delta from `lastAngle`, with wrap-around clamped at +/- pi. Delta accumulates into `cumulativeAngle` (floored at 0), allowing unlimited multi-revolution accumulation without discontinuities.

**Drag start sync.** When a drag begins on a running timer, `cumulativeAngle` is set to `(model.remaining / 3600) * 2 * .pi` so the knob matches the current countdown position.

**Duration rounding.** `rawSeconds = (cumulativeAngle / 2pi) * 3600`, rounded to whole minutes. Applied on drag change for running timers, on drag release for inactive state. Minimum duration: 1 minute (below that, `cumulativeAngle` resets to 0).

**Multi-revolution rendering.** Canvas draws layered arcs bottom-up. Color progression per revolution: accent (0), red (1), red-purple (2), deep purple (3+). Knob always visible at 12 o'clock when idle, grows from 18px to 22px during drag.

**Affordances.** "Drag to set" hint when idle, 12 tick marks at 5-minute intervals, `.onHover` with `NSCursor.pointingHand`, `.contentShape(Rectangle())` for full-area hit testing.

## Lessons Learned

- **Keep the model free of AppKit.** All `NSStatusItem` updates belong in AppDelegate, driven reactively via `withObservationTracking`. The model owns state only.
- **Track state transitions explicitly with `lastObservedState`.** Without this, every timer tick re-triggers one-shot effects (closing popover, starting flash).
- **Store secondary timers as owned properties.** Any fire-and-forget timer is a lifecycle hazard — invalidate at every exit point.
- **Override `acceptsFirstMouse` for NSHostingView in popovers.** Without `FirstMouseHostingView`, the first click activates the window but doesn't forward to SwiftUI gestures.
- **Schedule timers on `.common` RunLoop mode.** Default mode stops firing during UI tracking (drags).
- **Guard `.transient` popover double-toggle with a timestamp debounce.** The auto-dismiss click also triggers the status bar button action.
- **`NSUserNotificationUsageDescription` does not exist on macOS.** Don't add it to Info.plist — it's a silent no-op.
- **Use `MainActor.assumeIsolated` in Timer closures** scheduled on the main RunLoop to bridge `@Sendable` requirement without unnecessary async hops.

## Related Documentation

- [Original brainstorm](../../brainstorms/2026-03-17-countdown-timer-menubar-app.md) — defines three-state model, arc dial design, completion behavior
- [Implementation plan](../../plans/2026-03-17-epoch-menubar-countdown-timer.md) — comprehensive technical plan with 15 numbered design iterations
- [Xcode .gitignore setup](../build-errors/xcode-missing-gitignore-tracked-user-files.md) — project configuration for this same app
