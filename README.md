# Epoch

A macOS menubar countdown timer with a circular arc dial.

## Features

- Drag the arc to set any duration — 360° = 60 minutes, keep dragging for longer
- Soft snap to 5-minute increments
- Countdown lives in the menu bar as `MM:SS` (or `H:MM` for longer timers)
- Chime + system notification when done
- No Dock icon, no main window

## Requirements

macOS 14+

## Usage

Click the timer icon in the menu bar. Drag the arc clockwise to set a duration, then release to start. The countdown appears in the menu bar. Click again to open the dial and adjust or cancel.

## Setup

```sh
brew install xcodegen swiftlint swiftformat
xcodegen generate
```

## Build

```sh
make build          # Release
make build-debug    # Debug (faster)
make deploy         # Build + install to /Applications
```

## Development

```sh
make lint    # SwiftLint (strict)
make format  # SwiftFormat
make test    # Unit tests
```

## Implementation

See [docs/plans/](docs/plans/) for the full implementation plan and [docs/brainstorms/](docs/brainstorms/) for design decisions.
