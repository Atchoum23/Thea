#!/bin/bash

set -e

echo "════════════════════════════════════════════════════════"
echo "  Building Thea for Release Distribution"
echo "════════════════════════════════════════════════════════"

PROJECT_DIR="/Users/alexis/Documents/IT & Tech/MyApps/Thea/Development"
cd "$PROJECT_DIR"

# Clean
echo "→ Cleaning build directory..."
rm -rf build/

# Build with Xcode
echo "→ Building Release configuration with Xcode..."
xcodebuild -project Thea.xcodeproj \
           -scheme Thea-macOS \
           -configuration Release \
           -derivedDataPath build \
           clean build \
           CODE_SIGN_IDENTITY="" \
           CODE_SIGNING_REQUIRED=NO \
           CODE_SIGNING_ALLOWED=NO

# Install to /Applications if requested
if [ "$1" == "--install" ]; then
    echo ""
    echo "→ Installing to /Applications..."
    sudo rm -rf /Applications/Thea.app
    sudo cp -R build/Release/Thea.app /Applications/
    echo "✓ Thea.app installed to /Applications"
else
    echo ""
    echo "✓ Release build complete!"
    echo "✓ App location: build/Release/Thea.app"
    echo ""
    echo "To install: sudo cp -R build/Release/Thea.app /Applications/"
    echo "Or run: ./build-release.sh --install"
fi

