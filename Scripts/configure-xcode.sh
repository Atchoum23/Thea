#!/bin/bash

################################################################################
# Configure Xcode Settings
# Enables live issues and parallel compilation for faster error detection
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}⚙️  Configuring Xcode settings for optimal error detection...${NC}\n"

# Enable live issues (errors appear as you type)
echo -e "${BLUE}Enabling live issues...${NC}"
defaults write com.apple.dt.Xcode ShowLiveIssues -bool YES
echo -e "${GREEN}✅ Live issues enabled${NC}\n"

# Enable parallel compilation (compile multiple files at once)
echo -e "${BLUE}Enabling parallel compilation...${NC}"
# Get number of CPU cores
CORES=$(sysctl -n hw.ncpu)
# Use 75% of cores for compilation
COMPILE_TASKS=$((CORES * 3 / 4))
if [ $COMPILE_TASKS -lt 4 ]; then
    COMPILE_TASKS=4
fi

defaults write com.apple.dt.Xcode IDEBuildOperationMaxNumberOfConcurrentCompileTasks -int $COMPILE_TASKS
echo -e "${GREEN}✅ Parallel compilation enabled (${COMPILE_TASKS} concurrent tasks)${NC}\n"

# Show build times
echo -e "${BLUE}Enabling build timing display...${NC}"
defaults write com.apple.dt.Xcode ShowBuildOperationDuration -bool YES
echo -e "${GREEN}✅ Build timing enabled${NC}\n"

# Enable additional warnings
echo -e "${BLUE}Enabling additional compiler warnings...${NC}"
defaults write com.apple.dt.Xcode IDEIndexDisable -bool NO
echo -e "${GREEN}✅ Indexing enabled for better error detection${NC}\n"

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ Xcode configuration complete!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

echo -e "${YELLOW}Note: Restart Xcode for changes to take full effect${NC}"
echo -e "${BLUE}Command: killall Xcode && open Thea.xcodeproj${NC}"
