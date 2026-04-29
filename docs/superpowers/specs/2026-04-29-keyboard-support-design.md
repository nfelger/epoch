# Keyboard Support Design

## Feature 1: URL Scheme Panel Toggle

Register an `epoch` custom URL scheme so external tools (aerospace, Raycast, etc.) can toggle the overlay panel.

### Supported URLs

- `epoch://toggle` — toggle panel visibility
- `epoch://open` — show panel
- `epoch://close` — hide panel

### Implementation

- Add `CFBundleURLTypes` entry to `Info.plist` with scheme `epoch`
- Implement `application(_:open:)` in `AppDelegate`
- Route URL host (`toggle`, `open`, `close`) to existing `showOverlay()` / `hideOverlay()` methods

### External usage

Aerospace example: `bind-key cmd-shift-t exec open epoch://toggle`

## Feature 2: Keyboard Duration Input

Type integer minutes directly in the panel to set the timer, as an alternative to dragging.

### Behavior

- Only active when the panel is visible and timer state is `.inactive`
- Digit keys (0-9) append to a buffer, parsed as integer minutes
- Dial updates live as digits are typed — `cumulativeAngle` is set to match the typed minutes, producing the same visual as dragging
- Backspace removes the last digit from the buffer
- Enter starts the timer if duration >= 1 minute
- Dragging the dial clears the type buffer
- No special input display — center label shows the same duration as during drag

### Key event capture

- Use `.onKeyPress` modifier (macOS 14+) on `ArcDialView`
- Override `canBecomeKey` on the `NSPanel` subclass to return `true`, so the panel can receive key events despite `.nonactivatingPanel` style
- Call `makeKeyAndOrderFront` instead of `orderFront` when showing the panel

### State

- `@State private var typeBuffer: String = ""` in `ArcDialView`
- Typing sets `cumulativeAngle = Double(minutes) / 60.0 * 2 * .pi`
- Drag gesture resets `typeBuffer = ""`
