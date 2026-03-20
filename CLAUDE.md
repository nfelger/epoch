## Project

Epoch is a native macOS menubar countdown timer built with Swift/SwiftUI. It has no Dock icon and no main window — it lives entirely in the menu bar with an NSPanel for the arc dial UI.

- **Language:** Swift 5.9, macOS 14+ deployment target
- **Dependencies:** None (system frameworks only: AppKit, SwiftUI, UserNotifications)
- **Project config:** XcodeGen (`project.yml`) generates `Epoch.xcodeproj`

## Build Commands

```sh
make build        # Release build via xcodebuild
make build-debug  # Debug build (faster, no optimizations)
make deploy       # Build + copy to /Applications
make lint         # SwiftLint (strict mode)
make format       # SwiftFormat
make test         # Unit tests via xcodebuild
make release VERSION=x.y.z  # Full release: bump, changelog, tag, build, GitHub release
```

Requires: `brew install swiftlint swiftformat xcodegen`

Run `make lint` and `make test` before committing. Run `make format` to auto-fix style issues.

## Changelog

- Maintain `CHANGELOG.md` following [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and [Common Changelog](https://github.com/vweevers/common-changelog) conventions. See `docs/solutions/how-to/changelog-best-practices.md` for full guidelines.
- When adding features, fixing bugs, or making other user-facing changes, always add an entry to the `[Unreleased]` section of `CHANGELOG.md`.

## Architecture

**AppDelegate** (`Epoch/AppDelegate.swift`) is the central coordinator. It owns the `NSStatusItem`, `NSPopover`, and `TimerModel`, and drives all AppKit side effects (status bar text, flash sequence, sound, notifications) by observing model state changes via `withObservationTracking`.

**TimerModel** (`Epoch/TimerModel.swift`) is a pure state machine with three states: `inactive` → `running` → `finished`. It uses wall-clock `endDate` (not decremented counters), making it self-correcting across sleep/wake.

**ArcDialView** (`Epoch/Views/ArcDialView.swift`) renders the circular dial using SwiftUI `Canvas` with `DragGesture`. Key details:
- Cumulative angle tracking with wrap-safe delta computation for multi-revolution support
- 360° = 60 minutes, unlimited revolutions with color progression per revolution layer
- Snap to 5-minute increments on release, smooth during drag
- 12 tick marks at 5-minute intervals on background track

**PopoverContentView** (`Epoch/Views/PopoverContentView.swift`) wraps the dial and cancel button in the popover.

**EpochApp** (`Epoch/EpochApp.swift`) is a minimal `@main` entry point that delegates to `AppDelegate`.

**Key patterns:**
- `@MainActor` isolation throughout — all UI state is main-actor bound
- `FirstMouseHostingView` (in AppDelegate) overrides `acceptsFirstMouse` so the popover responds to the first click without needing focus
- Completion effects (sound → notification → flash) are sequenced in AppDelegate, triggered by observing state transition to `.finished`
