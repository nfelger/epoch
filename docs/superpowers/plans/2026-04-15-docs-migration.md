# Docs Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate all 20 documentation files from `docs/{brainstorms,plans,solutions}` to `docs/superpowers/{brainstorms,plans,knowledge}` with normalized filenames, stripped YAML frontmatter, superpowers-format plan headers, and updated cross-references.

**Architecture:** Three migration types run in parallel — brainstorms get heading/title normalization; plans get frontmatter stripped and a superpowers header prepended; knowledge files get frontmatter stripped and cross-references updated. Old folders deleted after migration. `CLAUDE.md` updated.

**Tech Stack:** Git, Markdown

---

## Task 1: Create destination folders

**Files:**
- Create: `docs/superpowers/brainstorms/`
- Create: `docs/superpowers/plans/`
- Create: `docs/superpowers/knowledge/build-errors/`
- Create: `docs/superpowers/knowledge/how-to/`
- Create: `docs/superpowers/knowledge/ui-bugs/`

Note: `docs/superpowers/specs/` already exists (created when the design doc was committed).

- [ ] **Step 1: Create all destination directories**

```bash
mkdir -p docs/superpowers/brainstorms
mkdir -p docs/superpowers/plans
mkdir -p docs/superpowers/knowledge/build-errors
mkdir -p docs/superpowers/knowledge/how-to
mkdir -p docs/superpowers/knowledge/ui-bugs
```

Expected: no output, no errors.

---

## Task 2: Write migrated brainstorm files

**Transformation rules applied to every brainstorm:**
1. Strip "Brainstorm: " prefix from the `#` title (if present), strip " Brainstorm" suffix from title (if present)
2. Rename `## What We're Building` → `## Goal`
3. Delete the `**Status:** ...` metadata line
4. Delete `## Open Questions` section when its only content is a "None" sentence

**Source → target filename mapping:**

| Source | Target |
|--------|--------|
| `docs/brainstorms/2026-03-17-countdown-timer-menubar-app-brainstorm.md` | `docs/superpowers/brainstorms/2026-03-17-countdown-timer-menubar-app.md` |
| `docs/brainstorms/2026-03-18-app-icon-brainstorm.md` | `docs/superpowers/brainstorms/2026-03-18-app-icon.md` |
| `docs/brainstorms/2026-03-20-arc-dial-visual-refinement-brainstorm.md` | `docs/superpowers/brainstorms/2026-03-20-arc-dial-visual-refinement.md` |
| `docs/brainstorms/2026-03-20-flash-animation-redesign-brainstorm.md` | `docs/superpowers/brainstorms/2026-03-20-flash-animation-redesign.md` |
| `docs/brainstorms/2026-03-20-release-workflow-brainstorm.md` | `docs/superpowers/brainstorms/2026-03-20-release-workflow.md` |

- [ ] **Step 1: Write `2026-03-17-countdown-timer-menubar-app.md`**

Write to `docs/superpowers/brainstorms/2026-03-17-countdown-timer-menubar-app.md`:

```markdown
# macOS Menubar Countdown Timer

**Date:** 2026-03-17

---

## Goal

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
```

- [ ] **Step 2: Write `2026-03-18-app-icon.md`**

Write to `docs/superpowers/brainstorms/2026-03-18-app-icon.md`:

