#!/bin/bash
# Auto-run on every Xcode build
# This script is designed to be added as an Xcode Build Phase

# Enable strict error handling
set -eo pipefail

# Only run for actual builds (not indexing)
if [ "${ACTION}" = "indexbuild" ]; then
    exit 0
fi

echo "🔍 Running automatic error detection..."

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

# 1. SwiftLint (if installed)
if command -v swiftlint >/dev/null 2>&1; then
    echo "Running SwiftLint..."
    swiftlint --quiet || true
else
    echo "warning: SwiftLint not installed. Install with: brew install swiftlint"
fi

# 2. Enable stricter warnings
export OTHER_SWIFT_FLAGS="${OTHER_SWIFT_FLAGS} -warn-concurrency -enable-actor-data-race-checks -warn-implicit-overrides"
export GCC_WARN_ABOUT_DEPRECATED_FUNCTIONS="YES"
export CLANG_WARN_DOCUMENTATION_COMMENTS="YES"
export CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER="YES"
export COMPILER_INDEX_STORE_ENABLE="YES"

# 3. Check for common issues
SWIFT_FILES_CHANGED=$(git diff --cached --name-only --diff-filter=ACM 2>/dev/null | grep ".swift$" || echo "")

if [ -n "$SWIFT_FILES_CHANGED" ]; then
    ERROR_COUNT=0
    
    for file in $SWIFT_FILES_CHANGED; do
        if [ -f "$file" ]; then
            # Check for editor placeholders
            if grep -q "<#.*#>" "$file"; then
                echo "${SRCROOT}/${file}:1:1: error: Editor placeholder found in ${file}"
                ERROR_COUNT=$((ERROR_COUNT + 1))
            fi
            
            # Check for force unwrapping (optional warning)
            # Uncomment if you want to warn about force unwraps
            # if grep -q "!" "$file"; then
            #     echo "${SRCROOT}/${file}:1:1: warning: Force unwrapping detected in ${file}"
            # fi
        fi
    done
    
    if [ $ERROR_COUNT -gt 0 ]; then
        echo "error: Found $ERROR_COUNT issues that must be fixed"
        exit 1
    fi
fi

echo "✅ Automatic checks passed"
exit 0
