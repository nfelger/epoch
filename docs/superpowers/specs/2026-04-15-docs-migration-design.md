# Docs Migration Design

**Date:** 2026-04-15

Migrate all documentation under `docs/` into the folder structure and file formats conventional for superpowers skills.

---

## Folder Structure

All docs move under `docs/superpowers/`. The old top-level folders (`brainstorms/`, `plans/`, `solutions/`) are deleted.

```
docs/superpowers/
├── brainstorms/        # design explorations (from docs/brainstorms/)
├── plans/              # implementation plans (from docs/plans/)
├── specs/              # design specs (this file lives here)
└── knowledge/          # how-to guides and bug fixes (from docs/solutions/)
    ├── build-errors/
    ├── how-to/
    └── ui-bugs/
```

`CLAUDE.md` reference to `docs/solutions/how-to/changelog-best-practices.md` is updated to `docs/superpowers/knowledge/how-to/changelog-best-practices.md`.

---

## Filename Normalization

**Plans** — drop `001-feat-` prefix and `-plan` suffix:

| Before | After |
|--------|-------|
| `2026-03-17-001-feat-epoch-menubar-countdown-timer-plan.md` | `2026-03-17-epoch-menubar-countdown-timer.md` |
| `2026-03-18-001-feat-dev-workflow-tooling-plan.md` | `2026-03-18-dev-workflow-tooling.md` |
| `2026-03-19-001-feat-app-bundle-icon-plan.md` | `2026-03-19-app-bundle-icon.md` |
| `2026-03-19-002-feat-right-click-menu-quit-plan.md` | `2026-03-19-right-click-menu-quit.md` |
| `2026-03-20-001-feat-arc-dial-visual-refinement-plan.md` | `2026-03-20-arc-dial-visual-refinement.md` |

**Brainstorms** — drop `-brainstorm` suffix:

| Before | After |
|--------|-------|
| `2026-03-17-countdown-timer-menubar-app-brainstorm.md` | `2026-03-17-countdown-timer-menubar-app.md` |
| `2026-03-18-app-icon-brainstorm.md` | `2026-03-18-app-icon.md` |
| `2026-03-20-arc-dial-visual-refinement-brainstorm.md` | `2026-03-20-arc-dial-visual-refinement.md` |
| `2026-03-20-flash-animation-redesign-brainstorm.md` | `2026-03-20-flash-animation-redesign.md` |
| `2026-03-20-release-workflow-brainstorm.md` | `2026-03-20-release-workflow.md` |

**Knowledge files** — filenames unchanged.

---

## Content Reformatting

### Plans

Restructure to superpowers checklist format:

- **Header**: goal, context (1–3 sentences)
- **Steps**: numbered checkboxes (`- [x]` since all are completed), with exact file paths and complete code blocks
- **Verification**: commands with expected output at the end

### Brainstorms

Add consistent structure:

- **Goal**: what was being figured out
- **Options considered**: each with trade-offs
- **Decision**: what was chosen and why
- **Outcome**: what was built / key insights

Preserve all substance; reshape the presentation.

### Knowledge files

Light touch — normalize heading hierarchy, ensure consistent structure:

- **Problem** (or **Goal** for how-tos)
- **Solution** (key steps/code)
- **Gotchas / Notes**

No major rewrites; content is already high quality.