```markdown
# App Bundle Icon

**Date:** 2026-03-18

## Goal

A macOS app icon for Epoch that visually echoes the in-app arc dial UI. The icon will be monochrome (black/white/gray), hand-crafted as SVG or programmatic drawing, and included in the app bundle via an asset catalog.

Even though Epoch is a menubar-only app (LSUIElement), the icon appears in Finder, Spotlight, Activity Monitor, Force Quit, and the About dialog. A proper icon replaces the generic "app" placeholder and gives Epoch a recognizable identity.

## Why This Approach

- **Arc/dial concept** — Maintains visual continuity between the icon and the app's primary UI element. Users who see the icon in Finder will immediately associate it with the circular timer they interact with.
- **Monochrome palette** — Fits the macOS system aesthetic, ages well across light/dark mode, and keeps the design simple.
- **Hand-crafted in code/SVG** — No external design tool dependencies. Easy to iterate and version-control friendly. Aligns with the project's zero-dependency philosophy.

## Key Decisions

1. **Visual concept:** Arc/dial inspired — echoes the app's circular countdown UI
2. **Color palette:** Monochrome (black, white, gray)
3. **Creation method:** Hand-crafted SVG or programmatic generation — no external design tools
4. **Arc state:** Flexible — optimize for legibility at small sizes (16x16 through 1024x1024)

## Design Considerations

- macOS app icons need sizes: 16, 32, 64, 128, 256, 512, 1024 (with @1x and @2x variants)
- The icon must read clearly at 16x16 — fine details will be lost, so the arc stroke needs to be bold enough
- Monochrome icons should have good contrast in both light and dark Finder backgrounds
- The rounded-rect mask is applied automatically by macOS — design within the full square canvas

## Open Questions

1. **Asset pipeline:** SVG-to-PNG conversion at build time requires a tool (e.g. `rsvg-convert`), adding a dependency. Alternative: author the SVG once, render PNGs at all required sizes, and commit the PNGs directly. The SVG stays in the repo as the editable source but the PNGs are the actual build input. Which approach to use is a planning decision.
```

- [ ] **Step 3: Write `2026-03-20-arc-dial-visual-refinement.md`**

Write to `docs/superpowers/brainstorms/2026-03-20-arc-dial-visual-refinement.md`:

```markdown
# Arc Dial Visual Refinement

**Date:** 2026-03-20

## Goal

A visual polish pass on the arc dial to improve legibility and aesthetics. Four changes:

1. **Thicker ticks (3pt)** — increase from 1.5pt to 3pt stroke width for better visibility
2. **Ticks extend beyond track** — ticks protrude past the arc on both inner and outer edges, making them more prominent gauge marks
3. **Semi-transparent arc (80% opacity)** — the active arc becomes translucent so ticks show through underneath when the arc covers them
4. **Flat start, rounded end** — the arc origin at 12 o'clock uses a butt/square cap; the end near the drag handle keeps a round cap
5. **Fully opaque white drag handle** — the knob at the arc endpoint is solid white
6. **Custom muted color palette** — softer, less saturated colors for all revolution tiers instead of the current vibrant system accent and bold RGB values

## Why This Approach

The current design hides tick marks behind the active arc, making it hard to gauge duration at a glance once you've dragged past a few ticks. The vibrant system blue is visually heavy for a utility that should feel calm and unobtrusive. A semi-transparent arc with muted colors lets the dial feel lighter while keeping ticks always visible as reference marks — like a real gauge or clock face.

## Key Decisions

- **Ticks stay behind the arc in draw order** — visibility comes from arc transparency, not from drawing ticks on top. This keeps the visual layering natural (gauge marks beneath the fill).
- **80% opacity on active arc** — enough transparency to see ticks through, but still clearly reads as a filled region.
- **3pt tick width** — double the current 1.5pt. Combined with extending beyond the track, ticks become a prominent visual scaffold.
- **Flat cap at origin only** — achieved by drawing start and end segments separately or using a path-based approach. The arc doesn't "bulge" past 12 o'clock.
- **White opaque knob** — stands out clearly against the muted arc color.
- **Muted palette for all revolutions** — softer versions of blue, red, magenta, purple for the 1h/2h/3h/4h+ tiers.

## Reference

User-provided mockup showing: cornflower blue semi-transparent arc, 3pt ticks extending beyond track, white dot handle, flat start at noon position.
```

- [ ] **Step 4: Write `2026-03-20-flash-animation-redesign.md`**

Write to `docs/superpowers/brainstorms/2026-03-20-flash-animation-redesign.md`:

