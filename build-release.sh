#!/bin/bash

set -e

echo "════════════════════════════════════════════════════════"
echo "  Building Thea for Release Distribution"
echo "════════════════════════════════════════════════════════"

PROJECT_DIR="/Users/alexis/Documents/IT & Tech/MyApps/Thea/Development"
cd "$PROJECT_DIR"

# Clean
echo "→ Cleaning build directory..."
rm -rf .build/release

# Build with SPM
echo "→ Building Release configuration with SPM..."
swift build -c release

echo "✓ Release build complete!"
echo "✓ Binary location: .build/release/"

