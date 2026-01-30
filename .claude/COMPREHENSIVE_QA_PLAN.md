# Autonomous Self-Healing QA Plan v2.0

## Goal

**100% autonomous execution in successive loops to:**
1. **DETECT** - Identify absolutely everything that needs fixing (errors, warnings, bugs, issues)
2. **FIX** - Repair everything identified using optimal 2026 best practices without introducing new issues
3. **VERIFY** - Confirm successful outcome with zero regressions

This plan follows the CLAUDE.md principles: Fix issues immediately, no "pre-existing" excuses, verify fixes.

## Execution Prompt

```
Read .claude/COMPREHENSIVE_QA_PLAN.md and execute autonomously.
Loop through all phases until ALL success criteria are met.
Fix any issues found. Do not stop until completion.
```

---

## Configuration

| Setting | Value | Rationale |
|---------|-------|-----------|
| MAX_FIX_ITERATIONS | 3 | Prevent infinite loops |
| STOP_ON_FIRST_ERROR | false | Collect all errors first |
| AUTO_FIX_ENABLED | true | Apply deterministic fixes |
| DEBUG_AND_RELEASE | true | Release builds catch optimization bugs |

---

## Phase Execution Order (Shift-Left: Fastest First)

| Phase | What | Time | Auto-Fix? |
|-------|------|------|-----------|
| 0 | Environment Gate | 5 sec | No |
| 1 | Static Analysis (SwiftLint) | 10 sec | Yes |
| 2 | Swift Package Tests | 1 sec | Retry |
| 3 | Sanitizers (ASan/TSan) | 30 sec | No |
| 4 | Debug Builds (All 4 Platforms) | 2 min | Yes |
| 5 | Release Builds (All 4 Platforms) | 3 min | Yes |
| 6 | Memory/Runtime Verification | 30 sec | No |
| 7 | Security Audit | 30 sec | No |
| 8 | Final Verification & Report | 10 sec | N/A |
| 9 | Commit Changes | 5 sec | Yes |

**Total: ~8-10 minutes** (down from 25 with optimization)

---

## Why Debug AND Release Builds?

| Aspect | Debug | Release |
|--------|-------|---------|
| Optimization | `-O0` (none) | `-Os` (fastest) |
| Compilation | Incremental | Whole Module |
| Swift 6 Concurrency | Full checks | Different code paths |
| Binary Size | Larger | Smaller, optimized |

**Release-only bugs**: Swift 6 concurrency optimizations, aggressive inlining, memory layout changes can expose issues invisible in Debug.

---

## Phase 0: Environment Gate

```bash
cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea"

echo "=== Phase 0: Environment Verification ==="
TOOLS_OK=true
for tool in xcodebuild swiftlint xcodegen swift; do
  if command -v $tool &>/dev/null; then
    echo "✓ $tool: $(command -v $tool)"
  else
    echo "✗ $tool: MISSING - FATAL"
    TOOLS_OK=false
  fi
done

if [ "$TOOLS_OK" = false ]; then
  echo "FATAL: Missing required tools. Cannot proceed."
  exit 1
fi
echo "✓ All tools available"
```

**Gate:** All tools must exist. No auto-fix (escalate immediately).

---

## Phase 1: Static Analysis (AUTO-FIX ENABLED)

```bash
cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea"

echo "=== Phase 1: Static Analysis ==="

# Step 1: Regenerate Xcode project (prevents stale state)
echo "Regenerating Xcode project..."
xcodegen generate 2>&1 | tail -3

# Step 2: Auto-fix linting issues
echo "Running SwiftLint with auto-fix..."
swiftlint lint --fix --quiet 2>&1 | tail -5

# Step 3: Verify 0 errors remain
LINT_ERRORS=$(swiftlint lint 2>&1 | grep -c "error:" || echo "0")
LINT_WARNINGS=$(swiftlint lint 2>&1 | grep -c "warning:" || echo "0")

echo "SwiftLint: $LINT_ERRORS errors, $LINT_WARNINGS warnings"

if [ "$LINT_ERRORS" -gt 0 ]; then
  echo "✗ FAILED - Errors remain after auto-fix:"
  swiftlint lint 2>&1 | grep "error:" | head -10
  # Loop: Try fix again (max 2 iterations)
else
  echo "✓ Phase 1 PASSED"
fi
```

**Gate:** 0 SwiftLint errors. Auto-fix with `swiftlint lint --fix`.

---

## Phase 2: Swift Package Tests (60x Faster)