```markdown
# Flash Animation Redesign

**Date:** 2026-03-20

---

## Goal

Replace the current flash animation (which uses `.backgroundColor` on `NSAttributedString` — broken in the menu bar) with a 3-frame SF Symbol strobe cycle that fires when the countdown finishes.

### The Cycle (repeating, 0.3s per tick)

| Tick (mod 3) | Status item appearance |
|---|---|
| 0 | Completely empty — no image, no text, item collapses |
| 1 | `slowmo` SF Symbol, bright orange (`NSColor.systemOrange`) |
| 2 | `timelapse` SF Symbol, bright red (`NSColor.systemRed`) |

- **Duration:** ~3 seconds (10 ticks), then auto-cancel and revert to idle clock icon
- **Blank tick:** `button?.image = nil`, `button?.title = ""` — the item shrinks to near-zero width for dramatic pop-in effect
- **Post-flash state:** normal idle clock icon (same as current inactive state)

---

## Why This Approach

### Problems with current implementation
The current flash uses `.backgroundColor` on `NSMutableAttributedString` applied to `NSStatusBarButton.attributedTitle`. Background color attributes on menu bar text are unreliable — they render clipped, misaligned, or inconsistently across macOS versions and system appearances.

### Why the 3-frame strobe
- Avoids all attributed string / background color rendering: pure image swaps on `button?.image`
- The blank frame creates a stark visual contrast (item literally disappears and reappears), which is more eye-catching than a color toggle alone
- Two distinct symbols (`slowmo` → `timelapse`) carry implicit semantic meaning (time slowing → time elapsed) and provide motion-like progression within the cycle
- Bright orange + red progression reads as an escalating urgency signal without being alarming

### Why "middle ground" urgency
- Noticeable within a few seconds without being jarring
- 3-second auto-cancel keeps it brief — doesn't demand immediate action
- Reverts to idle icon, so there's no lingering "something is wrong" state

---

## Key Decisions

1. **Image-based, not text-based** — use `button?.image` with `NSImage(systemSymbolName:)`, not `attributedTitle`. Eliminates background color rendering issues.
2. **Colored (non-template) symbols** — use `NSImage.withSymbolConfiguration` with `NSImageSymbolConfiguration(paletteColors:)` or `init(hierarchicalColor:)` to force specific colors. Template images would render in the system tint and ignore the orange/red.
3. **Three-frame cycle** — `flashCount % 3` determines frame: 0 = blank, 1 = orange `slowmo`, 2 = red `timelapse`.
4. **`squareLength` during colored frames, `variableLength` or collapse during blank frame** — to allow the blank tick to actually collapse the item width.
5. **Same timer cadence** — 0.3s interval, 10 ticks, then `timerModel.cancel()`.

---

## Technical Notes

```swift
// Rendering a colored SF Symbol (non-template)
let config = NSImageSymbolConfiguration(paletteColors: [.systemOrange])
let image = NSImage(systemSymbolName: "slowmo", accessibilityDescription: nil)?
    .withSymbolConfiguration(config)
button?.image = image
button?.image?.isTemplate = false  // ensure it stays colored
```

The `isTemplate = false` flag must be set after applying the configuration, or AppKit may override the color with the system tint.
```

- [ ] **Step 5: Write `2026-03-20-release-workflow.md`**

Write to `docs/superpowers/brainstorms/2026-03-20-release-workflow.md`:

```markdown
# Release Workflow

**Date:** 2026-03-20

---

## Goal

A fully automated `make release` command that bumps the version, stamps the changelog, commits, tags, builds, zips the app bundle, and creates a GitHub release — all in one command.

### Release flow

```
make release VERSION=0.2.0
```

1. Update `CFBundleShortVersionString` in `project.yml` to the given version
2. Update `CFBundleVersion` (increment build number)
3. Stamp `CHANGELOG.md`: rename `[Unreleased]` → `[0.2.0] - 2026-03-20`; add empty `[Unreleased]` section above
4. Run `xcodegen` to regenerate the Xcode project (picks up new version from project.yml)
5. Run `make lint` and `make test` as a gate
6. Commit: `"release: v0.2.0"`
7. Tag: `v0.2.0`
8. `make build` (release build)
9. Zip the `.app` bundle → `Epoch-0.2.0.zip`
10. `gh release create v0.2.0 Epoch-0.2.0.zip --title "Epoch 0.2.0" --notes-from-tag` (or extract notes from CHANGELOG)

---

## Key Decisions

1. **Distribution: GitHub release, unsigned** — No Apple Developer account. Users right-click → Open to bypass Gatekeeper. Simplest path for a personal project.
2. **Versioning: Semantic versioning** — Major.minor.patch. First release is v0.1.0.
3. **Artifact: Zipped .app bundle** — Users unzip and drag to /Applications. No DMG complexity.
4. **Automation: Fully automated** — Single `make release VERSION=x.y.z` command handles everything.
5. **Version source of truth: `project.yml`** — XcodeGen generates Info.plist from it, so project.yml is the single place to update. Info.plist version values are overridden by the XcodeGen-generated values at project generation time.
6. **VERSION parameter is required** — No default version bump logic; the caller specifies the exact version.
```

