---
title: Adding dev workflow tooling to a Swift/XcodeGen macOS project
category: how-to
date: 2026-03-18
tags: [swift, xcodegen, swiftlint, swiftformat, xctest, makefile, macos]
---

# Adding Dev Workflow Tooling (SwiftLint, SwiftFormat, XCTest) to a Swift/XcodeGen Project

## Problem

A Swift macOS app using XcodeGen had no debug build target, no linter/formatter, and no unit tests. Needed `make build-debug`, `make lint`, `make format`, and `make test`.

## Solution

### 1. Debug build — just add a Makefile target

```makefile
build-debug:
	xcodebuild -project Epoch.xcodeproj -scheme Epoch -configuration Debug build
```

### 2. SwiftLint + SwiftFormat — install, configure, fix violations

```sh
brew install swiftlint swiftformat
```

**`.swiftlint.yml`** — keep it minimal, use default rules:
```yaml
included:
  - Epoch
  - EpochTests
```

**`.swiftformat`**:
```
--swiftversion 5.9
--indent 4
--stripunusedargs closure-only
--allman false
```

**Key gotcha: SwiftFormat and SwiftLint can conflict.** SwiftFormat wraps long function signatures and moves the opening brace to a new line (`--allman` style), but SwiftLint's `opening_brace` rule requires the brace on the same line. Fix by using `--allman false` and formatting parameters like:

```swift
// This style satisfies both tools:
private func drawTickMarks(
    context: GraphicsContext, center: CGPoint, radius: CGFloat, lineWidth: CGFloat
) {
```

### 3. XCTest target in XcodeGen — add to `project.yml`

```yaml
targets:
  Epoch:
    # ... app target first ...

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
        GENERATE_INFOPLIST_FILE: YES  # Required — without this, code signing fails
```

**Critical: `GENERATE_INFOPLIST_FILE: YES`** — without this, `xcodebuild test` fails with "Cannot code sign because the target does not have an Info.plist file."

After editing `project.yml`, run `xcodegen generate` before `make test`.

### 4. Testing `@MainActor`-isolated models

Mark the entire test class `@MainActor` to match the model's isolation:

```swift
@MainActor
final class TimerModelTests: XCTestCase {
    var model: TimerModel!

    override func tearDown() {
        model.cancel()  // Stop any running Timer to prevent cross-test interference
        model = nil
        super.tearDown()
    }
}
```

Test synchronous state transitions only — avoid testing timer tick behavior (requires real-time waits or clock injection). Use `accuracy:` for time-sensitive assertions:

```swift
XCTAssertEqual(model.remaining, 300, accuracy: 1)
```

## Prevention

- Always lint and format test files too — include `EpochTests` in both `.swiftlint.yml` and Makefile targets from the start.
- Avoid naming local variables `min` or `max` — they shadow Swift's global functions.
- Run `make format` then `make lint` to catch SwiftFormat/SwiftLint conflicts early.
