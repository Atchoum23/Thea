#!/bin/bash

set -e

echo "════════════════════════════════════════════════════════"
echo "  Recreating Thea v1.1.1 Phase 5 Fixed DMG"
echo "════════════════════════════════════════════════════════"

PROJECT_DIR="/Users/alexis/Documents/IT & Tech/MyApps/Thea/Development"
cd "$PROJECT_DIR"

VERSION="1.1.1-Phase5-Fixed"
APP_PATH="build/Build/Products/Release/Thea.app"

# Verify the app exists
if [ ! -d "$APP_PATH" ]; then
    echo "❌ App not found at: $APP_PATH"
    echo "Please build first with: xcodebuild -scheme Thea-macOS -configuration Release -derivedDataPath build build"
    exit 1
fi

# Check version in the built app
BUILT_VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP_PATH/Contents/Info.plist")
echo "→ Built app version: $BUILT_VERSION"

if [ "$BUILT_VERSION" != "1.1.1" ]; then
    echo "⚠ Warning: App version is $BUILT_VERSION, expected 1.1.1"
fi

# Create DMG staging directory
echo "→ Creating DMG staging directory..."
rm -rf dmg-staging
mkdir -p dmg-staging

# Copy app to staging
echo "→ Copying Thea.app to staging..."
cp -R "$APP_PATH" dmg-staging/

# Create Applications symlink
echo "→ Creating Applications symlink..."
ln -s /Applications dmg-staging/Applications

# Create DMG
DMG_NAME="Thea-v${VERSION}.dmg"
DMG_PATH="macOS/DMG files/$DMG_NAME"
echo "→ Creating DMG: $DMG_NAME"

# Remove old DMG if exists
rm -f "$DMG_PATH"

# Create DMG
hdiutil create -volname "Thea $VERSION" \
               -srcfolder dmg-staging \
               -ov -format UDZO \
               -imagekey zlib-level=9 \
               "$DMG_PATH"

# Clean up
rm -rf dmg-staging

echo ""
echo "════════════════════════════════════════════════════════"
echo "✓ DMG recreated successfully!"
echo "  Location: $DMG_PATH"
echo "  Version in app: $BUILT_VERSION"
echo "════════════════════════════════════════════════════════"