---

## Task 3: Write migrated plan files

**Transformation rules applied to every plan:**
1. Strip YAML frontmatter (the `---` block at the top)
2. Replace the existing `#` title line with the superpowers header block (shown per file below)
3. For `2026-03-17` only: delete the "Enhancement Summary" section (everything between the first `---` after the title and `## Overview`)
4. Update cross-references (listed per file)

**Source → target filename mapping:**

| Source | Target |
|--------|--------|
| `docs/plans/2026-03-17-001-feat-epoch-menubar-countdown-timer-plan.md` | `docs/superpowers/plans/2026-03-17-epoch-menubar-countdown-timer.md` |
| `docs/plans/2026-03-18-001-feat-dev-workflow-tooling-plan.md` | `docs/superpowers/plans/2026-03-18-dev-workflow-tooling.md` |
| `docs/plans/2026-03-19-001-feat-app-bundle-icon-plan.md` | `docs/superpowers/plans/2026-03-19-app-bundle-icon.md` |
| `docs/plans/2026-03-19-002-feat-right-click-menu-quit-plan.md` | `docs/superpowers/plans/2026-03-19-right-click-menu-quit.md` |
| `docs/plans/2026-03-20-001-feat-arc-dial-visual-refinement-plan.md` | `docs/superpowers/plans/2026-03-20-arc-dial-visual-refinement.md` |

- [ ] **Step 1: Write `2026-03-17-epoch-menubar-countdown-timer.md`**

Read `docs/plans/2026-03-17-001-feat-epoch-menubar-countdown-timer-plan.md`. Write `docs/superpowers/plans/2026-03-17-epoch-menubar-countdown-timer.md` with these changes:

**Remove:** Lines 1–36 (YAML frontmatter + Enhancement Summary section, up to and including the `---` separator before `## Overview`).

**Prepend** this header in their place:

```markdown
# Epoch Menubar Countdown Timer — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build Epoch, a native macOS menubar countdown timer with a tactile arc dial UI, three-state model, and completion effects.

**Architecture:** SwiftUI/AppKit hybrid — `NSStatusItem` + `NSPanel` manage menubar presence; `@Observable TimerModel` is a pure state machine with wall-clock `endDate`; SwiftUI `Canvas` + `DragGesture` handle the arc dial; `AppDelegate` drives all side effects via `withObservationTracking`.

**Tech Stack:** Swift 5.9, SwiftUI (Canvas, DragGesture, @Observable), AppKit (NSStatusItem, NSPanel, NSSound), UserNotifications, XcodeGen, macOS 14+

---

```

**Keep** everything from `## Overview` to end of file.

**Update refs** in the "Sources & References" section at the bottom:
- `docs/brainstorms/2026-03-17-countdown-timer-menubar-app-brainstorm.md` → `docs/superpowers/brainstorms/2026-03-17-countdown-timer-menubar-app.md`
- `(../brainstorms/2026-03-17-countdown-timer-menubar-app-brainstorm.md)` → `(../brainstorms/2026-03-17-countdown-timer-menubar-app.md)`

- [ ] **Step 2: Write `2026-03-18-dev-workflow-tooling.md`**

Read `docs/plans/2026-03-18-001-feat-dev-workflow-tooling-plan.md`. Write `docs/superpowers/plans/2026-03-18-dev-workflow-tooling.md` with these changes:

**Remove:** YAML frontmatter (lines 1–6).

**Replace** `# Add Dev Workflow Tooling` with:

