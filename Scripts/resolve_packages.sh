#!/bin/bash

################################################################################
# Swift Package Manager Dependency Resolution Script
#
# Purpose: Clean and resolve Swift Package Manager dependencies for Thea project
# Usage: ./resolve_packages.sh
#
# This script is idempotent - safe to run multiple times without side effects.
# It performs a complete clean of SPM caches and forces fresh dependency resolution.
################################################################################

set -e  # Exit on any error
set -u  # Exit on undefined variable

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Project configuration
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_FILE="${PROJECT_DIR}/Thea.xcodeproj"
WORKSPACE_FILE="${PROJECT_DIR}/Thea.xcworkspace"
SCHEME_NAME="Thea-macOS"

# Cache and build directories
SPM_CACHE_DIR="${HOME}/Library/Caches/org.swift.swiftpm"
DERIVED_DATA_DIR="${HOME}/Library/Developer/Xcode/DerivedData"
BUILD_DIR="${PROJECT_DIR}/build"

# Xcode stores Package.resolved inside .xcodeproj/project.xcworkspace/xcshareddata/swiftpm/
PACKAGE_RESOLVED_DIR="${PROJECT_FILE}/project.xcworkspace/xcshareddata/swiftpm"
PACKAGE_RESOLVED="${PACKAGE_RESOLVED_DIR}/Package.resolved"

################################################################################
# Helper Functions
################################################################################

