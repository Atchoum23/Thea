#!/bin/bash

################################################################################
# Error Summary
# Quick statistical overview of code quality issues
################################################################################

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Get project root
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Code Quality Summary${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

# Count Swift files
SWIFT_FILES=$(find . -name "*.swift" -not -path "./build/*" -not -path "./.build/*" | wc -l | tr -d ' ')
echo -e "${BLUE}📄 Swift Files:${NC} $SWIFT_FILES"

# Run SwiftLint if available
if command -v swiftlint &> /dev/null; then
    echo -e "\n${BLUE}Running SwiftLint analysis...${NC}\n"

    # Capture SwiftLint output
    LINT_OUTPUT=$(swiftlint lint --config .swiftlint.yml --quiet 2>&1 || true)

    # Count violations
    ERRORS=$(echo "$LINT_OUTPUT" | grep -c "error:" || echo "0")
    WARNINGS=$(echo "$LINT_OUTPUT" | grep -c "warning:" || echo "0")

    echo -e "${RED}❌ Errors:${NC}   $ERRORS"
    echo -e "${YELLOW}⚠️  Warnings:${NC} $WARNINGS"

    # Show severity
    echo ""
    if [ "$ERRORS" -eq 0 ] && [ "$WARNINGS" -eq 0 ]; then
        echo -e "${GREEN}✅ Code Quality: Excellent${NC}"
    elif [ "$ERRORS" -eq 0 ] && [ "$WARNINGS" -lt 10 ]; then
        echo -e "${GREEN}✅ Code Quality: Good${NC}"
    elif [ "$ERRORS" -eq 0 ]; then
        echo -e "${YELLOW}⚠️  Code Quality: Fair (warnings present)${NC}"
    else
        echo -e "${RED}❌ Code Quality: Needs Attention (errors present)${NC}"
    fi
else
    echo -e "\n${YELLOW}⚠️  SwiftLint not installed${NC}"
    echo -e "${BLUE}Install with: brew install swiftlint${NC}"
fi

echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