```markdown
# Dev Workflow Tooling — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `make build-debug`, `make lint`, `make format`, and `make test` to streamline the development loop.

**Architecture:** Makefile targets drive xcodebuild (Debug configuration) and Homebrew-installed SwiftLint/SwiftFormat; `project.yml` gains an `EpochTests` unit test target; tests cover `TimerModel` state transitions.

**Tech Stack:** Swift 5.9, XcodeGen, SwiftLint, SwiftFormat, XCTest, Makefile, macOS 14+

---

```

**Keep** everything from `Add make build-debug...` paragraph onward.

**Update ref** in the "Sources" section:
- `docs/solutions/how-to/macos-menubar-countdown-timer-swift.md` → `docs/superpowers/knowledge/how-to/macos-menubar-countdown-timer-swift.md`

- [ ] **Step 3: Write `2026-03-19-app-bundle-icon.md`**

Read `docs/plans/2026-03-19-001-feat-app-bundle-icon-plan.md`. Write `docs/superpowers/plans/2026-03-19-app-bundle-icon.md` with these changes:

**Remove:** YAML frontmatter (lines 1–7).

**Replace** `# feat: Add App Bundle Icon` with:

```markdown
# App Bundle Icon — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a monochrome arc/dial app icon so Epoch shows a recognizable identity in Finder, Spotlight, and Activity Monitor instead of the generic placeholder.

**Architecture:** Master 1024×1024 PNG drawn via a CoreGraphics script (`scripts/generate_icon.swift`); `sips` resizes to all 9 smaller macOS icon sizes; asset catalog wired through XcodeGen's `sources` stanza. No external tool dependencies.

**Tech Stack:** Swift (CoreGraphics), sips (macOS built-in), XcodeGen, xcassets, Makefile

---

```

**Keep** everything from `## Overview` onward.

**Update refs** in the "Sources" section:
- `docs/brainstorms/2026-03-18-app-icon-brainstorm.md` (two occurrences: in prose and as link href) → `docs/superpowers/brainstorms/2026-03-18-app-icon.md`

- [ ] **Step 4: Write `2026-03-19-right-click-menu-quit.md`**

Read `docs/plans/2026-03-19-002-feat-right-click-menu-quit-plan.md`. Write `docs/superpowers/plans/2026-03-19-right-click-menu-quit.md` with these changes:

**Remove:** YAML frontmatter (lines 1–6).

**Replace** `# feat: Add right-click menu with Quit and About actions` with:

```markdown
# Right-Click Menu (Quit + About) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a right-click context menu to the status bar icon with "About Epoch" and "Quit Epoch" items, while preserving left-click popover behaviour.

**Architecture:** All changes in `AppDelegate.swift` — `button.sendAction(on: [.leftMouseUp, .rightMouseUp])` + event type inspection; lazy `NSMenu` property; `showAbout` activates the app before presenting the panel.

**Tech Stack:** Swift 5.9, AppKit (NSStatusItem, NSMenu, NSMenuItem, NSApp)

---

```

**Keep** everything from `The app is menubar-only...` paragraph onward.

**Update ref** in the "Sources" section:
- `docs/solutions/how-to/macos-menubar-countdown-timer-swift.md` → `docs/superpowers/knowledge/how-to/macos-menubar-countdown-timer-swift.md`

- [ ] **Step 5: Write `2026-03-20-arc-dial-visual-refinement.md`**

Read `docs/plans/2026-03-20-001-feat-arc-dial-visual-refinement-plan.md`. Write `docs/superpowers/plans/2026-03-20-arc-dial-visual-refinement.md` with these changes:

**Remove:** YAML frontmatter (lines 1–7).

**Replace** `# feat: Arc dial visual refinement` with:

```markdown
# Arc Dial Visual Refinement — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Polish the arc dial's visual appearance with six targeted changes: thicker/longer ticks, semi-transparent arc, flat start cap, white knob, and a muted color palette.

**Architecture:** All changes confined to `Epoch/Views/ArcDialView.swift` — surgical edits to `drawArc`, `drawTickMarks`, and `revolutionColor` methods. No new files or architectural changes.

**Tech Stack:** Swift 5.9, SwiftUI (Canvas, StrokeStyle)

---

```

**Keep** everything from `## Overview` onward.

**Update refs** in body and "Sources" section:
- `docs/brainstorms/2026-03-20-arc-dial-visual-refinement-brainstorm.md` (two occurrences) → `docs/superpowers/brainstorms/2026-03-20-arc-dial-visual-refinement.md`

