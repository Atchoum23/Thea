#!/bin/bash
# Create DMG for Thea v1.3.0-MetaAI-Phase7
# Run this script from the Development directory

VERSION="1.3.0"
PHASE="MetaAI-Phase7"
DMG_NAME="Thea-v${VERSION}-${PHASE}.dmg"
DMG_DIR="macOS/DMG files"

echo "=== Building Thea v${VERSION} Release ==="

# Clean build directory
rm -rf ./build
rm -rf ~/Library/Developer/Xcode/DerivedData/Thea-*

# Remove extended attributes (ignore errors for missing files)
xattr -cr . 2>/dev/null || true

# Update project from project.yml (if XcodeGen is installed)
if command -v xcodegen &> /dev/null; then
    echo "Running XcodeGen..."
    xcodegen generate
    if [ $? -ne 0 ]; then
        echo "ERROR: XcodeGen failed"
        exit 1
    fi
else
    echo "XcodeGen not found, using existing .xcodeproj"
fi

# Build Release
echo "Building Release..."
xcodebuild \
    -scheme "Thea-macOS" \
    -configuration Release \
    -derivedDataPath ./build \
    clean build \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO

BUILD_RESULT=$?
if [ $BUILD_RESULT -ne 0 ]; then
    echo "ERROR: xcodebuild failed with exit code $BUILD_RESULT"
    exit 1
fi

# Check if build succeeded
APP_PATH="./build/Build/Products/Release/Thea.app"
if [ ! -d "$APP_PATH" ]; then
    echo "ERROR: Build failed - Thea.app not found at $APP_PATH"
    exit 1
fi

echo "Build successful!"

# Create DMG directory if it doesn't exist
mkdir -p "$DMG_DIR"

# Remove old DMG if exists
DMG_PATH="$DMG_DIR/$DMG_NAME"
if [ -f "$DMG_PATH" ]; then
    echo "Removing existing DMG..."
    rm "$DMG_PATH"
fi

# Create DMG
echo "Creating DMG: $DMG_NAME"
hdiutil create \
    -volname "Thea-v${VERSION}" \
    -srcfolder "$APP_PATH" \
    -format UDZO \
    -fs HFS+ \
    "$DMG_PATH"

echo ""
echo "=== DMG Created Successfully ==="
echo "Location: $DMG_PATH"
echo "Size: $(du -h "$DMG_PATH" | cut -f1)"
echo ""
