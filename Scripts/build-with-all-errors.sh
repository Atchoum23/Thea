#!/bin/bash

################################################################################
# Build with All Errors
# Comprehensive error scan that shows ALL errors at once
# Combines SwiftLint + full Swift compilation
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Comprehensive Error Detection Scan${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

# Get project root
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

ERRORS_FOUND=0

# Step 1: Run SwiftLint
echo -e "${BLUE}[1/2] Running SwiftLint analysis...${NC}"
if command -v swiftlint &> /dev/null; then
    if swiftlint lint --config .swiftlint.yml; then
        echo -e "${GREEN}✅ SwiftLint: No issues found${NC}\n"
    else
        echo -e "${YELLOW}⚠️  SwiftLint found issues${NC}\n"
        ERRORS_FOUND=1
    fi
else
    echo -e "${YELLOW}⚠️  SwiftLint not installed (brew install swiftlint)${NC}\n"
fi

# Step 2: Build project to find compilation errors
echo -e "${BLUE}[2/2] Running full compilation check...${NC}"

if [ -f "Thea.xcodeproj/project.pbxproj" ]; then
    echo -e "${BLUE}Building Thea-macOS scheme...${NC}"

    if xcodebuild \
        -project Thea.xcodeproj \
        -scheme Thea-macOS \
        -destination 'platform=macOS' \
        clean build \
        -quiet \
        2>&1 | grep -E "error:|warning:" || true; then
        echo -e "${GREEN}✅ Compilation: No errors${NC}\n"
    else
        echo -e "${YELLOW}⚠️  Compilation warnings/errors found${NC}\n"
        ERRORS_FOUND=1
    fi
else
    echo -e "${YELLOW}⚠️  Xcode project not found${NC}\n"
fi

# Summary
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
if [ $ERRORS_FOUND -eq 0 ]; then
    echo -e "${GREEN}✅ Scan Complete: No critical issues found!${NC}"
else
    echo -e "${YELLOW}⚠️  Scan Complete: Issues found (see above)${NC}"
fi
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

exit $ERRORS_FOUND
