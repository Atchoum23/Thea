#!/bin/bash
# Thea Build Verification Script
# Run this on your Mac to verify all phases compile correctly

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=========================================="
echo "  Thea Build Verification"
echo "=========================================="
echo ""

# Check for required tools
echo "Checking tools..."
command -v xcodegen >/dev/null 2>&1 || { echo "❌ xcodegen not found. Install with: brew install xcodegen"; exit 1; }
command -v xcodebuild >/dev/null 2>&1 || { echo "❌ xcodebuild not found. Install Xcode."; exit 1; }
echo "✅ All required tools found"
echo ""

# Generate Xcode project
echo "Generating Xcode project..."
xcodegen generate
echo "✅ Xcode project generated"
echo ""

# Build macOS target
echo "Building Thea-macOS..."
xcodebuild -scheme "Thea-macOS" -configuration Debug build 2>&1 | tee build_log.txt | grep -E "(error:|warning:|BUILD|Compiling)" | head -50

if grep -q "BUILD SUCCEEDED" build_log.txt; then
    echo ""
    echo "✅ BUILD SUCCEEDED"
    echo ""

    # Count warnings
    WARNINGS=$(grep -c "warning:" build_log.txt 2>/dev/null || echo "0")
    ERRORS=$(grep -c "error:" build_log.txt 2>/dev/null || echo "0")

    echo "Summary:"
    echo "  - Errors: $ERRORS"
    echo "  - Warnings: $WARNINGS"

    if [ "$ERRORS" -eq 0 ]; then
        echo ""
        echo "🎉 Thea Phases 1-7 verified successfully!"
    fi
else
    echo ""
    echo "❌ BUILD FAILED"
    echo ""
    echo "Errors:"
    grep "error:" build_log.txt | head -20
    exit 1
fi