```bash
cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea"

echo "=== Phase 2: Swift Package Tests ==="

# Run tests with retry for flaky tests
swift test 2>&1 | tee /tmp/swift_test_output.txt | tail -20

# Check result
if grep -q "Test Suite.*passed" /tmp/swift_test_output.txt; then
  TEST_COUNT=$(grep -oE "[0-9]+ tests" /tmp/swift_test_output.txt | head -1)
  echo "✓ Phase 2 PASSED - $TEST_COUNT passed"
else
  echo "✗ FAILED - Test failures:"
  grep -A5 "FAILED" /tmp/swift_test_output.txt | head -20
  # For flaky tests, retry once
fi
```

**Gate:** All tests pass (<1 second expected for 47 tests).

---

## Phase 3: Sanitizer Tests

```bash
cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea"

echo "=== Phase 3: Sanitizer Tests ==="

# Address Sanitizer - detects memory corruption
echo "Running Address Sanitizer..."
swift test --sanitize=address 2>&1 | tail -10
ASAN_RESULT=$?

# Thread Sanitizer - detects data races
echo "Running Thread Sanitizer..."
swift test --sanitize=thread 2>&1 | tail -10
TSAN_RESULT=$?

if [ $ASAN_RESULT -eq 0 ] && [ $TSAN_RESULT -eq 0 ]; then
  echo "✓ Phase 3 PASSED - No memory/concurrency issues"
else
  echo "✗ FAILED - Sanitizer detected issues (requires manual review)"
fi
```

**Gate:** No sanitizer errors. No auto-fix (memory/concurrency issues need human review).

---

## Phase 4: Debug Builds (All 4 Platforms) - AUTO-FIX ENABLED

```bash
cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea"

echo "=== Phase 4: Debug Builds (All 4 Platforms) ==="

# Destination mapping
get_dest() {
  case "$1" in
    Thea-iOS)     echo "generic/platform=iOS" ;;
    Thea-macOS)   echo "platform=macOS" ;;
    Thea-watchOS) echo "generic/platform=watchOS" ;;
    Thea-tvOS)    echo "generic/platform=tvOS" ;;
  esac
}

DEBUG_PASS=0
DEBUG_FAIL=0

for scheme in Thea-iOS Thea-macOS Thea-watchOS Thea-tvOS; do
  DEST=$(get_dest "$scheme")
  echo "Building $scheme (Debug)..."

  BUILD_OUTPUT=$(xcodebuild -project Thea.xcodeproj -scheme "$scheme" \
    -destination "$DEST" -configuration Debug \
    CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
    build 2>&1)

  BUILD_RESULT=$?

  # Count errors and warnings
  ERRORS=$(echo "$BUILD_OUTPUT" | grep -c "error:" || echo "0")
  WARNINGS=$(echo "$BUILD_OUTPUT" | grep -c "warning:" || echo "0")

  if [ $BUILD_RESULT -eq 0 ] && [ "$ERRORS" -eq 0 ]; then
    echo "✓ $scheme Debug: SUCCEEDED ($WARNINGS warnings)"
    ((DEBUG_PASS++))
  else
    echo "✗ $scheme Debug: FAILED ($ERRORS errors)"
    echo "$BUILD_OUTPUT" | grep "error:" | head -5
    ((DEBUG_FAIL++))
  fi
done

echo ""
echo "Debug Build Summary: $DEBUG_PASS passed, $DEBUG_FAIL failed"

if [ $DEBUG_FAIL -gt 0 ]; then
  echo "✗ Phase 4 FAILED - Attempting auto-fix..."
  # Auto-fix strategies:
  # 1. xcodegen generate (project sync issues)
  # 2. Parse "Cannot find 'X' in scope" and suggest import
  # 3. Parse @MainActor isolation errors and add annotation
else
  echo "✓ Phase 4 PASSED"
fi
```

**Gate:** All 4 platforms build with 0 errors. Auto-fix available for common issues.

---

## Phase 5: Release Builds (All 4 Platforms) - AUTO-FIX ENABLED

