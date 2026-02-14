#!/bin/bash

################################################################################
# Auto Build Check Script
# Runs automatically during Xcode build phase
# Executes SwiftLint and other code quality checks
################################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔍 Running automatic error detection...${NC}"

# Get project root directory
if [ -n "$SRCROOT" ]; then
    PROJECT_ROOT="$SRCROOT"
else
    PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

cd "$PROJECT_ROOT"

# Check if SwiftLint is installed
if ! command -v swiftlint &> /dev/null; then
    echo -e "${YELLOW}⚠️  SwiftLint not found. Install with: brew install swiftlint${NC}"
    exit 0  # Don't fail the build, just warn
fi

# Run SwiftLint
echo -e "${BLUE}Running SwiftLint...${NC}"
if swiftlint lint --quiet --config .swiftlint.yml 2>&1; then
    echo -e "${GREEN}✅ Automatic checks passed${NC}"
    exit 0
else
    echo -e "${RED}❌ SwiftLint found issues${NC}"
    echo -e "${YELLOW}Run 'swiftlint' in terminal for details${NC}"
    exit 1  # Fail the build if there are errors
fi
