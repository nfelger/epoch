# Changelog

## [Unreleased]

### Added

- Floating transparent timer overlay that keeps the arc dial visible while the timer runs
- Overlay appears at 50% opacity during countdown, snaps to 100% with pulsing red border when finished
- Draggable overlay panel — drag the knob to adjust time, drag anywhere else to reposition
- "Show Timer Overlay" toggle in the right-click context menu, persisted via UserDefaults
- Overlay visible across all spaces and in fullscreen mode

## [0.1.0] - 2026-03-20

## [0.1.0] - 2026-03-20

## [0.1.0] - 2026-03-20

### Added

- `make release VERSION=x.y.z` command for fully automated releases (version bump, changelog stamp, lint, test, build, zip, GitHub release)

### Changed

- Replaced `NSPopover` with a borderless `NSPanel` (vibrancy + rounded corners) so the arc dial appears as a tipless panel flush with the menu bar, matching standard system menu appearance
- Flash animation on timer finish replaced: cycles a multicolor rainbow SF Symbol through `variableValue` steps on a timer, sweeping arcs from inner to outer

### Added

- Compact square popover with refined arc dial: semi-transparent arc (70% opacity) so tick marks show through, flat cap at 12 o'clock, white knob, and muted color palette
- Cancel timer action in the right-click context menu
- Popover stays open after timer starts for immediate adjustments
- Stable popover positioning (status bar width frozen while popover is open)
- Arc dial can be dragged to start a new timer during the flash-finished sequence
- Right-click context menu on menubar icon with "About Epoch" and "Quit Epoch" actions
- App bundle icon: monochrome arc/dial design on dark background, visible in Finder, Spotlight, and Activity Monitor
- `make icon` target to regenerate icon PNGs from the Swift source script
- Menubar countdown timer with arc dial UI and NSPopover
- Drag gesture to set duration with smooth dragging, rounded to whole minutes
- Multi-revolution support for durations beyond 60 minutes with layered arc colors
- Tick marks at 5-minute intervals on background track
- Snap to 5-minute increments on drag release
- "Drag to set" hint and always-visible knob on the dial
- Glass chime sound and system notification on timer completion
- Flash animation with red text alternation when timer finishes
- Hour display in menubar countdown for long timers
- Immediate drag interaction via `FirstMouseHostingView` (no focus required)
- XcodeGen project config and Makefile (`make build`, `make deploy`)
- `make build-debug` for faster debug builds
- `make lint` (SwiftLint) and `make format` (SwiftFormat) with config files
- `make test` with unit tests for TimerModel state machine