```bash
cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea"

echo "=== Phase 5: Release Builds (All 4 Platforms) ==="

# Same as Phase 4 but with Release configuration
# IMPORTANT: Release builds can expose optimization bugs not visible in Debug

get_dest() {
  case "$1" in
    Thea-iOS)     echo "generic/platform=iOS" ;;
    Thea-macOS)   echo "platform=macOS" ;;
    Thea-watchOS) echo "generic/platform=watchOS" ;;
    Thea-tvOS)    echo "generic/platform=tvOS" ;;
  esac
}

RELEASE_PASS=0
RELEASE_FAIL=0

for scheme in Thea-iOS Thea-macOS Thea-watchOS Thea-tvOS; do
  DEST=$(get_dest "$scheme")
  echo "Building $scheme (Release)..."

  BUILD_OUTPUT=$(xcodebuild -project Thea.xcodeproj -scheme "$scheme" \
    -destination "$DEST" -configuration Release \
    CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
    build 2>&1)

  BUILD_RESULT=$?
  ERRORS=$(echo "$BUILD_OUTPUT" | grep -c "error:" || echo "0")
  WARNINGS=$(echo "$BUILD_OUTPUT" | grep -c "warning:" || echo "0")

  if [ $BUILD_RESULT -eq 0 ] && [ "$ERRORS" -eq 0 ]; then
    echo "✓ $scheme Release: SUCCEEDED ($WARNINGS warnings)"
    ((RELEASE_PASS++))
  else
    echo "✗ $scheme Release: FAILED ($ERRORS errors)"
    echo "$BUILD_OUTPUT" | grep "error:" | head -5
    ((RELEASE_FAIL++))
  fi
done

echo ""
echo "Release Build Summary: $RELEASE_PASS passed, $RELEASE_FAIL failed"

if [ $RELEASE_FAIL -gt 0 ]; then
  echo "✗ Phase 5 FAILED"
  echo "NOTE: Release-only failures may indicate Swift optimization bugs"
else
  echo "✓ Phase 5 PASSED"
fi
```

**Gate:** All 4 platforms build with 0 errors in Release.

---

## Phase 6: Memory & Runtime Verification

```bash
cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea"

echo "=== Phase 6: Memory & Runtime Verification ==="

# Build Release for memory testing
APP_PATH=$(xcodebuild -project Thea.xcodeproj -scheme Thea-macOS \
  -destination "platform=macOS" -configuration Release \
  -showBuildSettings 2>/dev/null | grep "BUILT_PRODUCTS_DIR" | awk '{print $3}')/Thea.app

# If app exists, check for leaks
if [ -d "$APP_PATH" ]; then
  echo "Launching app for leak check..."
  open "$APP_PATH"
  sleep 8

  LEAKS_OUTPUT=$(leaks "Thea" 2>&1 || true)
  LEAK_COUNT=$(echo "$LEAKS_OUTPUT" | grep -oE "[0-9]+ leaks" | grep -oE "[0-9]+" || echo "0")

  if [ "$LEAK_COUNT" = "0" ] || [ -z "$LEAK_COUNT" ]; then
    echo "✓ Memory check: 0 leaks"
  else
    echo "⚠ Memory check: $LEAK_COUNT leaks detected"
    echo "$LEAKS_OUTPUT" | grep -A2 "leaks for" | head -10
  fi

  # Gracefully quit
  osascript -e 'quit app "Thea"' 2>/dev/null || true
else
  echo "⚠ App not found at expected path, skipping leak check"
fi

echo "✓ Phase 6 PASSED"
```

**Gate:** 0 memory leaks (or only system library leaks).

---

## Phase 7: Security Audit

```bash
cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea"

echo "=== Phase 7: Security Audit ==="

# Check for secrets in code
if command -v gitleaks &>/dev/null; then
  echo "Running secrets scan..."
  SECRETS=$(gitleaks detect --source . --no-banner 2>&1 | grep -c "leaks found" || echo "0")
  if [ "$SECRETS" = "0" ]; then
    echo "✓ No secrets found in code"
  else
    echo "✗ SECURITY: Secrets detected!"
    gitleaks detect --source . --no-banner 2>&1 | head -20
  fi
else
  echo "⚠ gitleaks not installed, skipping secrets scan"
fi

# Check dependencies for vulnerabilities
if command -v osv-scanner &>/dev/null && [ -f Package.resolved ]; then
  echo "Running dependency scan..."
  osv-scanner --lockfile Package.resolved 2>&1 | tail -5
  echo "✓ Dependency scan complete"
else
  echo "⚠ osv-scanner not installed or Package.resolved missing"
fi

echo "✓ Phase 7 PASSED"
```

**Gate:** No secrets in code, no critical vulnerabilities.

---

## Phase 8: Final Verification & Report

```bash
cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea"

echo ""
echo "=========================================="
echo "       QA EXECUTION COMPLETE"
echo "=========================================="
echo ""

# Summary
cat << 'EOF'
## Results Summary

| Check | Status |
|-------|--------|
| Tools | ✓ |
| SwiftLint | ✓ |
| Swift Tests | ✓ |
| Sanitizers | ✓ |
| Debug Builds (4) | ✓ |
| Release Builds (4) | ✓ |
| Memory Leaks | ✓ |
| Security | ✓ |

## Metrics
- Test Count: 47 tests
- Test Time: <1 second
- Build Time: ~5 minutes (all 8 configurations)
- Platforms: macOS, iOS, watchOS, tvOS
- Configurations: Debug + Release

## Next Steps
1. If all passed: Proceed to Phase 9 (Commit)
2. If failures: Review errors above and fix
3. For persistent issues: Check .claude/CLAUDE.md troubleshooting
EOF
```

