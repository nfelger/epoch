# Dark Mode Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the arc dial look good in both light and dark mode by replacing hardcoded colors with a material disc and warm analogous arc palette.

**Architecture:** All changes are in `Epoch/Views/ArcDialView.swift`. The Canvas-drawn cream disc is replaced with a SwiftUI `Circle` backed by `.ultraThinMaterial` layered behind the Canvas. Revolution colors switch to a warm amber→orange→coral→rose progression. The knob uses an adaptive system color.

**Tech Stack:** Swift/SwiftUI, macOS 14+

---

### Task 1: Replace cream disc with material circle

**Files:**
- Modify: `Epoch/Views/ArcDialView.swift:45-77` (body), `Epoch/Views/ArcDialView.swift:150-163` (drawArc)

- [ ] **Step 1: Add material circle to ZStack, before the Canvas**

In the `body` computed property, add a `Circle` with `.ultraThinMaterial` as the first element of the ZStack, sized to match the current disc radius. The disc radius formula is `arcRadius + arcLineWidth/2 + 4`, which equals `min(size.width, size.height) / 2 - 15 + 5 + 4 = min/2 - 6`. Since the view is constrained to 142x142 by OverlayContentView, this is `71 - 6 = 65`, so diameter = 130.

Replace the body:

```swift
var body: some View {
    GeometryReader { geo in
        let discDiameter = (arcRadius(in: geo.size) + arcLineWidth / 2 + 4) * 2

        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: discDiameter, height: discDiameter)

            Canvas { context, size in
                drawArc(context: context, size: size)
            }

            centerLabel(geo: geo)
        }
        .contentShape(AnyShape(KnobHitShape(
            center: CGPoint(x: geo.size.width / 2, y: geo.size.height / 2),
            arcRadius: arcRadius(in: geo.size),
            angleDeg: knobAngleDeg
        )))
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .local)
                .onChanged { value in
                    handleDragChanged(value, in: geo.size)
                }
                .onEnded { value in
                    handleDragEnded(value)
                }
        )
        .onHover { hovering in
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
    .aspectRatio(1, contentMode: .fit)
}
```

- [ ] **Step 2: Remove the disc-drawing code from drawArc**

In the `drawArc` method, delete the "Contrast disc" block (lines 157–163). Remove these lines:

```swift
// Contrast disc
let discRadius = radius + arcLineWidth / 2 + 4
var disc = Path()
disc.addEllipse(in: CGRect(
    x: center.x - discRadius, y: center.y - discRadius,
    width: discRadius * 2, height: discRadius * 2
))
context.fill(disc, with: .color(Color(red: 0.96, green: 0.95, blue: 0.93).opacity(0.9)))
```

- [ ] **Step 3: Build and verify**

Run: `make build-debug`
Expected: Builds successfully. The disc is now a frosted material circle instead of a cream fill.

- [ ] **Step 4: Commit**

```bash
git add Epoch/Views/ArcDialView.swift
git commit -m "refactor: replace hardcoded cream disc with material circle"
```

---

### Task 2: Update knob color to adaptive system color

**Files:**
- Modify: `Epoch/Views/ArcDialView.swift:178,208` (knob fill color in drawArc)

- [ ] **Step 1: Replace hardcoded white knob with adaptive color**

In the `drawArc` method, find the two places where the knob is filled with `.color(.white)`:

```swift
// Around line 178 (zero-angle knob):
context.fill(knobPath(center: center, radius: radius, angleDeg: -90, diameter: 14),
             with: .color(.white))

// Around line 208 (active knob):
context.fill(knobPath(center: center, radius: radius,
                       angleDeg: -90 + endSweepDeg, diameter: knobSize),
             with: .color(.white))
```

Replace both `.color(.white)` with:

```swift
.color(Color(nsColor: .controlBackgroundColor))
```

- [ ] **Step 2: Build and verify**

Run: `make build-debug`
Expected: Builds successfully. Knob is white in light mode, dark gray in dark mode.

- [ ] **Step 3: Commit**

```bash
git add Epoch/Views/ArcDialView.swift
git commit -m "fix: use adaptive color for dial knob"
```

---

### Task 3: Replace arc colors with warm analogous palette

**Files:**
- Modify: `Epoch/Views/ArcDialView.swift:211-219` (revolutionColor method)

- [ ] **Step 1: Update the revolutionColor method**

Replace the entire `revolutionColor` method:

```swift
/// Color for each revolution layer: amber → orange → coral → rose
private func revolutionColor(revolution: Int) -> Color {
    switch revolution {
    case 0: Color(red: 0.90, green: 0.65, blue: 0.20) // amber
    case 1: Color(red: 0.92, green: 0.50, blue: 0.20) // orange
    case 2: Color(red: 0.90, green: 0.38, blue: 0.35) // coral
    default: Color(red: 0.88, green: 0.30, blue: 0.45) // rose
    }
}
```

- [ ] **Step 2: Build and verify**

Run: `make build-debug`
Expected: Builds successfully. Arc shows warm amber for the first revolution.

- [ ] **Step 3: Commit**

```bash
git add Epoch/Views/ArcDialView.swift
git commit -m "style: warm analogous arc color palette (amber→orange→coral→rose)"
```

---

### Task 4: Update changelog, lint, and test

**Files:**
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Add changelog entry**

Add under `## [Unreleased]`, in the `### Changed` section:

```markdown
- Arc dial now uses a frosted material background and warm color palette (amber → orange → coral → rose) that adapts to both light and dark mode
```

- [ ] **Step 2: Run lint**

Run: `make lint`
Expected: No lint errors.

- [ ] **Step 3: Run tests**

Run: `make test`
Expected: All tests pass.

- [ ] **Step 4: Run format**

Run: `make format`
Expected: No changes, or auto-fixes applied.

- [ ] **Step 5: Commit**

```bash
git add CHANGELOG.md
git commit -m "docs: add dark mode fix to changelog"
```