---

## Task 4: Write migrated knowledge files

**Transformation rules applied to every knowledge file:**
1. Strip YAML frontmatter (the `---` block at the top, including all keys up to and including the closing `---`)
2. Update cross-references listed per file below
3. Keep all content sections exactly as-is

**Source → target path mapping** (filenames unchanged):

| Source | Target |
|--------|--------|
| `docs/solutions/how-to/changelog-best-practices.md` | `docs/superpowers/knowledge/how-to/changelog-best-practices.md` |
| `docs/solutions/how-to/macos-app-icon-xcodegen-asset-catalog.md` | `docs/superpowers/knowledge/how-to/macos-app-icon-xcodegen-asset-catalog.md` |
| `docs/solutions/how-to/macos-menubar-countdown-timer-swift.md` | `docs/superpowers/knowledge/how-to/macos-menubar-countdown-timer-swift.md` |
| `docs/solutions/how-to/nsstatusitem-right-click-context-menu.md` | `docs/superpowers/knowledge/how-to/nsstatusitem-right-click-context-menu.md` |
| `docs/solutions/how-to/swift-dev-workflow-xcodegen-lint-test.md` | `docs/superpowers/knowledge/how-to/swift-dev-workflow-xcodegen-lint-test.md` |
| `docs/solutions/how-to/swiftui-canvas-arc-dial-visual-refinement.md` | `docs/superpowers/knowledge/how-to/swiftui-canvas-arc-dial-visual-refinement.md` |
| `docs/solutions/how-to/automated-macos-release-workflow.md` | `docs/superpowers/knowledge/how-to/automated-macos-release-workflow.md` |
| `docs/solutions/build-errors/xcode-missing-gitignore-tracked-user-files.md` | `docs/superpowers/knowledge/build-errors/xcode-missing-gitignore-tracked-user-files.md` |
| `docs/solutions/ui-bugs/popover-jumping-and-interaction-fixes.md` | `docs/superpowers/knowledge/ui-bugs/popover-jumping-and-interaction-fixes.md` |
| `docs/solutions/ui-bugs/nspanel-replacement-and-rainbow-flash-animation.md` | `docs/superpowers/knowledge/ui-bugs/nspanel-replacement-and-rainbow-flash-animation.md` |

- [ ] **Step 1: Write `knowledge/how-to/changelog-best-practices.md`**

Read source. Strip frontmatter (lines 1–5, the `---`/`name`/`description`/`tags` block). Write to target. No ref updates needed.

- [ ] **Step 2: Write `knowledge/how-to/macos-app-icon-xcodegen-asset-catalog.md`**

Read source. Strip frontmatter (lines 1–7). Write to target. No ref updates needed.

- [ ] **Step 3: Write `knowledge/how-to/macos-menubar-countdown-timer-swift.md`**

Read source. Strip frontmatter (lines 1–22). Write to target.

**Update refs** in the "Related Documentation" section:
- `../../brainstorms/2026-03-17-countdown-timer-menubar-app-brainstorm.md` → `../../brainstorms/2026-03-17-countdown-timer-menubar-app.md`
- `../../plans/2026-03-17-001-feat-epoch-menubar-countdown-timer-plan.md` → `../../plans/2026-03-17-epoch-menubar-countdown-timer.md`

- [ ] **Step 4: Write `knowledge/how-to/nsstatusitem-right-click-context-menu.md`**

Read source. Strip frontmatter (lines 1–15). Write to target. No ref updates needed (same-dir link `macos-menubar-countdown-timer-swift.md` is unchanged).

- [ ] **Step 5: Write `knowledge/how-to/swift-dev-workflow-xcodegen-lint-test.md`**

Read source. Strip frontmatter (lines 1–6). Write to target. No ref updates needed.

- [ ] **Step 6: Write `knowledge/how-to/swiftui-canvas-arc-dial-visual-refinement.md`**

Read source. Strip frontmatter (lines 1–12). Write to target.

