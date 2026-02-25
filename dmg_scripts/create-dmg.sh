#!/bin/bash

# Configuration
APP_NAME="Maclipboard"
APP_DIR="build/${APP_NAME}.app"
DMG_NAME="${APP_NAME}.dmg"
DMG_DIR="build"
STAGE_DIR="build/dmg_stage"
BG_IMG="build/dmg_background.png"
VOL_ICON="build/rounded.icns"

if [ ! -d "$APP_DIR" ]; then
    echo "Error: App directory not found. Please build the app first with 'make app'."
    exit 1
fi

# Clean up any existing dmg
if [ -f "${DMG_DIR}/${DMG_NAME}" ]; then
    rm "${DMG_DIR}/${DMG_NAME}"
fi
rm -rf "${STAGE_DIR}"
mkdir -p "${STAGE_DIR}"

# Generate the background image with the arrow
echo "Generating background image..."
swift dmg_scripts/generate-dmg-bg.swift "${BG_IMG}"

# Generate the rounded volume icon
echo "Generating rounded volume icon..."
sips -s format png "${APP_DIR}/Contents/Resources/AppIcon.icns" --out build/icon.png
swift dmg_scripts/apply-radius.swift build/icon.png build/rounded_icon.png
sips -s format icns build/rounded_icon.png --out "${VOL_ICON}"

# Copy app to staging dir
cp -R "${APP_DIR}" "${STAGE_DIR}/"

# Generate proper Applications alias bookmark
echo "Creating Applications shortcut..."
swift dmg_scripts/make-alias.swift /Applications "${STAGE_DIR}/Applications"

# Create the DMG using create-dmg
echo "Creating ${DMG_NAME}..."

create-dmg \
  --volname "${APP_NAME} Installer" \
  --volicon "${VOL_ICON}" \
  --background "${BG_IMG}" \
  --window-pos 200 120 \
  --window-size 500 300 \
  --icon-size 100 \
  --icon "${APP_NAME}.app" 125 100 \
  --hide-extension "${APP_NAME}.app" \
  --icon "Applications" 375 100 \
  "${DMG_DIR}/${DMG_NAME}" \
  "${STAGE_DIR}/"

if [ $? -eq 0 ]; then
    echo "Successfully created ${DMG_DIR}/${DMG_NAME}"
    # Clean up intermediate files
    rm -f "${BG_IMG}"
    rm -f "build/icon.png"
    rm -f "build/rounded_icon.png"
    rm -f "${VOL_ICON}"
    rm -rf "${STAGE_DIR}"
else
    echo "Failed to create DMG. Ensure 'create-dmg' is installed (brew install create-dmg)."
    exit 1
fi
