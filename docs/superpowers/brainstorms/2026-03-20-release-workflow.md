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
