#!/bin/bash
#
# Thea macOS Distribution Script
# Signs, packages, and notarizes Thea.app for distribution
#
# Usage: ./build-and-notarize.sh [--skip-build]
#

set -e

# Configuration
APP_NAME="Thea"
BUNDLE_ID="app.thea.macos"
TEAM_ID="6B66PM4JLK"
APPLE_ID="alexis@calevras.com"
# Create an app-specific password at https://appleid.apple.com/account/manage
# Store it in Keychain: xcrun notarytool store-credentials "notarytool-profile" --apple-id YOUR_EMAIL --team-id 6B66PM4JLK
NOTARYTOOL_PROFILE="notarytool-profile"

# Paths
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/Distribution"
DERIVED_DATA="$HOME/Library/Developer/Xcode/DerivedData"

# Signing identities
DEVELOPER_ID_APP="Developer ID Application: Alexis Calevras (6B66PM4JLK)"
DEVELOPER_ID_INSTALLER="Developer ID Installer: Alexis Calevras (6B66PM4JLK)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo_step() {
    echo -e "${GREEN}==>${NC} $1"
}

echo_warning() {
    echo -e "${YELLOW}Warning:${NC} $1"
}

echo_error() {
    echo -e "${RED}Error:${NC} $1"
}

# Parse arguments
SKIP_BUILD=false
for arg in "$@"; do
    case $arg in
        --skip-build)
            SKIP_BUILD=true
            shift
            ;;
    esac
done

# Create distribution directory
mkdir -p "$BUILD_DIR"

# Step 1: Build Release
if [ "$SKIP_BUILD" = false ]; then
    echo_step "Building Release configuration..."
    cd "$PROJECT_DIR"
    xcodebuild -project Thea.xcodeproj \
        -scheme Thea-macOS \
        -configuration Release \
        -allowProvisioningUpdates \
        clean build | tail -5

    if [ $? -ne 0 ]; then
        echo_error "Build failed!"
        exit 1
    fi
fi

# Find the built app
APP_PATH=$(find "$DERIVED_DATA" -name "Thea.app" -path "*/Release/*" -type d 2>/dev/null | head -1)

if [ -z "$APP_PATH" ]; then
    echo_error "Could not find Thea.app in DerivedData"
    exit 1
fi

echo_step "Found app at: $APP_PATH"

# Step 2: Copy to Distribution folder
echo_step "Copying to Distribution folder..."
rm -rf "$BUILD_DIR/$APP_NAME.app"
cp -R "$APP_PATH" "$BUILD_DIR/"

APP_PATH="$BUILD_DIR/$APP_NAME.app"

# Step 3: Sign with Developer ID
echo_step "Signing with Developer ID Application..."
codesign --deep --force --verify --verbose \
    --sign "$DEVELOPER_ID_APP" \
    --options runtime \
    "$APP_PATH"

# Verify signature
echo_step "Verifying signature..."
codesign --verify --verbose=2 "$APP_PATH"
spctl --assess --verbose=2 "$APP_PATH" || echo_warning "spctl check failed (expected before notarization)"

# Step 4: Create DMG (optional, comment out if you prefer .pkg only)
echo_step "Creating DMG..."
DMG_PATH="$BUILD_DIR/$APP_NAME.dmg"
rm -f "$DMG_PATH"
hdiutil create -volname "$APP_NAME" \
    -srcfolder "$APP_PATH" \
    -ov -format UDZO \
    "$DMG_PATH"

# Sign the DMG
codesign --force --sign "$DEVELOPER_ID_APP" "$DMG_PATH"

# Step 5: Create PKG
echo_step "Creating PKG installer..."
PKG_PATH="$BUILD_DIR/$APP_NAME.pkg"
rm -f "$PKG_PATH"
productbuild --component "$APP_PATH" /Applications \
    --sign "$DEVELOPER_ID_INSTALLER" \
    "$PKG_PATH"

# Step 6: Notarize
echo_step "Submitting for notarization..."
echo "This may take several minutes..."

# Check if credentials are stored
if ! xcrun notarytool history --keychain-profile "$NOTARYTOOL_PROFILE" &>/dev/null; then
    echo_warning "Notarytool profile not found. Setting up credentials..."
    echo "Please enter your Apple ID password (app-specific password):"
    xcrun notarytool store-credentials "$NOTARYTOOL_PROFILE" \
        --apple-id "$APPLE_ID" \
        --team-id "$TEAM_ID"
fi

# Notarize the PKG
xcrun notarytool submit "$PKG_PATH" \
    --keychain-profile "$NOTARYTOOL_PROFILE" \
    --wait

# Notarize the DMG
xcrun notarytool submit "$DMG_PATH" \
    --keychain-profile "$NOTARYTOOL_PROFILE" \
    --wait

# Step 7: Staple the notarization ticket
echo_step "Stapling notarization ticket..."
xcrun stapler staple "$PKG_PATH"
xcrun stapler staple "$DMG_PATH"

# Verify final result
echo_step "Final verification..."
spctl --assess --verbose=2 "$APP_PATH"
spctl --assess --type install --verbose=2 "$PKG_PATH"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Distribution files ready:${NC}"
echo -e "  App: $APP_PATH"
echo -e "  DMG: $DMG_PATH"
echo -e "  PKG: $PKG_PATH"
echo -e "${GREEN}========================================${NC}"
