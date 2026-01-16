#!/bin/bash

# ============================================
# Thea Project Configuration Validator
# ============================================
# This script validates that all required configuration
# files and settings are properly configured.
# ============================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
PASS=0
FAIL=0
WARN=0

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo ""
echo "============================================"
echo "  Thea Configuration Validator"
echo "============================================"
echo "Project Root: $PROJECT_ROOT"
echo ""

# Helper functions
pass() {
    echo -e "${GREEN}✓${NC} $1"
    PASS=$((PASS + 1))
}

fail() {
    echo -e "${RED}✗${NC} $1"
    FAIL=$((FAIL + 1))
}

warn() {
    echo -e "${YELLOW}⚠${NC} $1"
    WARN=$((WARN + 1))
}

info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

section() {
    echo ""
    echo -e "${BLUE}── $1 ──${NC}"
}

# ============================================
# CHECK 1: Required Files Exist
# ============================================
section "Checking Required Files"

# macOS Entitlements
if [ -f "$PROJECT_ROOT/macOS/Thea.entitlements" ]; then
    pass "macOS entitlements file exists"
else
    fail "macOS entitlements file missing: macOS/Thea.entitlements"
fi

# iOS Entitlements
if [ -f "$PROJECT_ROOT/iOS/Thea.entitlements" ]; then
    pass "iOS entitlements file exists"
else
    fail "iOS entitlements file missing: iOS/Thea.entitlements"
fi

# Shared Info.plist
if [ -f "$PROJECT_ROOT/Shared/Resources/Info.plist" ]; then
    pass "Shared Info.plist exists"
else
    fail "Shared Info.plist missing: Shared/Resources/Info.plist"
fi

# Xcode Project
if [ -f "$PROJECT_ROOT/Thea.xcodeproj/project.pbxproj" ]; then
    pass "Xcode project file exists"
else
    fail "Xcode project file missing"
fi

# ============================================
# CHECK 2: macOS Entitlements Content
# ============================================
section "Validating macOS Entitlements"

MACOS_ENT="$PROJECT_ROOT/macOS/Thea.entitlements"
if [ -f "$MACOS_ENT" ]; then
    # App Sandbox
    if grep -q "com.apple.security.app-sandbox" "$MACOS_ENT"; then
        pass "App Sandbox enabled"
    else
        fail "App Sandbox not configured"
    fi

    # Network Client
    if grep -q "com.apple.security.network.client" "$MACOS_ENT"; then
        pass "Network client access enabled"
    else
        fail "Network client access not enabled (required for AI providers)"
    fi

    # Microphone
    if grep -q "com.apple.security.device.audio-input" "$MACOS_ENT"; then
        pass "Microphone access enabled"
    else
        fail "Microphone access not enabled (required for voice features)"
    fi

    # Speech Recognition
    if grep -q "com.apple.security.personal-information.speech-recognition" "$MACOS_ENT"; then
        pass "Speech recognition enabled"
    else
        fail "Speech recognition not enabled"
    fi

    # Camera
    if grep -q "com.apple.security.device.camera" "$MACOS_ENT"; then
        pass "Camera access enabled"
    else
        warn "Camera access not enabled (optional for visual AI)"
    fi

    # Apple Events
    if grep -q "com.apple.security.automation.apple-events" "$MACOS_ENT"; then
        pass "Apple Events automation enabled"
    else
        warn "Apple Events not enabled (needed for app automation)"
    fi

    # JIT for MLX
    if grep -q "com.apple.security.cs.allow-jit" "$MACOS_ENT"; then
        pass "JIT compilation enabled (for local ML models)"
    else
        warn "JIT not enabled (may be needed for MLX models)"
    fi
fi

# ============================================
# CHECK 3: iOS Entitlements Content
# ============================================
section "Validating iOS Entitlements"

IOS_ENT="$PROJECT_ROOT/iOS/Thea.entitlements"
if [ -f "$IOS_ENT" ]; then
    # App Groups
    if grep -q "com.apple.security.application-groups" "$IOS_ENT"; then
        pass "App Groups configured"
    else
        fail "App Groups not configured (required for widgets)"
    fi

    # HealthKit
    if grep -q "com.apple.developer.healthkit" "$IOS_ENT"; then
        pass "HealthKit enabled"
    else
        warn "HealthKit not enabled"
    fi

    # Siri
    if grep -q "com.apple.developer.siri" "$IOS_ENT"; then
        pass "Siri integration enabled"
    else
        warn "Siri integration not enabled"
    fi

    # Push Notifications
    if grep -q "aps-environment" "$IOS_ENT"; then
        pass "Push notifications configured"
    else
        warn "Push notifications not configured"
    fi

    # iCloud
    if grep -q "com.apple.developer.icloud-services" "$IOS_ENT"; then
        pass "iCloud services enabled"
    else
        warn "iCloud services not enabled"
    fi
fi

# ============================================
# CHECK 4: Info.plist Privacy Descriptions
# ============================================
section "Validating Privacy Descriptions (Info.plist)"

