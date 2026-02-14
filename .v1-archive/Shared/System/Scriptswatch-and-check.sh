#!/bin/bash
# Continuous type checker - watches for file changes and shows errors
# Usage: ./Scripts/watch-and-check.sh

echo "👀 Starting continuous Swift type checker..."
echo "   Press Ctrl+C to stop"
echo ""

# Check if fswatch is installed
if ! command -v fswatch &> /dev/null; then
    echo "⚠️  fswatch not found. Install it with:"
    echo "   brew install fswatch"
    exit 1
fi

# Function to run type check
check_swift_files() {
    clear
    echo "🔍 Type-checking Swift files... ($(date '+%H:%M:%S'))"
    echo ""
    
    # Find all Swift files
    SWIFT_FILES=$(find . -name "*.swift" -not -path "*/.*" -not -path "*/DerivedData/*" -not -path "*/Build/*")
    
    ERROR_COUNT=0
    WARNING_COUNT=0
    
    for file in $SWIFT_FILES; do
        # Run type check
        OUTPUT=$(swiftc -typecheck \
            -continue-building-after-errors \
            -warnings-as-errors=false \
            -sdk "$(xcrun --show-sdk-path)" \
            "$file" 2>&1 || true)
        
        if [ -n "$OUTPUT" ]; then
            echo "$OUTPUT"
            ERROR_COUNT=$((ERROR_COUNT + $(echo "$OUTPUT" | grep -c "error:" || echo "0")))
            WARNING_COUNT=$((WARNING_COUNT + $(echo "$OUTPUT" | grep -c "warning:" || echo "0")))
        fi
    done
    
    echo ""
    if [ $ERROR_COUNT -eq 0 ] && [ $WARNING_COUNT -eq 0 ]; then
        echo "✅ No issues found!"
    else
        echo "Summary: $ERROR_COUNT errors, $WARNING_COUNT warnings"
    fi
    echo ""
    echo "👀 Watching for changes..."
}

# Initial check
check_swift_files

# Watch for changes
fswatch -o -r \
    --exclude ".*\/\..*" \
    --exclude ".*\/DerivedData\/.*" \
    --exclude ".*\/Build\/.*" \
    --include "\.swift$" \
    . | while read num
do
    check_swift_files
done