print_header() {
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

print_step() {
    echo -e "${GREEN}▶${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

################################################################################
# Main Script
################################################################################

print_header "Swift Package Manager Dependency Resolution"

# Step 1: Verify project exists
print_step "Verifying project structure..."
if [ ! -d "$PROJECT_FILE" ]; then
    print_error "Project file not found: $PROJECT_FILE"
    exit 1
fi
print_success "Project file found"

# Step 2: Clean SPM cache
print_step "Cleaning Swift Package Manager cache..."
if [ -d "$SPM_CACHE_DIR" ]; then
    rm -rf "$SPM_CACHE_DIR"
    print_success "SPM cache cleared: $SPM_CACHE_DIR"
else
    print_warning "SPM cache directory not found (already clean)"
fi

# Step 3: Clean build directory
print_step "Cleaning local build directory..."
if [ -d "$BUILD_DIR" ]; then
    rm -rf "$BUILD_DIR"
    print_success "Build directory removed: $BUILD_DIR"
else
    print_warning "Build directory not found (already clean)"
fi

# Step 4: Clean DerivedData for this project
print_step "Cleaning Xcode DerivedData..."
if [ -d "$DERIVED_DATA_DIR" ]; then
    # Find and remove DerivedData for Thea project specifically
    find "$DERIVED_DATA_DIR" -name "Thea-*" -type d -exec rm -rf {} + 2>/dev/null || true
    print_success "DerivedData cleaned for Thea project"
else
    print_warning "DerivedData directory not found"
fi

# Step 5: Remove Package.resolved (optional - force fresh resolution)
print_step "Removing Package.resolved to force fresh resolution..."

# Ensure the swiftpm directory exists
mkdir -p "$PACKAGE_RESOLVED_DIR"

if [ -f "$PACKAGE_RESOLVED" ]; then
    # Backup the current Package.resolved
    cp "$PACKAGE_RESOLVED" "${PACKAGE_RESOLVED}.backup"
    print_success "Backed up Package.resolved to $(basename $PACKAGE_RESOLVED_DIR)/Package.resolved.backup"

    rm "$PACKAGE_RESOLVED"
    print_success "Removed Package.resolved"
else
    print_warning "Package.resolved not found at expected location"
    print_warning "Location: ${PACKAGE_RESOLVED_DIR}"
fi

# Step 6: Resolve packages using xcodebuild
print_header "Resolving Swift Package Dependencies"

print_step "Running xcodebuild -resolvePackageDependencies..."

# Check if workspace exists, use it; otherwise use project
if [ -d "$WORKSPACE_FILE" ]; then
    print_step "Using workspace: Thea.xcworkspace"
    # Resolve packages
    if xcodebuild -workspace "$WORKSPACE_FILE" \
        -scheme "$SCHEME_NAME" \
        -resolvePackageDependencies \
        -derivedDataPath "$BUILD_DIR" \
        2>&1 | tee /tmp/thea_resolve.log; then
        RESOLUTION_SUCCESS=true
    else
        RESOLUTION_SUCCESS=false
    fi
else
    print_step "Using project: Thea.xcodeproj"
    # Resolve packages
    if xcodebuild -project "$PROJECT_FILE" \
        -scheme "$SCHEME_NAME" \
        -resolvePackageDependencies \
        -derivedDataPath "$BUILD_DIR" \
        2>&1 | tee /tmp/thea_resolve.log; then
        RESOLUTION_SUCCESS=true
    else
        RESOLUTION_SUCCESS=false
    fi
fi

if [ "$RESOLUTION_SUCCESS" = true ]; then

    print_success "Package resolution completed successfully"
else
    print_error "Package resolution failed"
    print_error "Check log file: /tmp/thea_resolve.log"
    exit 1
fi

# Step 7: Verify Package.resolved was created
print_step "Verifying Package.resolved creation..."
if [ -f "$PACKAGE_RESOLVED" ]; then
    print_success "Package.resolved created successfully"
    print_step "Location: ${PACKAGE_RESOLVED_DIR}"

    # Create convenience symlink at project root
    SYMLINK_PATH="${PROJECT_DIR}/Package.resolved"
    if [ -L "$SYMLINK_PATH" ]; then
        rm "$SYMLINK_PATH"
    fi
    ln -s "$PACKAGE_RESOLVED" "$SYMLINK_PATH"
    print_success "Created symlink: ./Package.resolved → xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"

    # Display resolved packages
    echo -e "\n${BLUE}Resolved Packages:${NC}"
    if command -v jq &> /dev/null; then
        # Pretty print with jq if available
        jq -r '.pins[] | "  • \(.identity) @ \(.state.version // .state.revision[0:8])"' "$PACKAGE_RESOLVED"
    else
        # Fallback: basic grep
        grep -o '"identity" : "[^"]*"' "$PACKAGE_RESOLVED" | sed 's/"identity" : "//;s/"$//' | sed 's/^/  • /'
    fi
else
    print_error "Package.resolved was not created at expected location"
    print_error "Expected: $PACKAGE_RESOLVED"
    print_step "Searching for Package.resolved in build directory..."

    FOUND_RESOLVED=$(find "$BUILD_DIR" -name "Package.resolved" -not -path "*/checkouts/*" 2>/dev/null | head -1)
    if [ -n "$FOUND_RESOLVED" ]; then
        print_warning "Found at: $FOUND_RESOLVED"
        print_step "Copying to correct location..."
        mkdir -p "$PACKAGE_RESOLVED_DIR"
        cp "$FOUND_RESOLVED" "$PACKAGE_RESOLVED"
        print_success "Package.resolved copied to correct location"
    else
        print_error "Package.resolved not found - resolution may have failed"
        exit 1
    fi
fi

# Step 8: List package products
print_header "Package Information"

print_step "Analyzing resolved packages..."
echo -e "\n${BLUE}Package Details:${NC}"

if command -v jq &> /dev/null; then
    jq -r '.pins[] | "  📦 \(.identity)\n     URL: \(.location)\n     Version: \(.state.version // "branch/commit")\n     Revision: \(.state.revision[0:12])\n"' "$PACKAGE_RESOLVED"
else
    print_warning "Install jq for detailed package information (brew install jq)"
fi

# Step 9: Verify dependencies are available
print_header "Verification"

print_step "Checking if packages are cached..."
PACKAGES_DIR="${BUILD_DIR}/SourcePackages/checkouts"
if [ -d "$PACKAGES_DIR" ]; then
    PACKAGE_COUNT=$(find "$PACKAGES_DIR" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')
    print_success "Found $PACKAGE_COUNT package(s) in checkouts directory"

    echo -e "\n${BLUE}Checked out packages:${NC}"
    find "$PACKAGES_DIR" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sed 's/^/  ✓ /'
else
    print_warning "Packages directory not found - packages will be resolved on first build"
fi

# Step 10: Final summary
print_header "Summary"

echo -e "${GREEN}✓ SPM cache cleaned${NC}"
echo -e "${GREEN}✓ Build directories cleaned${NC}"
echo -e "${GREEN}✓ Dependencies resolved${NC}"
echo -e "${GREEN}✓ Package.resolved created${NC}"

if [ -f "${PACKAGE_RESOLVED}.backup" ]; then
    echo -e "\n${YELLOW}Note: Previous Package.resolved backed up to Package.resolved.backup${NC}"
fi

print_success "All done! Dependencies are ready for building."

echo -e "\n${BLUE}Next steps:${NC}"
echo -e "  1. Open Thea.xcodeproj in Xcode"
echo -e "  2. Build the project (⌘B)"
echo -e "  3. Xcode will download and integrate the packages automatically"

echo -e "\n${BLUE}Troubleshooting:${NC}"
echo -e "  • If packages fail to integrate, try: Product → Clean Build Folder (⇧⌘K)"
echo -e "  • Check Xcode → Preferences → Accounts (ensure Apple ID is signed in)"
echo -e "  • View detailed logs: /tmp/thea_resolve.log"

exit 0
