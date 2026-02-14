#!/bin/bash
# Quick error summary - shows all errors grouped by type
# Usage: ./Scripts/error-summary.sh

echo "📊 Generating error summary..."
echo ""

# Create temp file
TMP_FILE=$(mktemp)

# Find all Swift files and check them
find . -name "*.swift" \
    -not -path "*/.*" \
    -not -path "*/DerivedData/*" \
    -not -path "*/Build/*" \
    -exec swiftc -typecheck \
        -continue-building-after-errors \
        -sdk "$(xcrun --show-sdk-path)" \
        {} \; 2> "$TMP_FILE" || true

# Count errors by type
SYNTAX_ERRORS=$(grep -c "syntax error" "$TMP_FILE" || echo "0")
TYPE_ERRORS=$(grep -c "type error" "$TMP_FILE" || echo "0")
DEPRECATION_WARNINGS=$(grep -c "deprecated" "$TMP_FILE" || echo "0")
OTHER_ERRORS=$(grep -c "error:" "$TMP_FILE" || echo "0")
TOTAL_WARNINGS=$(grep -c "warning:" "$TMP_FILE" || echo "0")

# Display summary
echo "=== Error Summary ==="
echo ""
echo "Syntax Errors:        $SYNTAX_ERRORS"
echo "Type Errors:          $TYPE_ERRORS"
echo "Other Errors:         $OTHER_ERRORS"
echo "Deprecation Warnings: $DEPRECATION_WARNINGS"
echo "Total Warnings:       $TOTAL_WARNINGS"
echo ""

# Show unique error messages
echo "=== Unique Error Messages ==="
echo ""
grep "error:" "$TMP_FILE" | \
    sed 's/^.*error: //' | \
    sort | \
    uniq -c | \
    sort -rn | \
    head -20

echo ""
echo "=== Unique Warning Messages ==="
echo ""
grep "warning:" "$TMP_FILE" | \
    sed 's/^.*warning: //' | \
    sort | \
    uniq -c | \
    sort -rn | \
    head -20

# Cleanup
rm "$TMP_FILE"

echo ""
echo "✅ Done!"
