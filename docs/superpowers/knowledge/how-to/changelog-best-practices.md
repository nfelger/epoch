# Changelog Best Practices

Based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and [Common Changelog](https://github.com/vweevers/common-changelog).

## Format

- File: `CHANGELOG.md`
- First line: `# Changelog`
- Release heading: `## [VERSION] - YYYY-MM-DD` (no "v" prefix, ISO 8601 date)
- Keep an `## [Unreleased]` section at the top for in-progress changes
- Latest version first

## Change Categories (in order)

- `### Changed` — modifications to existing functionality
- `### Added` — new features
- `### Removed` — removed functionality
- `### Fixed` — bug fixes
- `### Deprecated` — soon-to-be removed (Keep a Changelog only)
- `### Security` — vulnerability fixes (Keep a Changelog only)

Only include categories that have entries.

## Writing Changes

- One line per change, brief and scannable
- Use imperative mood: "Add", "Fix", "Remove", "Change", "Bump"
- Must be self-describing without relying on category heading
- Prefix breaking changes: `**Breaking:** change description`
- Breaking changes listed first within their category

### References and Authors

Format: `- Change description (#PR) (Author Name)`

- Reference PRs/commits in parentheses after the change
- Prefer PR over commit ref when both exist
- Omit author if single contributor to the project
- Use short commit hashes when referencing commits: `` [`53bd922`](url) ``

## What to Include

- User-facing features and bug fixes
- Refactorings (risk of side effects)
- Runtime environment changes
- Dependency bumps with version ranges: "Bump X from 1.x to 2.x"

## What to Exclude

- Dotfile changes (.gitignore, .github, CI config)
- Dev-only dependency updates
- Minor code style changes
- Documentation formatting
- Changes that negate each other (add then revert)

## Maintenance

- Merge related changes across commits into one entry
- Merge fixups with their main change
- Don't copy commit messages verbatim — curate for human readers
- When releasing, move Unreleased items into a new version section
