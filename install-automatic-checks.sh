#!/bin/bash

################################################################################
# Automatic Error Detection Installer
# One-command setup for comprehensive error detection
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

clear

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}  Automatic Error Detection System - Installer${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_ROOT"

# Step 1: Make scripts executable
echo -e "${BLUE}[1/7] Making scripts executable...${NC}"
chmod +x Scripts/*.sh Scripts/pre-commit
chmod +x install-automatic-checks.sh setup.sh 2>/dev/null || true
echo -e "${GREEN}✅ Scripts are now executable${NC}\n"

# Step 2: Check/Install Homebrew
echo -e "${BLUE}[2/7] Checking Homebrew...${NC}"
if ! command -v brew &> /dev/null; then
    echo -e "${YELLOW}⚠️  Homebrew not found${NC}"
    echo -e "${BLUE}Install Homebrew? (y/n)${NC} "
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    else
        echo -e "${YELLOW}Skipping Homebrew installation${NC}\n"
    fi
else
    echo -e "${GREEN}✅ Homebrew installed${NC}\n"
fi

# Step 3: Install SwiftLint
echo -e "${BLUE}[3/7] Checking SwiftLint...${NC}"
if ! command -v swiftlint &> /dev/null; then
    echo -e "${YELLOW}⚠️  SwiftLint not found${NC}"
    if command -v brew &> /dev/null; then
        echo -e "${BLUE}Installing SwiftLint...${NC}"
        brew install swiftlint
        echo -e "${GREEN}✅ SwiftLint installed${NC}\n"
    else
        echo -e "${RED}Cannot install SwiftLint without Homebrew${NC}\n"
    fi
else
    echo -e "${GREEN}✅ SwiftLint already installed ($(swiftlint version))${NC}\n"
fi

# Step 4: Install fswatch (optional)
echo -e "${BLUE}[4/7] Checking fswatch (optional for file watcher)...${NC}"
if ! command -v fswatch &> /dev/null; then
    echo -e "${YELLOW}⚠️  fswatch not found${NC}"
    if command -v brew &> /dev/null; then
        echo -e "${BLUE}Install fswatch for continuous monitoring? (y/n)${NC} "
        read -r response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            brew install fswatch
            echo -e "${GREEN}✅ fswatch installed${NC}\n"
        else
            echo -e "${YELLOW}Skipping fswatch (you can install later with: brew install fswatch)${NC}\n"
        fi
    fi
else
    echo -e "${GREEN}✅ fswatch already installed${NC}\n"
fi

# Step 5: Configure Xcode settings
echo -e "${BLUE}[5/7] Configuring Xcode settings...${NC}"
./Scripts/configure-xcode.sh

# Step 6: Install Git pre-commit hook
echo -e "${BLUE}[6/7] Installing Git pre-commit hook...${NC}"
if [ -d ".git" ]; then
    cp Scripts/pre-commit .git/hooks/pre-commit
    chmod +x .git/hooks/pre-commit
    echo -e "${GREEN}✅ Pre-commit hook installed${NC}\n"
else
    echo -e "${YELLOW}⚠️  Not a git repository - skipping hook installation${NC}\n"
fi

# Step 7: Create Xcode build phase snippet
echo -e "${BLUE}[7/7] Creating Xcode build phase snippet...${NC}"
cat > xcode-build-phase-snippet.txt << 'EOF'
# Auto Error Detection
if [ -f "${SRCROOT}/Scripts/auto-build-check.sh" ]; then
    "${SRCROOT}/Scripts/auto-build-check.sh"
fi
EOF
echo -e "${GREEN}✅ Snippet created: xcode-build-phase-snippet.txt${NC}\n"

# Installation complete!
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ Installation Complete!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

echo -e "${CYAN}What's Enabled:${NC}"
echo -e "  ${GREEN}✅${NC} Live issues in Xcode (errors as you type)"
echo -e "  ${GREEN}✅${NC} Parallel compilation (faster builds)"
echo -e "  ${GREEN}✅${NC} Git pre-commit validation"
echo -e "  ${GREEN}✅${NC} Scripts ready to use\n"

echo -e "${YELLOW}Next Steps:${NC}"
echo -e "  ${BLUE}1.${NC} Add Build Phase to Xcode:"
echo -e "     ${CYAN}→${NC} Open Thea.xcodeproj"
echo -e "     ${CYAN}→${NC} Select target → Build Phases → + → New Run Script Phase"
echo -e "     ${CYAN}→${NC} Paste content from: ${BLUE}xcode-build-phase-snippet.txt${NC}"
echo -e "     ${CYAN}→${NC} Drag script phase ${YELLOW}ABOVE${NC} 'Compile Sources'\n"

echo -e "  ${BLUE}2.${NC} Test the setup:"
echo -e "     ${CYAN}make check${NC}    # Run full error scan"
echo -e "     ${CYAN}make summary${NC}  # Show quick statistics\n"

echo -e "  ${BLUE}3.${NC} (Optional) Start file watcher:"
echo -e "     ${CYAN}make watch${NC}    # Continuous monitoring\n"

echo -e "${BLUE}📚 Documentation:${NC}"
echo -e "   ${CYAN}START-HERE.md${NC}                        # Quick start guide"
echo -e "   ${CYAN}XCODE-BUILD-PHASE-GUIDE.md${NC}          # Detailed Xcode instructions"
echo -e "   ${CYAN}QUICK-REFERENCE.md${NC}                  # All commands\n"

# Ask about starting watcher
echo -e "${BLUE}Start background file watcher now? (y/n)${NC} "
read -r response
if [[ "$response" =~ ^[Yy]$ ]]; then
    if command -v fswatch &> /dev/null; then
        echo -e "${GREEN}Starting file watcher...${NC}"
        echo -e "${YELLOW}Press Ctrl+C to stop${NC}\n"
        ./Scripts/watch-and-check.sh
    else
        echo -e "${RED}fswatch not installed - cannot start watcher${NC}"
        echo -e "${BLUE}Install with: brew install fswatch${NC}\n"
    fi
fi

echo -e "${GREEN}Setup complete! Happy coding! 🚀${NC}\n"
