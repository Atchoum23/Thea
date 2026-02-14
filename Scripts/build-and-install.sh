#!/bin/bash
# Build and Install Thea.app to /Applications

set -e

echo "🔨 Building Thea.app..."
echo "========================"

THEA_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$THEA_DIR"

# Clean previous builds
rm -rf build/DerivedData

# Build release version
xcodebuild -project Thea.xcodeproj \
    -scheme Thea-macOS \
    -configuration Release \
    -destination 'platform=macOS' \
    -derivedDataPath build/DerivedData \
    build 2>&1 | tail -30

# Check if build succeeded
APP_PATH="build/DerivedData/Build/Products/Release/Thea.app"
if [ -d "$APP_PATH" ]; then
    echo ""
    echo "✅ Build successful!"
    echo ""
    echo "📦 Installing to /Applications..."

    # Remove old version if exists
    if [ -d "/Applications/Thea.app" ]; then
        rm -rf "/Applications/Thea.app"
    fi

    # Copy new version
    cp -R "$APP_PATH" /Applications/

    echo "✅ Thea.app installed to /Applications"
    echo ""
    echo "🎉 Mission Complete!"
    echo "==================="
    echo "Run 'open -a Thea' to launch the app!"
else
    echo ""
    echo "❌ Build failed - Thea.app not found at $APP_PATH"
    echo "Check the build output above for errors."
    exit 1
fi
