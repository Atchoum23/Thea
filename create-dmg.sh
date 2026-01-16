#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# Thea DMG Creation Script
# ═══════════════════════════════════════════════════════════════════════════════
# 
# USAGE:
#   ./create-dmg.sh                     # Interactive mode (prompts for phase)
#   ./create-dmg.sh "Phase6-UIFoundation"  # Specify phase description
#   ./create-dmg.sh --help              # Show help
#
# NAMING CONVENTION:
#   Thea-v{VERSION}-{PHASE_DESCRIPTION}.dmg
#
# EXAMPLES:
#   Thea-v1.0.0-Bootstrap-Phase1-4.dmg
#   Thea-v1.1.0-SelfExecution-Phase5.dmg
#   Thea-v1.1.1-Phase5-Fixed.dmg
#   Thea-v1.2.0-UIFoundation-Phase6.dmg
#
# ═══════════════════════════════════════════════════════════════════════════════

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

PROJECT_DIR="/Users/alexis/Documents/IT & Tech/MyApps/Thea/Development"
DMG_OUTPUT_DIR="$PROJECT_DIR/macOS/DMG files"
INFO_PLIST="$PROJECT_DIR/Shared/Resources/Info.plist"

# ═══════════════════════════════════════════════════════════════════════════════
# HELP
# ═══════════════════════════════════════════════════════════════════════════════

show_help() {
    echo "═══════════════════════════════════════════════════════════════════════"
    echo "  Thea DMG Creation Script"
    echo "═══════════════════════════════════════════════════════════════════════"
    echo ""
    echo "USAGE:"
    echo "  ./create-dmg.sh                          Interactive mode"
    echo "  ./create-dmg.sh \"Phase6-UIFoundation\"    Specify phase description"
    echo "  ./create-dmg.sh --help                   Show this help"
    echo ""
    echo "NAMING CONVENTION:"
    echo "  Thea-v{VERSION}-{PHASE_DESCRIPTION}.dmg"
    echo ""
    echo "PHASE DESCRIPTIONS:"
    echo "  Phase 1-4:  Bootstrap-Phase1-4"
    echo "  Phase 5:    SelfExecution-Phase5"
    echo "  Phase 6:    UIFoundation-Phase6"
    echo "  Phase 7:    PowerManagement-Phase7"
    echo "  Phase 8:    AlwaysOn-Phase8"
    echo "  Phase 9:    CrossDevice-Phase9"
    echo "  Phase 10:   AppIntegration-Phase10"
    echo "  Phase 11:   MCPBuilder-Phase11"
    echo "  Phase 12:   Integrations-Phase12"
    echo "  Phase 13:   Testing-Phase13"
    echo "  Phase 14:   Documentation-Phase14"
    echo "  Phase 15:   Production"
    echo ""
    echo "  For bug fixes, append: -Fixed or -Hotfix"
    echo "  Example: Phase5-Fixed"
    echo ""
    exit 0
}

if [ "$1" == "--help" ] || [ "$1" == "-h" ]; then
    show_help
