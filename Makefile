BUILD_DIR = $(shell xcodebuild -project Epoch.xcodeproj -scheme Epoch -configuration Release -showBuildSettings 2>/dev/null | grep -m1 'BUILT_PRODUCTS_DIR' | awk '{print $$NF}')
APP = $(BUILD_DIR)/Epoch.app

.PHONY: build build-debug deploy lint format test

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

deploy: build
	rm -rf /Applications/Epoch.app
	cp -r "$(APP)" /Applications/
	@echo "Installed to /Applications/Epoch.app"
