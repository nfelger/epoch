# Automating macOS Menubar App Releases with Make

## Problem

Releasing a macOS menubar app requires coordinating many steps: bump the version, stamp the changelog, regenerate the Xcode project, lint, test, build, zip, tag, and publish to GitHub. Doing these manually is error-prone and tedious.

## Solution

A single `make release VERSION=x.y.z` command that automates the entire pipeline.

### Design Decisions

- **Unsigned distribution** — No Apple Developer account needed. Users right-click → Open to bypass Gatekeeper. Suitable for personal/open-source projects.
- **Semantic versioning** — MAJOR.MINOR.PATCH (first release: v0.1.0).
- **project.yml as single source of truth** — XcodeGen generates Info.plist from it, so version is only edited in one place.
- **VERSION parameter is required** — No default bump logic; the caller specifies the exact version.
- **Zipped .app bundle** — Users unzip and drag to /Applications.

### The Release Target

```makefile
release:
ifndef VERSION
	$(error VERSION is required. Usage: make release VERSION=0.2.0)
endif
	@echo "==> Releasing v$(VERSION)..."
	# 1. Update version in project.yml
	sed -i '' 's/CFBundleShortVersionString: ".*"/CFBundleShortVersionString: "$(VERSION)"/' project.yml
	# 2. Increment build number
	$(eval CURRENT_BUILD := $(shell grep 'CFBundleVersion:' project.yml | head -1 | sed 's/.*"\(.*\)"/\1/'))
	sed -i '' 's/CFBundleVersion: "$(CURRENT_BUILD)"/CFBundleVersion: "$(shell echo $$(($(CURRENT_BUILD) + 1)))"/' project.yml
	# 3. Stamp changelog: [Unreleased] → [x.y.z] - date
	sed -i '' 's/## \[Unreleased\]/## [Unreleased]\n\n## [$(VERSION)] - $(shell date +%Y-%m-%d)/' CHANGELOG.md
	# 4. Regenerate Xcode project
	xcodegen
	# 5. Lint and test gate
	$(MAKE) lint
	$(MAKE) test
	# 6. Commit and tag
	git add project.yml Epoch.xcodeproj CHANGELOG.md
	git commit -m "release: v$(VERSION)"
	git tag "v$(VERSION)"
	# 7. Build
	$(MAKE) build
	# 8. Zip the .app bundle
	cd "$(BUILD_DIR)" && zip -r "$(CURDIR)/Epoch-$(VERSION).zip" Epoch.app
	# 9. Create GitHub release with changelog notes
	awk '/^## \[$(VERSION)\]/{flag=1; next} /^## \[/{flag=0} flag' CHANGELOG.md \
	  | gh release create "v$(VERSION)" "Epoch-$(VERSION).zip" --title "Epoch $(VERSION)" --notes-file -
	rm -f "Epoch-$(VERSION).zip"
	@echo "==> Released v$(VERSION) successfully!"
```

### How Each Step Works

**Version bump (steps 1-2):** `sed` replaces `CFBundleShortVersionString` with the given VERSION and increments `CFBundleVersion` by 1. Both live in `project.yml`.

**Changelog stamp (step 3):** Inserts a new dated section header after `[Unreleased]`, so existing entries under `[Unreleased]` become the release notes for the new version.

**XcodeGen (step 4):** Regenerates `Epoch.xcodeproj` from the updated `project.yml`, ensuring Info.plist reflects the new version.

**Quality gate (step 5):** SwiftLint (strict mode) and unit tests must pass. If either fails, the release aborts before any git operations.

**Changelog extraction (step 9):** `awk` extracts everything between the `## [x.y.z]` header and the next `## [` header, piping it as release notes to `gh release create`.

### Version Source of Truth

```yaml
# project.yml
info:
  properties:
    CFBundleShortVersionString: "0.1.0"  # Marketing version
    CFBundleVersion: "1"                  # Build number (auto-incremented)
```

XcodeGen writes these into Info.plist at project generation time. Never edit Info.plist directly for version fields.

## Prevention

1. **Never edit version in Info.plist directly** — Always edit `project.yml` and run `xcodegen`. Info.plist is generated.
2. **Always add changelog entries to `[Unreleased]`** — The release target stamps them automatically. If `[Unreleased]` is empty, the GitHub release notes will be empty.
3. **Lint and test run before the commit** — If they fail, no git operations happen. Fix issues and re-run.
4. **If a release fails mid-way** — Clean up with `git tag -d vX.Y.Z` and `git reset --soft HEAD~1`, then fix and retry.

## Related

- [Dev Workflow Tooling](swift-dev-workflow-xcodegen-lint-test.md) — Makefile targets for lint, format, test
- [Changelog Best Practices](changelog-best-practices.md) — Format conventions for CHANGELOG.md
- [macOS App Icon with XcodeGen](macos-app-icon-xcodegen-asset-catalog.md) — XcodeGen project.yml configuration patterns