fi

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 0: PRE-FLIGHT CHECKS
# ═══════════════════════════════════════════════════════════════════════════════

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Thea DMG Creation - Pre-flight Checks${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════════════${NC}"
echo ""

cd "$PROJECT_DIR"

# Check Info.plist exists
if [ ! -f "$INFO_PLIST" ]; then
    echo -e "${RED}ERROR: Info.plist not found at $INFO_PLIST${NC}"
    exit 1
fi

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 1: VERSION VERIFICATION (CRITICAL!)
# ═══════════════════════════════════════════════════════════════════════════════
# ⚠️ Versions are BAKED INTO THE BINARY at compile time!
# ⚠️ You MUST update Info.plist BEFORE building!

echo -e "${YELLOW}STEP 1: VERSION VERIFICATION${NC}"
echo ""

# Read current version from project.yml (XcodeGen)
PLIST_VERSION=$(grep "MARKETING_VERSION:" "$PROJECT_DIR/project.yml" | awk '{print $2}' | tr -d '"')
PLIST_BUILD=$(grep "CURRENT_PROJECT_VERSION:" "$PROJECT_DIR/project.yml" | awk '{print $2}' | tr -d '"')

echo "Current project.yml version: $PLIST_VERSION (build: $PLIST_BUILD)"
echo ""

# Prompt user to enter desired version
echo -e "${YELLOW}⚠️  CRITICAL: Version must be set BEFORE building!${NC}"
echo ""
read -p "Enter version to build (or press Enter to use $PLIST_VERSION): " new_version

# If user provided a version, use it; otherwise use current
if [ -n "$new_version" ]; then
    # Update project.yml with new version (XcodeGen)
    echo "Updating project.yml to version $new_version..."
    sed -i '' "s/MARKETING_VERSION: \"[^\"]*\"/MARKETING_VERSION: \"$new_version\"/g" "$PROJECT_DIR/project.yml"
    sed -i '' "s/CURRENT_PROJECT_VERSION: \"[^\"]*\"/CURRENT_PROJECT_VERSION: \"$new_version\"/g" "$PROJECT_DIR/project.yml"

    VERSION="$new_version"
    echo -e "${GREEN}✓ Version updated to $new_version in project.yml${NC}"

    # Regenerate Xcode project from project.yml
    echo "→ Regenerating Xcode project with xcodegen..."
    xcodegen generate
    echo -e "${GREEN}✓ Xcode project regenerated${NC}"
    echo ""
else
    VERSION="$PLIST_VERSION"
    echo "Using current version: $VERSION"
    echo ""
fi

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 2: GET PHASE DESCRIPTION
# ═══════════════════════════════════════════════════════════════════════════════

echo -e "${YELLOW}STEP 2: PHASE DESCRIPTION${NC}"
echo ""

if [ -n "$1" ] && [ "$1" != "--help" ] && [ "$1" != "-h" ]; then
    PHASE_DESC="$1"
    echo "Using provided phase description: $PHASE_DESC"
else
    echo "Phase description examples:"
    echo "  - Bootstrap-Phase1-4"
    echo "  - SelfExecution-Phase5"
    echo "  - UIFoundation-Phase6"
    echo "  - Phase5-Fixed (for bug fixes)"
    echo ""
    read -p "Enter phase description: " PHASE_DESC
    
    if [ -z "$PHASE_DESC" ]; then
        echo -e "${RED}ERROR: Phase description cannot be empty${NC}"
        exit 1
    fi
fi

# Construct DMG name following convention: Thea-v{VERSION}-{PHASE_DESCRIPTION}.dmg
DMG_NAME="Thea-v${VERSION}-${PHASE_DESC}.dmg"
DMG_PATH="$DMG_OUTPUT_DIR/$DMG_NAME"

echo ""
echo -e "${GREEN}DMG will be named: $DMG_NAME${NC}"
echo ""

# Check if DMG already exists
if [ -f "$DMG_PATH" ]; then
    echo -e "${YELLOW}WARNING: DMG already exists at:${NC}"
    echo "  $DMG_PATH"
    read -p "Overwrite? (y/n): " overwrite
    if [ "$overwrite" != "y" ] && [ "$overwrite" != "Y" ]; then
        echo "Aborted."
        exit 0
    fi
    rm -f "$DMG_PATH"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 3: CLEAN BUILD
# ═══════════════════════════════════════════════════════════════════════════════

echo -e "${YELLOW}STEP 3: CLEAN BUILD${NC}"
echo ""
echo "→ Cleaning build directories..."

rm -rf "$PROJECT_DIR/build/"
rm -rf ~/Library/Developer/Xcode/DerivedData/Thea-*

echo -e "${GREEN}✓ Build directories cleaned${NC}"
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 4: BUILD RELEASE
# ═══════════════════════════════════════════════════════════════════════════════

echo -e "${YELLOW}STEP 4: BUILD RELEASE${NC}"
echo ""
echo "→ Building Release configuration..."
echo ""

xcodebuild -project Thea.xcodeproj \
           -scheme Thea-macOS \
           -configuration Release \
           -derivedDataPath build \
           clean build \
           CODE_SIGN_IDENTITY="" \
           CODE_SIGNING_REQUIRED=NO \
           CODE_SIGNING_ALLOWED=NO

APP_PATH="$PROJECT_DIR/build/Build/Products/Release/Thea.app"

if [ ! -d "$APP_PATH" ]; then
    echo -e "${RED}ERROR: Build failed - Thea.app not found at $APP_PATH${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}✓ Build completed${NC}"
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 5: VERIFY VERSION IN BUILT APP (CRITICAL!)
# ═══════════════════════════════════════════════════════════════════════════════

echo -e "${YELLOW}STEP 5: VERIFY VERSION IN BUILT APP${NC}"
echo ""

BUILT_VERSION=$(defaults read "$APP_PATH/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "UNKNOWN")

echo "Expected version: $VERSION"
echo "Built app version: $BUILT_VERSION"
echo ""

if [ "$BUILT_VERSION" != "$VERSION" ]; then
    echo -e "${RED}═══════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${RED}  ❌ VERSION MISMATCH DETECTED!${NC}"
    echo -e "${RED}═══════════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "The built app has version '$BUILT_VERSION' but you wanted '$VERSION'."
    echo ""
    echo "This happens when Info.plist was updated AFTER the app was built."
    echo "Versions are baked into the binary at compile time."
    echo ""
    echo "SOLUTION: Run this script again. It will:"
    echo "  1. Update Info.plist to '$VERSION'"
    echo "  2. Clean build directories"
    echo "  3. Rebuild with correct version"
    echo ""
    exit 1
fi

echo -e "${GREEN}✓ Version verified: $BUILT_VERSION${NC}"
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 6: CREATE DMG
# ═══════════════════════════════════════════════════════════════════════════════

echo -e "${YELLOW}STEP 6: CREATE DMG${NC}"
echo ""

# Create staging directory
echo "→ Creating DMG staging directory..."
rm -rf "$PROJECT_DIR/dmg-staging"
mkdir -p "$PROJECT_DIR/dmg-staging"

# Copy app
echo "→ Copying Thea.app to staging..."
cp -R "$APP_PATH" "$PROJECT_DIR/dmg-staging/"

# Create Applications symlink
echo "→ Creating Applications symlink..."
ln -s /Applications "$PROJECT_DIR/dmg-staging/Applications"

# Create DMG
echo "→ Creating DMG..."
mkdir -p "$DMG_OUTPUT_DIR"

hdiutil create \
    -volname "Thea-v${VERSION}" \
    -srcfolder "$PROJECT_DIR/dmg-staging" \
    -ov -format UDZO \
    -imagekey zlib-level=9 \
    "$DMG_PATH"

# Cleanup staging
rm -rf "$PROJECT_DIR/dmg-staging"

echo ""
echo -e "${GREEN}✓ DMG created${NC}"
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 7: FINAL VERIFICATION
# ═══════════════════════════════════════════════════════════════════════════════

echo -e "${YELLOW}STEP 7: FINAL VERIFICATION${NC}"
echo ""

# Mount and verify
echo "→ Mounting DMG to verify contents..."
hdiutil attach "$DMG_PATH" -quiet

MOUNTED_APP="/Volumes/Thea-v${VERSION}/Thea.app"
if [ -d "$MOUNTED_APP" ]; then
    FINAL_VERSION=$(defaults read "$MOUNTED_APP/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "UNKNOWN")
    echo "DMG contains Thea.app version: $FINAL_VERSION"
    
    if [ "$FINAL_VERSION" == "$VERSION" ]; then
        echo -e "${GREEN}✓ Version verification PASSED${NC}"
    else
        echo -e "${RED}✗ Version verification FAILED${NC}"
    fi
else
    echo -e "${RED}✗ Could not find Thea.app in mounted DMG${NC}"
fi

hdiutil detach "/Volumes/Thea-v${VERSION}" -quiet 2>/dev/null || true

echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# DONE
# ═══════════════════════════════════════════════════════════════════════════════

DMG_SIZE=$(du -h "$DMG_PATH" | cut -f1)

echo -e "${GREEN}═══════════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  ✅ DMG CREATED SUCCESSFULLY${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════════════════${NC}"
echo ""
echo "  File: $DMG_NAME"
echo "  Size: $DMG_SIZE"
echo "  Path: $DMG_PATH"
echo ""
echo "  Installation:"
echo "    1. Open $DMG_NAME"
echo "    2. Drag Thea to Applications folder"
echo "    3. Launch Thea from Applications"
echo ""
echo -e "${YELLOW}  Don't forget to update THEA_MASTER_SPEC.md:${NC}"
echo "    - Current Release: $DMG_NAME"
echo "    - Add to Previous Releases list"
echo ""
