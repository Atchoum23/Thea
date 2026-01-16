#!/bin/bash

################################################################################
# Basic Setup Script
# Simpler alternative to install-automatic-checks.sh
# Just makes scripts executable and checks prerequisites
################################################################################

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Basic Setup${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

# Make scripts executable
echo -e "${BLUE}Making scripts executable...${NC}"
chmod +x Scripts/*.sh Scripts/pre-commit
chmod +x install-automatic-checks.sh setup.sh
echo -e "${GREEN}✅ Scripts are executable${NC}\n"

# Check prerequisites
echo -e "${BLUE}Checking prerequisites...${NC}\n"

# Check Homebrew
if command -v brew &> /dev/null; then
    echo -e "${GREEN}✅ Homebrew${NC} ($(brew --version | head -1))"
else
    echo -e "${YELLOW}⚠️  Homebrew not installed${NC}"
fi

# Check SwiftLint
if command -v swiftlint &> /dev/null; then
    echo -e "${GREEN}✅ SwiftLint${NC} ($(swiftlint version))"
else
    echo -e "${YELLOW}⚠️  SwiftLint not installed - run: brew install swiftlint${NC}"
fi

# Check fswatch
if command -v fswatch &> /dev/null; then
    echo -e "${GREEN}✅ fswatch${NC}"
else
    echo -e "${YELLOW}⚠️  fswatch not installed (optional) - run: brew install fswatch${NC}"
fi

# Check Xcode
if command -v xcodebuild &> /dev/null; then
    echo -e "${GREEN}✅ Xcode${NC} ($(xcodebuild -version | head -1))"
else
    echo -e "${YELLOW}⚠️  Xcode not found${NC}"
fi

echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Setup complete!${NC}\n"
echo -e "${BLUE}Next steps:${NC}"
echo -e "  ${GREEN}→${NC} Run full installer: ${YELLOW}./install-automatic-checks.sh${NC}"
echo -e "  ${GREEN}→${NC} Or see: ${YELLOW}START-HERE.md${NC}\n"
