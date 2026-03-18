---
title: "feat: Add dev workflow tooling (debug builds, lint/format, tests)"
type: feat
status: completed
date: 2026-03-18
---

# Add Dev Workflow Tooling

Add `make build-debug`, `make lint`, `make format`, and `make test` to streamline the development loop.

## Acceptance Criteria

- [x] `make build-debug` runs a Debug configuration build (faster, no optimizations)
- [x] `make lint` runs SwiftLint on all Swift sources
- [x] `make format` runs SwiftFormat on all Swift sources
- [x] `make test` runs unit tests via xcodebuild
- [x] Unit tests exist for `TimerModel` covering state transitions
- [x] SwiftLint config (`.swiftlint.yml`) and SwiftFormat config (`.swiftformat`) are committed
- [x] XcodeGen `project.yml` includes an `EpochTests` unit test target
- [x] `CLAUDE.md` updated to reflect new commands
- [x] `README.md` added with super concise human-facing instructions (build, lint, format, test)
- [x] `TODO.md` updated to check off completed items
- [x] `CHANGELOG.md` updated

## MVP

### Phase 1: `make build-debug`

Add a Debug build target to the Makefile. This is the simplest change.

#### `Makefile` changes

```makefile
BUILD_DIR = $(shell xcodebuild -project Epoch.xcodeproj -scheme Epoch -configuration Release -showBuildSettings 2>/dev/null | grep -m1 'BUILT_PRODUCTS_DIR' | awk '{print $$NF}')
APP = $(BUILD_DIR)/Epoch.app

.PHONY: build build-debug deploy lint format test

build:
	xcodebuild -project Epoch.xcodeproj -scheme Epoch -configuration Release build

build-debug:
	xcodebuild -project Epoch.xcodeproj -scheme Epoch -configuration Debug build

deploy: build
	rm -rf /Applications/Epoch.app
	cp -r "$(APP)" /Applications/
	@echo "Installed to /Applications/Epoch.app"
```

### Phase 2: `make lint` and `make format`

Install SwiftLint and SwiftFormat via Homebrew, add config files, add Makefile targets.

#### `.swiftlint.yml`

```yaml
included:
  - Epoch
```

Use default rules with no disabled rules. The codebase is small — fix all violations rather than suppressing them.

#### `.swiftformat`

```
--swiftversion 5.9
--indent 4
--stripunusedargs closure-only
```

#### Makefile additions

```makefile
lint:
	swiftlint lint --strict Epoch/

format:
	swiftformat Epoch/
```

The targets assume `swiftlint` and `swiftformat` are installed (`brew install swiftlint swiftformat`). No install-if-missing magic — keep it simple and document in CLAUDE.md.

### Phase 3: `make test` and initial unit tests

#### `project.yml` — add test target

```yaml
  EpochTests:
    type: bundle.unit-test
    platform: macOS
    sources:
      - path: EpochTests
    dependencies:
      - target: Epoch
    settings:
      base:
        SWIFT_VERSION: "5.9"
        MACOSX_DEPLOYMENT_TARGET: "14.0"
```

After editing `project.yml`, regenerate with `xcodegen generate`.

#### `EpochTests/TimerModelTests.swift`

Test the `TimerModel` state machine — it's pure logic with no AppKit dependencies. All tests need `@MainActor` since `TimerModel` is `@MainActor`-isolated.

Test cases:
- **Initial state**: model starts `.inactive`, `remainingSeconds` is 0
- **Start with valid duration**: transitions to `.running`, sets `endDate` in the future
- **Start guard**: duration < 60 seconds is rejected (stays `.inactive`)
- **Cancel**: running → inactive, clears `endDate`
- **Adjust remaining to zero**: running → finished
- **Adjust remaining negative**: running → finished
- **Double start**: calling `start` while `.running` should be a no-op or update

#### Makefile addition

```makefile
test:
	xcodebuild test -project Epoch.xcodeproj -scheme Epoch -destination 'platform=macOS'
```

Note: The auto-generated XcodeGen scheme should include the test target. If it doesn't, add an explicit `schemes` section to `project.yml`.

## Technical Considerations

- **`@MainActor` in tests**: All `TimerModel` test methods must be `@MainActor`. Use Swift Testing's `@Test @MainActor` or XCTest's `@MainActor func testX()`.
- **XCTest vs Swift Testing**: Prefer XCTest for now — it's the established pattern and doesn't require Swift 6 features. Can migrate later.
- **Timer ticks**: Don't test `tick()` directly (it's private). Test observable state transitions instead. For time-dependent behavior, set `endDate` to the past and call `adjustRemaining`.
- **SwiftLint/SwiftFormat installation**: Document as a prerequisite in CLAUDE.md rather than auto-installing. The Makefile should fail clearly if tools are missing.
- **XcodeGen regeneration**: After modifying `project.yml`, `xcodegen generate` must be run. The Makefile could include a `generate` target but it's not strictly necessary for this PR.

## Sources

- Existing Makefile: `Makefile`
- XcodeGen config: `project.yml`
- TimerModel source: `Epoch/TimerModel.swift`
- Architecture docs: `docs/solutions/how-to/macos-menubar-countdown-timer-swift.md`
