# Changelog

## [Unreleased]

### Added

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
