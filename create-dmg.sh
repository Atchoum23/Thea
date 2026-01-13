#!/bin/bash

set -e

echo "════════════════════════════════════════════════════════"
echo "  Creating Thea DMG Installer"
echo "════════════════════════════════════════════════════════"

PROJECT_DIR="/Users/alexis/Documents/IT & Tech/MyApps/Thea/Development"
cd "$PROJECT_DIR"

# Get version from Info.plist
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "Shared/Resources/Info.plist")
BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "Shared/Resources/Info.plist")

echo "Version: $VERSION"
echo "Build: $BUILD"
echo ""

# Build Release with Xcode if not already built
APP_PATH="build/Release/Thea.app"
if [ ! -d "$APP_PATH" ]; then
    echo "→ Building Release configuration with Xcode..."
    xcodebuild -project Thea.xcodeproj \
               -scheme Thea-macOS \
               -configuration Release \
               -derivedDataPath build \
               clean build \
               CODE_SIGN_IDENTITY="" \
               CODE_SIGNING_REQUIRED=NO \
               CODE_SIGNING_ALLOWED=NO
    echo ""
fi

# Create DMG staging directory
echo "→ Creating DMG staging directory..."
rm -rf dmg-staging
mkdir -p dmg-staging

# Copy app to staging
echo "→ Copying Thea.app to staging..."
cp -R "$APP_PATH" dmg-staging/

# Create Applications symlink for easy drag-and-drop
echo "→ Creating Applications symlink..."
ln -s /Applications dmg-staging/Applications

# Create DMG
DMG_NAME="Thea-${VERSION}.dmg"
echo "→ Creating DMG: $DMG_NAME"

# Remove old DMG if exists
rm -f "$DMG_NAME"

# Create DMG with custom settings
hdiutil create -volname "Thea $VERSION" \
               -srcfolder dmg-staging \
               -ov -format UDZO \
               -imagekey zlib-level=9 \
               "$DMG_NAME"

# Clean up staging
rm -rf dmg-staging

echo ""
echo "════════════════════════════════════════════════════════"
echo "✓ DMG created successfully: $DMG_NAME"
echo "════════════════════════════════════════════════════════"
echo ""
echo "Installation:"
echo "  1. Open $DMG_NAME"
echo "  2. Drag Thea to Applications folder"
echo "  3. Launch Thea from Applications"
echo ""
