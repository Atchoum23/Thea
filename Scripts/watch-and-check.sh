#!/bin/bash

################################################################################
# Watch and Check
# Continuously monitors Swift files and runs checks when they change
# Requires: fswatch (brew install fswatch)
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
echo -e "${BLUE}  File Watcher Started${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

# Check if fswatch is installed
if ! command -v fswatch &> /dev/null; then
    echo -e "${RED}❌ fswatch not found${NC}"
    echo -e "${YELLOW}Install with: brew install fswatch${NC}\n"
    exit 1
fi

echo -e "${GREEN}✅ Watching Swift files for changes...${NC}"
echo -e "${BLUE}Press Ctrl+C to stop${NC}\n"

# Watch for changes in Swift files
fswatch -0 -r --exclude "build/" --exclude ".build/" -e ".*" -i "\\.swift$" . | while read -d "" event; do
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}📝 File changed: $(basename "$event")${NC}"
    echo -e "${BLUE}$(date '+%H:%M:%S')${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

    # Run quick SwiftLint check on the changed file
    if command -v swiftlint &> /dev/null; then
        swiftlint lint --quiet --path "$event" 2>&1 || true
    fi

    echo ""
done
