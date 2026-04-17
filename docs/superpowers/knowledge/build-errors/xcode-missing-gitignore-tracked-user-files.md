## Root Cause

Missing `.gitignore` from project inception. The initial commit included Xcode user-specific files (`xcuserdata/` containing `UserInterfaceState.xcuserstate` and `xcschememanagement.plist`) that should never be version-controlled.

## Solution

1. **Create `.gitignore`** at the project root with entries for macOS system files, Xcode user data, build artifacts, debug symbols, and Swift Package Manager:

```
# macOS
.DS_Store
._*

# Xcode user data (window state, breakpoints, scheme ordering)
xcuserdata/

# Build artifacts — release builds via Makefile, not via git
DerivedData/
build/

# Debug symbols
*.dSYM
*.dSYM.zip

# Swift Package Manager
.build/
```

2. **Remove already-tracked files from the git index** (without deleting them from disk):

```bash
git rm -r --cached Epoch.xcodeproj/xcuserdata/ Epoch.xcodeproj/project.xcworkspace/xcuserdata/
```

3. **Commit both changes together** so the ignore rules and index removal are atomic.

## Key Insight

Adding a path to `.gitignore` only prevents *untracked* files from being staged in the future. It does **not** stop git from tracking files already in the index. To fully ignore previously committed files, you must first remove them from the index with `git rm -r --cached <path>`, then commit that removal alongside the `.gitignore` update.

## Decision: Ignore `build/`

Release builds should not live in git — they are large binaries that bloat the repo permanently. Produce them on demand via `make` or CI, and distribute via GitHub Releases or direct download.

## Prevention Strategies

- **Create `.gitignore` before first commit.** Use GitHub's standard templates (`github/gitignore/Swift.gitignore`) as a starting point.
- **Use `git rm --cached` to fix already-tracked files.** One-time fix: files remain on disk but stop being tracked.
- **Include `.xcodeproj` selectively.** Track `project.pbxproj` but ignore `xcuserdata/` within it.
- **Keep a personal boilerplate `.gitignore`.** Use `gibo dump Swift Xcode > .gitignore` so setup is a single command.

## Related Documentation

No existing related solutions. This is the first entry in `docs/superpowers/knowledge/`.
