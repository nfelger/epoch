# Brainstorm: macOS Menubar Countdown Timer

**Date:** 2026-03-17

---

## What We're Building

A lightweight native macOS menubar app called **Epoch** — a countdown timer that lives in the menu bar. The UI centers on a tactile circular arc dial (inspired by the TimeTimer) for setting and monitoring time remaining.

### Three States

| State | Menubar | Click opens |
|---|---|---|
| **Inactive** | Stopwatch icon | Arc dial to set duration → drag-release starts timer |
| **Running** | `MM:SS` countdown | Adjustable arc dial + Cancel button |
| **Finished** | Brief flash + icon resets | — (auto-returns to inactive) |

---

## Core Interaction Design

### Arc Dial Widget

- A circular arc rendered in a SwiftUI `Canvas` view
- 360° = 60 minutes; dragging beyond one full revolution extends the duration further (no hard cap)
- **Soft snapping** to 5-minute increments with a brief visual pulse at each snap point
- While running: arc drains counterclockwise showing time remaining; still draggable to adjust

**Center label — while setting (dragging):**
```
  12:45  ← projected end time, HH:MM, small, blue
  25m    ← selected duration in minutes, large, primary
```

**Center label — while running:**
```
  12:45  ← end time, HH:MM, small, blue
  25m    ← remaining minutes, large, primary
  30s    ← remaining seconds, small, dark gray
```

### Completion

- **Chime sound** (macOS system sound via `NSSound`, e.g. `Glass`)
- **macOS User Notification** banner (UserNotifications framework, requires permission)
- **Menubar icon flash/pulse** (animate NSStatusItem image via a short timer loop)
- Returns to inactive state automatically

---

## Why This Approach

**SwiftUI + AppKit hybrid** is the right choice:
- `NSStatusItem` / `NSPopover` from AppKit handle the menubar presence and popover anchoring
- SwiftUI `Canvas` + gesture recognizers handle the custom arc dial
- No third-party dependencies — ships as a tiny, self-contained `.app`

**Custom arc control** (not a system slider or stepper) because:
- It's visually distinctive and communicates "time remaining" naturally
- A circular form factor is compact enough to live in a popover
- SwiftUI `Canvas` + `DragGesture` makes this achievable without AppKit-style custom `NSView` subclasses

---

## Key Decisions

1. **Arc scale:** 360° = 60 minutes; dragging beyond one revolution extends the duration (no hard cap).
2. **Snap interval:** 5-minute increments, soft visual snap (no hard lock — slow drag gives finer control).
3. **Timer starts on drag-release**, not during drag (avoids accidental starts).
4. **Popover closes** automatically when the timer starts.
5. **Menubar text while running:** `MM:SS` format (e.g., `14:32`).
6. **Chime:** macOS system sound (`NSSound`, e.g. `Glass`). No bundled audio.
7. **Pause:** Not supported. Cancel-only returns to inactive state.
8. **No persistence:** Timer state is not saved across app restarts.
9. **Single timer only:** One timer at a time.
10. **Swift/Xcode project structure:** Standard macOS App target, no SwiftPM packages needed.

---

## Out of Scope (for now)

- Multiple simultaneous timers
- Timer history / statistics
- Menu bar preferences window
- Repeat / recurring timers
- iOS / watchOS companion
