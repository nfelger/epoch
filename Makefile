BUILD_DIR = $(shell xcodebuild -project Epoch.xcodeproj -scheme Epoch -configuration Release -showBuildSettings 2>/dev/null | grep -m1 'BUILT_PRODUCTS_DIR' | awk '{print $$NF}')
APP = $(BUILD_DIR)/Epoch.app

APPICONSET = Epoch/Resources/Epoch.xcassets/AppIcon.appiconset

.PHONY: build build-debug deploy lint format test icon release

build:
	xcodebuild -project Epoch.xcodeproj -scheme Epoch -configuration Release build

build-debug:
	xcodebuild -project Epoch.xcodeproj -scheme Epoch -configuration Debug build

lint:
	swiftlint lint --strict Epoch/ EpochTests/

format:
	swiftformat Epoch/ EpochTests/

test:
	xcodebuild test -project Epoch.xcodeproj -scheme Epoch -destination 'platform=macOS'

icon:
	swift scripts/generate_icon.swift $(APPICONSET)/icon_512x512@2x.png
	sips -z 512 512 $(APPICONSET)/icon_512x512@2x.png --out $(APPICONSET)/icon_512x512.png
	sips -z 512 512 $(APPICONSET)/icon_512x512@2x.png --out $(APPICONSET)/icon_256x256@2x.png
	sips -z 256 256 $(APPICONSET)/icon_512x512@2x.png --out $(APPICONSET)/icon_256x256.png
	sips -z 256 256 $(APPICONSET)/icon_512x512@2x.png --out $(APPICONSET)/icon_128x128@2x.png
	sips -z 128 128 $(APPICONSET)/icon_512x512@2x.png --out $(APPICONSET)/icon_128x128.png
	sips -z 64 64 $(APPICONSET)/icon_512x512@2x.png --out $(APPICONSET)/icon_32x32@2x.png
	sips -z 32 32 $(APPICONSET)/icon_512x512@2x.png --out $(APPICONSET)/icon_32x32.png
	sips -z 32 32 $(APPICONSET)/icon_512x512@2x.png --out $(APPICONSET)/icon_16x16@2x.png
	sips -z 16 16 $(APPICONSET)/icon_512x512@2x.png --out $(APPICONSET)/icon_16x16.png

release:
ifndef VERSION
	$(error VERSION is required. Usage: make release VERSION=0.2.0)
endif
	@echo "==> Releasing v$(VERSION)..."
	@# 1. Update version in project.yml
	sed -i '' 's/CFBundleShortVersionString: ".*"/CFBundleShortVersionString: "$(VERSION)"/' project.yml
	@# 2. Increment build number
	$(eval CURRENT_BUILD := $(shell grep 'CFBundleVersion:' project.yml | head -1 | sed 's/.*"\(.*\)"/\1/'))
	sed -i '' 's/CFBundleVersion: "$(CURRENT_BUILD)"/CFBundleVersion: "$(shell echo $$(($(CURRENT_BUILD) + 1)))"/' project.yml
	@# 3. Stamp changelog
	sed -i '' 's/## \[Unreleased\]/## [Unreleased]\n\n## [$(VERSION)] - $(shell date +%Y-%m-%d)/' CHANGELOG.md
	@# 4. Regenerate Xcode project
	xcodegen
	@# 5. Lint and test
	$(MAKE) lint
	$(MAKE) test
	@# 6. Commit, tag
	git add project.yml Epoch.xcodeproj CHANGELOG.md
	git commit -m "release: v$(VERSION)"
	git tag "v$(VERSION)"
	@# 7. Build
	$(MAKE) build
	@# 8. Zip
	cd "$(BUILD_DIR)" && zip -r "$(CURDIR)/Epoch-$(VERSION).zip" Epoch.app
	@# 9. Extract release notes from changelog and create GitHub release
	@echo "==> Creating GitHub release v$(VERSION)..."
	awk '/^## \[$(VERSION)\]/{flag=1; next} /^## \[/{flag=0} flag' CHANGELOG.md | gh release create "v$(VERSION)" "Epoch-$(VERSION).zip" --title "Epoch $(VERSION)" --notes-file -
	rm -f "Epoch-$(VERSION).zip"
	@echo "==> Released v$(VERSION) successfully!"

deploy: build
	rm -rf /Applications/Epoch.app
	cp -r "$(APP)" /Applications/
	@echo "Installed to /Applications/Epoch.app"