INFO_PLIST="$PROJECT_ROOT/Shared/Resources/Info.plist"
if [ -f "$INFO_PLIST" ]; then
    # Required permissions
    if grep -q "NSMicrophoneUsageDescription" "$INFO_PLIST"; then
        pass "Microphone usage description present"
    else
        fail "Missing NSMicrophoneUsageDescription (required for voice)"
    fi

    if grep -q "NSSpeechRecognitionUsageDescription" "$INFO_PLIST"; then
        pass "Speech recognition usage description present"
    else
        fail "Missing NSSpeechRecognitionUsageDescription"
    fi

    if grep -q "NSCameraUsageDescription" "$INFO_PLIST"; then
        pass "Camera usage description present"
    else
        warn "Missing NSCameraUsageDescription"
    fi

    if grep -q "NSLocationWhenInUseUsageDescription" "$INFO_PLIST"; then
        pass "Location usage description present"
    else
        warn "Missing NSLocationWhenInUseUsageDescription"
    fi

    if grep -q "NSContactsUsageDescription" "$INFO_PLIST"; then
        pass "Contacts usage description present"
    else
        warn "Missing NSContactsUsageDescription"
    fi

    if grep -q "NSCalendarsUsageDescription" "$INFO_PLIST"; then
        pass "Calendar usage description present"
    else
        warn "Missing NSCalendarsUsageDescription"
    fi

    if grep -q "NSHealthShareUsageDescription" "$INFO_PLIST"; then
        pass "HealthKit share description present"
    else
        warn "Missing NSHealthShareUsageDescription"
    fi

    if grep -q "NSAppleEventsUsageDescription" "$INFO_PLIST"; then
        pass "Apple Events usage description present"
    else
        warn "Missing NSAppleEventsUsageDescription (macOS automation)"
    fi

    # App Category
    if grep -q "LSApplicationCategoryType" "$INFO_PLIST"; then
        pass "App category set in Info.plist"
    else
        info "App category not in Info.plist (may be in build settings)"
    fi
fi

# ============================================
# CHECK 5: Xcode Project Settings
# ============================================
section "Validating Xcode Project Settings"

PBXPROJ="$PROJECT_ROOT/Thea.xcodeproj/project.pbxproj"
if [ -f "$PBXPROJ" ]; then
    # App Category in build settings
    if grep -q "INFOPLIST_KEY_LSApplicationCategoryType" "$PBXPROJ"; then
        CATEGORY=$(grep "INFOPLIST_KEY_LSApplicationCategoryType" "$PBXPROJ" | head -1 | sed 's/.*= "\(.*\)";/\1/')
        pass "App category configured: $CATEGORY"
    else
        fail "App category not configured in build settings"
    fi

    # macOS entitlements reference
    if grep -q "CODE_SIGN_ENTITLEMENTS.*macOS/Thea.entitlements" "$PBXPROJ"; then
        pass "macOS entitlements referenced in project"
    else
        warn "macOS entitlements may not be referenced in project"
    fi

    # iOS entitlements reference
    if grep -q "CODE_SIGN_ENTITLEMENTS.*iOS/Thea.entitlements" "$PBXPROJ"; then
        pass "iOS entitlements referenced in project"
    else
        warn "iOS entitlements not referenced in project (needs manual setup)"
    fi

    # Bundle identifier (app.theathe.*)
    if grep -q "app.theathe" "$PBXPROJ"; then
        pass "Bundle identifier configured (app.theathe.*)"
    else
        warn "Bundle identifier may need configuration"
    fi

    # App Group identifier
    if grep -q "group.app.theathe" "$PROJECT_ROOT/iOS/Thea.entitlements" 2>/dev/null; then
        pass "App Group identifier correct (group.app.theathe)"
    else
        warn "App Group identifier may need configuration"
    fi

    # iCloud container identifier
    if grep -q "iCloud.app.theathe" "$PROJECT_ROOT/iOS/Thea.entitlements" 2>/dev/null; then
        pass "iCloud container identifier correct (iCloud.app.theathe)"
    else
        warn "iCloud container identifier may need configuration"
    fi
fi

# ============================================
# CHECK 6: XML/Plist Syntax Validation
# ============================================
section "Validating File Syntax"

# Validate plist files with plutil
validate_plist() {
    local file=$1
    local name=$2
    if [ -f "$file" ]; then
        if plutil -lint "$file" > /dev/null 2>&1; then
            pass "$name is valid XML/plist"
        else
            fail "$name has syntax errors"
            plutil -lint "$file" 2>&1 | head -5
        fi
    fi
}

validate_plist "$PROJECT_ROOT/macOS/Thea.entitlements" "macOS Entitlements"
validate_plist "$PROJECT_ROOT/iOS/Thea.entitlements" "iOS Entitlements"
validate_plist "$PROJECT_ROOT/Shared/Resources/Info.plist" "Info.plist"

# ============================================
# SUMMARY
# ============================================
echo ""
echo "============================================"
echo "  Validation Summary"
echo "============================================"
echo -e "${GREEN}Passed:${NC}   $PASS"
echo -e "${RED}Failed:${NC}   $FAIL"
echo -e "${YELLOW}Warnings:${NC} $WARN"
echo ""

if [ $FAIL -eq 0 ]; then
    echo -e "${GREEN}✓ All critical checks passed!${NC}"
    if [ $WARN -gt 0 ]; then
        echo -e "${YELLOW}  (Review warnings above for optional improvements)${NC}"
    fi
    exit 0
else
    echo -e "${RED}✗ Some checks failed. Please review the errors above.${NC}"
    exit 1
fi
