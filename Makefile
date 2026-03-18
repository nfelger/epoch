BUILD_DIR = $(shell xcodebuild -project Epoch.xcodeproj -scheme Epoch -configuration Release -showBuildSettings 2>/dev/null | grep -m1 'BUILT_PRODUCTS_DIR' | awk '{print $$NF}')
APP = $(BUILD_DIR)/Epoch.app

.PHONY: build deploy

build:
	xcodebuild -project Epoch.xcodeproj -scheme Epoch -configuration Release build

deploy: build
	rm -rf /Applications/Epoch.app
	cp -r "$(APP)" /Applications/
	@echo "Installed to /Applications/Epoch.app"
