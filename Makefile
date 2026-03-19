BUILD_DIR = $(shell xcodebuild -project Epoch.xcodeproj -scheme Epoch -configuration Release -showBuildSettings 2>/dev/null | grep -m1 'BUILT_PRODUCTS_DIR' | awk '{print $$NF}')
APP = $(BUILD_DIR)/Epoch.app

APPICONSET = Epoch/Resources/Epoch.xcassets/AppIcon.appiconset

.PHONY: build build-debug deploy lint format test icon

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

deploy: build
	rm -rf /Applications/Epoch.app
	cp -r "$(APP)" /Applications/
	@echo "Installed to /Applications/Epoch.app"
