#!/bin/bash
# Build script that attempts to show all errors at once
# Usage: ./Scripts/build-with-all-errors.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}🔍 Building with maximum error detection...${NC}\n"

# Find all Swift files in the project
SWIFT_FILES=$(find . -name "*.swift" -not -path "*/.*" -not -path "*/DerivedData/*" -not -path "*/Build/*")

# Count total files
TOTAL_FILES=$(echo "$SWIFT_FILES" | wc -l | xargs)
echo -e "${GREEN}Found $TOTAL_FILES Swift files${NC}\n"

# Create temporary directory for results
TMP_DIR=$(mktemp -d)
ERROR_FILE="$TMP_DIR/errors.txt"

# Type-check all files with error recovery
echo -e "${YELLOW}Running Swift type-checker with error recovery...${NC}\n"

COUNTER=0
ERROR_COUNT=0

for file in $SWIFT_FILES; do
    COUNTER=$((COUNTER + 1))
    echo -ne "${YELLOW}Progress: $COUNTER/$TOTAL_FILES${NC}\r"
    
    # Run swiftc in typecheck mode, continue on errors
    swiftc -typecheck \
        -continue-building-after-errors \
        -warnings-as-errors=false \
        -sdk "$(xcrun --show-sdk-path)" \
        "$file" 2>> "$ERROR_FILE" || true
done

echo -e "\n"

# Check if there were any errors
if [ -s "$ERROR_FILE" ]; then
    ERROR_COUNT=$(grep -c "error:" "$ERROR_FILE" || echo "0")
    WARNING_COUNT=$(grep -c "warning:" "$ERROR_FILE" || echo "0")
    
    echo -e "${RED}❌ Found $ERROR_COUNT errors and $WARNING_COUNT warnings${NC}\n"
    echo -e "${YELLOW}=== Error Report ===${NC}\n"
    
    # Display errors grouped by file
    cat "$ERROR_FILE" | sed 's/^/  /'
    
    echo -e "\n${YELLOW}=== Summary ===${NC}"
    echo -e "Total files checked: $TOTAL_FILES"
    echo -e "Errors: ${RED}$ERROR_COUNT${NC}"
    echo -e "Warnings: ${YELLOW}$WARNING_COUNT${NC}"
    
    # Save to file
    REPORT_FILE="build-errors-$(date +%Y%m%d-%H%M%S).txt"
    cp "$ERROR_FILE" "$REPORT_FILE"
    echo -e "\n${GREEN}Full report saved to: $REPORT_FILE${NC}"
else
    echo -e "${GREEN}✅ No errors found!${NC}"
fi

# Cleanup
rm -rf "$TMP_DIR"

echo -e "\n${GREEN}Done!${NC}"
