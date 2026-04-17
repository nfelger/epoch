# Transparent Timer Overlay

## Summary

A floating, semi-transparent overlay panel that keeps the arc dial timer visible while the timer runs, rather than hiding the UI and showing only a menubar countdown. The overlay is on by default, togglable via the menubar right-click menu.

## Overlay Panel Setup

A new `NSPanel` owned by `AppDelegate`, created at launch alongside the existing popover panel:

- **Style:** `.borderless`, `.nonactivatingPanel`, `.closable`, `.fullSizeContentView`
- **Title bar:** Hidden visually (`titlebarAppearsTransparent = true`, `titleVisibility = .hidden`) — only the red close button is visible
- **Level:** `.floating` — above normal windows, below the popover
- **Collection behavior:** `[.canJoinAllSpaces, .fullScreenAuxiliary]` — visible on all aerospace workspaces and in fullscreen spaces
- **Transparency:** `alphaValue = 0.5` during running state, `1.0` when finished
- **Background:** Clear with `NSVisualEffectView` backdrop (same as existing panel), muted by panel-level alpha
- **Size:** 174×174 (same as existing panel)
- **Content:** Reuses `ArcDialView` via a new `FirstMouseHostingView` instance bound to the same `TimerModel`

## Lifecycle

1. **Timer starts** → overlay panel appears at the default position (below menubar icon, same as popover), popover hides
2. **Timer running** → overlay visible at 50% opacity, menubar continues showing countdown text
3. **Timer finishes** → overlay snaps to 100% opacity, red pulsing border starts, menubar flash sequence also plays
4. **User dismisses finished overlay** (close button or "Cancel Timer" in context menu) → overlay hides, timer resets to inactive
5. **User closes overlay while running** (close button) → overlay hides, timer keeps running in menubar only
6. **User clicks menubar icon while overlay is hidden but timer is running** → overlay reappears at its last position
7. **Feature toggled off** via right-click menu → overlay hides, timer continues in menubar only

## Interaction Model

- **Drag the knob** → adjusts remaining time (existing `ArcDialView` drag behavior, unchanged)
- **Drag anywhere else on the panel** → moves the panel. Implemented by overriding `mouseDown`/`mouseDragged` on the panel's content view, forwarding to `window?.performDrag(with:)`
- **Close button (red dot)** → hides overlay, timer continues in menubar
- **Right-click on overlay** → no context menu (that lives on the menubar icon)
- **No hover opacity change** (keep simple, can revisit later)

## Finished State — Pulsing Red Border

When the timer finishes, the overlay snaps to full opacity and displays a pulsing red border:

- A `RoundedRectangle` stroke overlay inside the SwiftUI view, animated with repeating ease-in-out opacity (0.4 → 1.0)
- Corner radius matches panel's 12px rounded corners
- Border width: ~3px
- Color: system red
- Pulse speed: ~1 second per cycle
- Stops when user closes the overlay or cancels the timer
- `ArcDialView` (or its wrapper) observes `TimerModel.state == .finished` to trigger the border

## Settings Persistence & Menu Toggle

- **Storage:** `UserDefaults`, key `showTimerOverlay`, type `Bool`
- **Default:** `true` (on by default)
- **Menu item:** Checkmarked "Show Timer Overlay" in the existing right-click context menu on the menubar icon
- **Toggle off while running:** overlay hides immediately, timer continues in menubar
- **Toggle on while running:** overlay reappears at default position

## Multi-Screen / Aerospace Behavior

- `canJoinAllSpaces` makes the panel visible across all aerospace workspaces without aerospace managing it
- The panel stays where the user placed it; no automatic repositioning across screens
- This is the simplest approach — may be revisited based on real-world feel

## Technical Approach

Separate `NSPanel` for the overlay (Approach A), distinct from the existing popover panel used for setting the timer. The two panels have fundamentally different lifecycles and interaction rules — the popover anchors to the menubar and dismisses on outside click, while the overlay floats freely and persists.

The existing popover panel and its behavior remain unchanged. The overlay is an additive feature.
