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

## Building

Open `Epoch.xcodeproj` in Xcode 15+ and build the `Epoch` scheme.

For distribution, enable a Developer ID code signing certificate and run:

```sh
xcodebuild archive -scheme Epoch -archivePath Epoch.xcarchive
xcrun notarytool submit Epoch.xcarchive --wait
```

## Implementation

See [docs/plans/](docs/plans/) for the full implementation plan and [docs/brainstorms/](docs/brainstorms/) for design decisions.
