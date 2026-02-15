#!/bin/bash
# G1 Live Guidance - Build and Test Script
# Run this script to build Thea and test the G1 implementation

set -euo pipefail

PROJECT_DIR="$HOME/Documents/IT & Tech/MyApps/Thea"
BUILD_LOG="/tmp/thea_g1_build.log"
TEST_LOG="/tmp/thea_g1_test.log"

echo "🏗️  G1 Live Guidance - Build and Test"
echo "======================================"
echo ""

# Step 1: Clean build
echo "📦 Step 1: Building Thea macOS app..."
cd "$PROJECT_DIR"

xcodebuild -project Thea.xcodeproj \
    -scheme Thea-macOS \
    -configuration Debug \
    -destination "platform=macOS" \
    -parallelizeTargets \
    -jobs 4 \
    build 2>&1 | tee "$BUILD_LOG" | grep -E "(BUILD SUCCEEDED|BUILD FAILED|Compiling|Linking|error:)"

if grep -q "BUILD SUCCEEDED" "$BUILD_LOG"; then
    echo "✅ Build succeeded!"
else
    echo "❌ Build failed. Check $BUILD_LOG for details."
    exit 1
fi

echo ""

# Step 2: Find built app
echo "📍 Step 2: Locating Thea.app..."
THEA_APP=$(find ~/Library/Developer/Xcode/DerivedData/Thea-*/Build/Products/Debug/Thea.app -maxdepth 0 2>/dev/null | head -1)

if [[ -z "$THEA_APP" ]]; then
    echo "❌ Thea.app not found in DerivedData"
    exit 1
fi

echo "✅ Found: $THEA_APP"
echo ""

# Step 3: Launch app
echo "🚀 Step 3: Launching Thea.app..."
open "$THEA_APP"
sleep 3

echo "✅ Thea launched"
echo ""

# Step 4: Test instructions
echo "🧪 Step 4: Manual Testing Instructions"
echo "======================================"
echo ""
echo "Please perform the following tests:"
echo ""
echo "1. ✓ Open Thea → Settings (Cmd+,)"
echo "2. ✓ Click 'Live Guidance' in sidebar"
echo "3. ✓ Click 'Grant' for Screen Recording permission"
echo "   → System Settings should open"
echo "   → Enable 'Thea' in Screen Recording"
echo "   → Return to Thea"
echo "4. ✓ Click 'Grant' for Accessibility permissions"
echo "   → System Settings should open"
echo "   → Enable 'Thea' in Accessibility"
echo "   → Return to Thea"
echo "5. ✓ In 'Task' field, enter:"
echo "   'Navigate Safari to apple.com'"
echo "6. ✓ Ensure 'Enable voice guidance' is ON"
echo "7. ✓ Set Analysis Interval to 2.0s"
echo "8. ✓ Click 'Start Guidance'"
echo "9. ✓ Verify Qwen2-VL model loads (progress shown)"
echo "10. ✓ Open Safari and navigate randomly"
echo "11. ✓ Listen for voice instructions"
echo "12. ✓ Check Activity Monitor for RAM usage (<100GB)"
echo "13. ✓ Verify voice latency (<3s)"
echo "14. ✓ Enable 'Allow control handoff' and test"
echo "15. ✓ Click 'Stop Guidance'"
echo ""
echo "Expected Results:"
echo "  - Qwen2-VL loads successfully (~8GB VRAM)"
echo "  - Screen captures every 2s"
echo "  - Voice speaks instructions"
echo "  - Control handoff works (if enabled)"
echo "  - RAM stays <100GB total"
echo "  - No crashes or errors"
echo ""
echo "📋 Test Log: $TEST_LOG"
echo ""
echo "To log your test results:"
echo "  echo 'Test: <description> - Result: PASS/FAIL' >> $TEST_LOG"
echo ""

# Step 5: RAM monitoring
echo "💾 Step 5: RAM Monitoring"
echo "========================"
echo ""
echo "Run this in another terminal to monitor RAM:"
echo "  watch -n 2 'ps aux | grep Thea.app | grep -v grep'"
echo ""
echo "Or use Activity Monitor (Cmd+Space → Activity Monitor)"
echo ""

# Step 6: Log checking
echo "📜 Step 6: Check Logs"
echo "===================="
echo ""
echo "Check Console.app for Thea logs:"
echo "  1. Open Console.app"
echo "  2. Filter: 'Thea'"
echo "  3. Look for:"
echo "     - '✅ LocalVisionGuidance: Qwen2-VL loaded successfully'"
echo "     - '📋 LocalVisionGuidance: New instruction - ...'"
echo "     - '✅ LocalVisionGuidance: Executed action - ...'"
echo ""

echo "✅ Setup complete! Follow the test instructions above."
echo ""
echo "When testing is complete, update the status:"
echo "  - Edit .claude/G1_IMPLEMENTATION_STATUS.md"
echo "  - Change status from 'AWAITING BUILD + TESTING' to 'COMPLETE'"
echo "  - Add test results section"
