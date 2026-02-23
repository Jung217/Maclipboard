APP_NAME = Maclipboard
BUNDLE_ID = com.user.Maclipboard
APP_DIR = build/$(APP_NAME).app
CONTENTS_DIR = $(APP_DIR)/Contents
MACOS_DIR = $(CONTENTS_DIR)/MacOS
RESOURCES_DIR = $(CONTENTS_DIR)/Resources

SWIFTC = swiftc
SWIFT_TARGET = arm64-apple-macos13.0
SWIFT_SOURCES = $(shell find Sources -name "*.swift")

all: app

app: $(APP_DIR)

$(APP_DIR): $(SWIFT_SOURCES) Info.plist
	@echo "Building $(APP_NAME) architecture arm64..."
	@mkdir -p $(MACOS_DIR)
	@mkdir -p $(RESOURCES_DIR)
	@cp Info.plist $(CONTENTS_DIR)/
	@if [ -f AppIcon.icns ]; then cp AppIcon.icns $(RESOURCES_DIR)/; fi
	$(SWIFTC) $(SWIFT_SOURCES) -target $(SWIFT_TARGET) -o $(MACOS_DIR)/$(APP_NAME)
	@codesign --force --deep --sign - $(APP_DIR)
	@echo "Build complete at $(APP_DIR)"

run: app
	@open $(APP_DIR)

clean:
	@rm -rf build

.PHONY: all app run clean