**Update refs** in the "Related" section:
- `../../brainstorms/2026-03-20-arc-dial-visual-refinement-brainstorm.md` → `../../brainstorms/2026-03-20-arc-dial-visual-refinement.md`
- `../../plans/2026-03-20-001-feat-arc-dial-visual-refinement-plan.md` → `../../plans/2026-03-20-arc-dial-visual-refinement.md`

- [ ] **Step 7: Write `knowledge/how-to/automated-macos-release-workflow.md`**

Read source. Strip frontmatter (lines 1–13). Write to target. No ref updates needed (all same-dir links to unchanged filenames).

- [ ] **Step 8: Write `knowledge/build-errors/xcode-missing-gitignore-tracked-user-files.md`**

Read source. Strip frontmatter (lines 1–18). Write to target.

**Update ref** in "Related Documentation" section:
- `docs/solutions/` → `docs/superpowers/knowledge/` (in the sentence "This is the first entry in `docs/solutions/`.")

- [ ] **Step 9: Write `knowledge/ui-bugs/popover-jumping-and-interaction-fixes.md`**

Read source. Strip frontmatter (lines 1–11). Write to target. No ref updates needed (all relative links use `../how-to/` which stays valid).

- [ ] **Step 10: Write `knowledge/ui-bugs/nspanel-replacement-and-rainbow-flash-animation.md`**

Read source. Strip frontmatter (lines 1–18). Write to target. No ref updates needed (all relative links use `../how-to/` or same-dir — all stay valid).

---

## Task 5: Update CLAUDE.md

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Update changelog path in CLAUDE.md**

In `CLAUDE.md`, in the `## Changelog` section, update:

```markdown
See `docs/solutions/how-to/changelog-best-practices.md` for full guidelines.
```

→

```markdown
See `docs/superpowers/knowledge/how-to/changelog-best-practices.md` for full guidelines.
```

---

## Task 6: Delete old folders and commit

**Files:**
- Delete: `docs/brainstorms/` (all 5 files + directory)
- Delete: `docs/plans/` (all 5 files + directory)
- Delete: `docs/solutions/` (all 10 files + subdirectories)

- [ ] **Step 1: Delete old folder trees**

```bash
rm -rf docs/brainstorms docs/plans docs/solutions
```

Expected: no errors. Verify with `ls docs/` — should show only `superpowers/`.

- [ ] **Step 2: Stage and commit all changes**

```bash
git add -A docs/ CLAUDE.md
git status
```

Expected: ~40 files changed (20 deleted, 20 new in superpowers/).

```bash
git commit -m "docs: Migrate docs to docs/superpowers/ with superpowers-format structure"
```

- [ ] **Step 3: Verify**

```bash
ls docs/superpowers/brainstorms/
ls docs/superpowers/plans/
ls docs/superpowers/knowledge/how-to/
ls docs/superpowers/knowledge/build-errors/
ls docs/superpowers/knowledge/ui-bugs/
```

Expected:
```
docs/superpowers/brainstorms/:
2026-03-17-countdown-timer-menubar-app.md
2026-03-18-app-icon.md
2026-03-20-arc-dial-visual-refinement.md
2026-03-20-flash-animation-redesign.md
2026-03-20-release-workflow.md

docs/superpowers/plans/:
2026-03-17-epoch-menubar-countdown-timer.md
2026-03-18-dev-workflow-tooling.md
2026-03-19-app-bundle-icon.md
2026-03-19-right-click-menu-quit.md
2026-03-20-arc-dial-visual-refinement.md
2026-04-15-docs-migration.md   ← this plan
2026-04-15-docs-migration-design.md  ← (in specs/, not here)

docs/superpowers/knowledge/how-to/:
automated-macos-release-workflow.md
changelog-best-practices.md
macos-app-icon-xcodegen-asset-catalog.md
macos-menubar-countdown-timer-swift.md
nsstatusitem-right-click-context-menu.md
swift-dev-workflow-xcodegen-lint-test.md
swiftui-canvas-arc-dial-visual-refinement.md

docs/superpowers/knowledge/build-errors/:
xcode-missing-gitignore-tracked-user-files.md

docs/superpowers/knowledge/ui-bugs/:
nspanel-replacement-and-rainbow-flash-animation.md
popover-jumping-and-interaction-fixes.md
```