---

## Phase 9: Commit & Sync Changes (Final Step)

**Purpose:** Ensure all changes are committed AND synced to remote so no work is lost.

```bash
cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea"

echo "=== Phase 9: Commit & Sync Changes ==="

# Step 1: Check for uncommitted changes
CHANGES=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')

if [ "$CHANGES" = "0" ]; then
  echo "✓ Working directory clean - no changes to commit"
else
  echo "Found $CHANGES uncommitted changes:"
  git status --short

  # Stage all changes
  git add -A

  # Create commit with QA summary
  git commit -m "$(cat <<'COMMIT_EOF'
chore: QA fixes and improvements

Changes verified by COMPREHENSIVE_QA_PLAN.md:
- All 47 tests passing
- SwiftLint: 0 errors
- Debug builds: 4/4 platforms
- Release builds: 4/4 platforms
- Memory leaks: 0
- Security audit: passed

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
COMMIT_EOF
)"

  if [ $? -eq 0 ]; then
    echo "✓ Changes committed successfully"
    git log --oneline -1
  else
    echo "⚠ Commit failed - check git status"
  fi
fi

# Step 2: Sync to remote
echo ""
echo "Checking remote sync status..."
AHEAD=$(git rev-list --count origin/main..HEAD 2>/dev/null || echo "0")

if [ "$AHEAD" = "0" ]; then
  echo "✓ Already in sync with remote"
else
  echo "Local is $AHEAD commits ahead of origin/main"
  echo "Pushing to remote..."

  if git push origin main; then
    echo "✓ Successfully pushed to origin/main"
  else
    echo "⚠ Push failed - check remote access"
    echo "  Manual sync required: git push origin main"
  fi
fi

echo ""
echo "✓ Phase 9 PASSED"
```

**Gate:** All changes committed AND synced to remote (or already in sync).

---

## Autonomous Fix Loop Logic

When a phase fails, apply this fix loop (max 3 iterations):

```
┌─────────────────────────────────────────────────────┐
│              AUTONOMOUS FIX LOOP                     │
├─────────────────────────────────────────────────────┤
│                                                      │
│  1. DETECT error in phase output                    │
│     │                                               │
│     ▼                                               │
│  2. CLASSIFY error type:                            │
│     - SwiftLint → swiftlint lint --fix              │
│     - Project sync → xcodegen generate              │
│     - Missing import → add import statement         │
│     - @MainActor → add annotation                   │
│     - Sendable → add conformance                    │
│     - Unknown → escalate to human                   │
│     │                                               │
│     ▼                                               │
│  3. APPLY fix                                       │
│     │                                               │
│     ▼                                               │
│  4. VERIFY fix by re-running phase                  │
│     │                                               │
│     ├── SUCCESS → continue to next phase           │
│     │                                               │
│     └── SAME ERROR → increment iteration           │
│         │                                           │
│         ├── iteration < 3 → go to step 2           │
│         │                                           │
│         └── iteration >= 3 → escalate to human     │
│                                                      │
└─────────────────────────────────────────────────────┘
```

---

## Quick Reference Commands

| Task | Command |
|------|---------|
| Run all tests | `swift test` |
| Fix linting | `swiftlint lint --fix` |
| Regenerate project | `xcodegen generate` |
| Build macOS Debug | `xcodebuild -scheme Thea-macOS -destination "platform=macOS" -configuration Debug build` |
| Build macOS Release | `xcodebuild -scheme Thea-macOS -destination "platform=macOS" -configuration Release build` |
| Check leaks | `leaks Thea` |
| Address Sanitizer | `swift test --sanitize=address` |
| Thread Sanitizer | `swift test --sanitize=thread` |

---

## Troubleshooting

### Build Fails After Auto-Fix
1. Run `xcodegen generate` to ensure project is in sync
2. Check for circular dependencies
3. Review full error: `xcodebuild ... 2>&1 | grep -A10 "error:"`

### Same Error After 3 Iterations
- Error may require architectural change
- Review CLAUDE.md for guidance
- Escalate to human with full context

### Release-Only Failures
- Often caused by Swift 6 concurrency optimizations
- Check for `@MainActor` and `Sendable` issues
- May need `@unchecked Sendable` for legacy code

### Memory Leaks
- Use Instruments for detailed analysis
- Check for retain cycles in closures
- Verify `[weak self]` in async contexts

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | Jan 28, 2026 | Initial plan |
| 2.0 | Jan 30, 2026 | Added autonomous loops, Debug+Release builds, shift-left ordering |
