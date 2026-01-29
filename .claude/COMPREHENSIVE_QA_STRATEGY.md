# Thea Comprehensive QA Strategy

## Overview

This document defines the complete Quality Assurance strategy for the Thea project - a multi-platform Swift 6 application (macOS, iOS, watchOS, tvOS) with MLX on-device AI, 12 extensions, and 316 test functions.

**Last Updated:** January 29, 2026
**Version:** 1.0

---

## Part 1: QA Tool Matrix

### 1.1 Static Analysis Tools

| Tool | Purpose | Command | Target |
|------|---------|---------|--------|
| **SwiftLint** | Code style & best practices | `swiftlint lint --strict` | 0 violations |
| **SwiftFormat** | Code formatting | `swiftformat .` | Consistent style |
| **XCLogParser** | Build log analysis | `xclogparser parse --file LOG --reporter issues` | 0 issues |
| **Xcode Analyzer** | Static analysis | Build with `CLANG_ANALYZER_*` enabled | 0 warnings |
| **Periphery** | Dead code detection | `periphery scan --project Thea.xcodeproj` | 0 findings |

### 1.2 Runtime Analysis Tools

| Tool | Purpose | Command | Target |
|------|---------|---------|--------|
| **Address Sanitizer** | Memory corruption, buffer overflows | `xcodebuild test -enableAddressSanitizer YES` | 0 findings |
| **Thread Sanitizer** | Data races, threading issues | `xcodebuild test -enableThreadSanitizer YES` | 0 findings |
| **UBSan** | Undefined behavior | `xcodebuild test -enableUndefinedBehaviorSanitizer YES` | 0 findings |
| **Instruments (Leaks)** | Memory leak detection | Xcode > Product > Profile > Leaks | 0 leaks |

### 1.3 Testing Tools

| Tool | Purpose | Command | Target |
|------|---------|---------|--------|
| **XCTest** | Unit & integration tests | `xcodebuild test -scheme Thea-macOS` | All pass |
| **XCUITest** | UI automation | Included in test scheme | All pass |
| **Maestro** | iOS E2E testing | `maestro test .maestro/` | All flows pass |
| **Swift Testing** | Modern test framework | `@Test` functions | All pass |

### 1.4 Security Tools

| Tool | Purpose | Command | Target |
|------|---------|---------|--------|
| **gitleaks** | Secrets detection | `gitleaks detect --source . --no-git` | 0 real findings |
| **osv-scanner** | Dependency vulnerabilities | `osv-scanner --lockfile Package.resolved` | 0 critical |
| **thea-audit** | Custom security scan | `thea-audit audit --path .` | 0 critical |
| **Keychain audit** | Secure storage verification | Manual review | Proper access control |

### 1.5 Accessibility Tools

| Tool | Purpose | Command | Target |
|------|---------|---------|--------|
| **performAccessibilityAudit()** | Automated audits | In XCUITest | All pass |
| **VoiceOver** | Screen reader testing | Manual | Full navigation |
| **Dynamic Type** | Text size accessibility | Manual | Layouts adapt |
| **Accessibility Inspector** | Element inspection | Xcode tool | All labeled |

### 1.6 Platform Validation Tools

| Tool | Purpose | Command | Target |
|------|---------|---------|--------|
| **codesign** | Signature verification | `codesign --verify --deep --strict --verbose=4` | Valid |
| **spctl** | Gatekeeper assessment | `spctl --assess --type exec` | Accepted |
| **notarytool** | Notarization | `xcrun notarytool submit` | Successful |
| **altool** | App Store validation | `xcrun altool --validate-app` | No errors |

---

## Part 2: Verification Procedures

### 2.1 Build Verification (Two-Phase)

**Phase A: CLI Builds**
```bash
cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea"

# Build all 4 platforms
for scheme in "Thea-iOS" "Thea-macOS" "Thea-watchOS" "Thea-tvOS"; do
  xcodebuild -project Thea.xcodeproj -scheme "$scheme" \
    -destination "generic/platform=${scheme#Thea-}" \
    CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO \
    build 2>&1 | tee "build_${scheme}.log"
done

# Check for warnings
for log in build_Thea-*.log; do
  echo "$log: $(grep -c ' warning:' "$log" || echo 0) warnings"
done
```

**Phase B: GUI Builds (via AppleScript + XCLogParser)**
```bash
# Trigger GUI build
osascript -e 'tell application "Xcode" to build front workspace document'

# Wait and read log
sleep 120
LOG=$(ls -t ~/Library/Developer/Xcode/DerivedData/Thea-*/Logs/Build/*.xcactivitylog | head -1)
xclogparser parse --file "$LOG" --reporter issues
```

**Success Criteria:**
- All 4 CLI builds: 0 errors, 0 warnings
- All 4 GUI builds: 0 issues in Issue Navigator
- XCLogParser: 0 errors, 0 warnings

### 2.2 Sanitizer Runs

```bash
# Address Sanitizer (memory issues)
xcodebuild test -project Thea.xcodeproj -scheme "Thea-macOS" \
  -destination 'platform=macOS' \
  -enableAddressSanitizer YES \
  2>&1 | tee sanitizer_address.log

# Thread Sanitizer (data races - CRITICAL for Swift 6)
xcodebuild test -project Thea.xcodeproj -scheme "Thea-macOS" \
  -destination 'platform=macOS' \
  -enableThreadSanitizer YES \
  2>&1 | tee sanitizer_thread.log

# Check results
grep -E "(AddressSanitizer|ThreadSanitizer|SUMMARY)" sanitizer_*.log
```

**Success Criteria:**
- 0 Address Sanitizer findings
- 0 Thread Sanitizer findings (data races)

### 2.3 Security Audit

```bash
cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea"

# Secrets scan (exclude build artifacts)
gitleaks detect --source . --no-git \
  --config .gitleaks.toml \
  2>&1 | tee security_secrets.log

# Dependency vulnerabilities
osv-scanner --lockfile Thea.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved \
  2>&1 | tee security_deps.log

# Custom audit (if available)
if [ -x Tools/thea-audit/.build/release/thea-audit ]; then
  ./Tools/thea-audit/.build/release/thea-audit audit --path . --severity low
fi
```

**Success Criteria:**
- 0 real secrets (false positives documented)
- 0 critical dependency vulnerabilities

### 2.4 Test Execution

```bash
# macOS unit tests
xcodebuild test -project Thea.xcodeproj -scheme "Thea-macOS" \
  -destination 'platform=macOS' \
  -resultBundlePath TestResults-macOS.xcresult \
  2>&1 | tee test_macos.log

# iOS Simulator tests
SIMULATOR=$(xcrun simctl list devices available | grep "iPhone 16" | head -1 | sed 's/.*(\([^)]*\)).*/\1/')
xcodebuild test -project Thea.xcodeproj -scheme "Thea-iOS" \
  -destination "platform=iOS Simulator,id=$SIMULATOR" \
  -resultBundlePath TestResults-iOS.xcresult \
  2>&1 | tee test_ios.log

# Maestro E2E (if configured)
if [ -d .maestro ]; then
  maestro test .maestro/ 2>&1 | tee test_maestro.log
fi
```

**Success Criteria:**
- All unit tests pass
- All UI tests pass
- All E2E flows pass

### 2.5 Platform Validation

**macOS:**
```bash
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData/Thea-*/Build/Products/Debug -name "Thea.app" -path "*macOS*" | head -1)

# Verify signature and hardened runtime
codesign --verify --deep --strict --verbose=4 "$APP_PATH"

# Check entitlements
codesign -d --entitlements - "$APP_PATH"

# Gatekeeper assessment (may fail without notarization)
spctl --assess --type exec --verbose "$APP_PATH" || echo "Not notarized yet"
```

**iOS:**
```bash
# Check for privacy manifest
ls -la "/Users/alexis/Documents/IT & Tech/MyApps/Thea/iOS/"*.xcprivacy 2>/dev/null || echo "Privacy manifest check needed"

# Verify Info.plist required keys
plutil -p "/Users/alexis/Documents/IT & Tech/MyApps/Thea/iOS/Info.plist" | grep -E "(Privacy|Usage)"
```

### 2.6 MLX/AI Validation

```bash
# Build and run MLX test script
cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea"
swift Tools/test-mlx.swift 2>&1 | tee mlx_validation.log

# Check model directory
ls -la ~/.cache/huggingface/hub/ | head -10
```

**Success Criteria:**
- Models discovered correctly
- Inference produces valid output
- Memory released after session

---

## Part 3: Success Criteria Checklist

### Build Quality
- [ ] All 4 CLI Debug builds: 0 errors, 0 warnings
- [ ] All 4 CLI Release builds: 0 errors, 0 warnings
- [ ] All 4 GUI builds: 0 issues in Issue Navigator
- [ ] SwiftLint: 0 violations
- [ ] SwiftFormat: Applied

### Runtime Quality
- [ ] Address Sanitizer: 0 findings
- [ ] Thread Sanitizer: 0 data races
- [ ] No memory leaks in Instruments

### Test Coverage
- [ ] All unit tests passing
- [ ] All UI tests passing
- [ ] All Maestro E2E flows passing
- [ ] Code coverage > 60%

### Accessibility
- [ ] performAccessibilityAudit() passes
- [ ] VoiceOver navigation complete
- [ ] Dynamic Type layouts work

### Security
- [ ] No real secrets in codebase
- [ ] No critical dependency vulnerabilities
- [ ] Keychain usage verified secure

### Platform Compliance
- [ ] macOS: Hardened runtime enabled
- [ ] macOS: Notarization ready
- [ ] iOS: Privacy manifest present
- [ ] iOS: Required Info.plist keys present
- [ ] watchOS: Complications work
- [ ] tvOS: Focus navigation works

### MLX/AI (macOS only)
- [ ] Model loading works
- [ ] Inference produces output
- [ ] Memory properly released
- [ ] Graceful degradation on unsupported hardware

### CI/CD
- [ ] CI workflow passes
- [ ] E2E Tests workflow passes
- [ ] Security Audit workflows pass

---

## Part 4: Automation Scripts

### Full QA Run Script

```bash
#!/bin/bash
# qa-full-run.sh - Complete QA validation

set -e
cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea"

echo "=== Thea Full QA Run ==="
echo "Started: $(date)"

# 1. Code Quality
echo ""
echo "=== Step 1: Code Quality ==="
swiftlint lint --strict || { echo "SwiftLint failed"; exit 1; }

# 2. Build All Platforms
echo ""
echo "=== Step 2: Build All Platforms ==="
for scheme in "Thea-macOS" "Thea-iOS" "Thea-watchOS" "Thea-tvOS"; do
  echo "Building $scheme..."
  xcodebuild -project Thea.xcodeproj -scheme "$scheme" \
    -destination "generic/platform=${scheme#Thea-}" \
    CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO \
    build 2>&1 | grep -E "(BUILD|error:|warning:)" | tail -5
done

# 3. Run Tests
echo ""
echo "=== Step 3: Run Tests ==="
xcodebuild test -project Thea.xcodeproj -scheme "Thea-macOS" \
  -destination 'platform=macOS' \
  2>&1 | grep -E "(Test Suite|passed|failed)" | tail -10

# 4. Security Scan
echo ""
echo "=== Step 4: Security Scan ==="
gitleaks detect --source . --no-git --config .gitleaks.toml || true

# 5. Summary
echo ""
echo "=== QA Run Complete ==="
echo "Finished: $(date)"
```

### Quick Validation Script

```bash
#!/bin/bash
# qa-quick.sh - Quick pre-commit validation

cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea"

echo "Quick QA Check..."

# SwiftLint
swiftlint lint 2>&1 | tail -3

# Build macOS only
xcodebuild -project Thea.xcodeproj -scheme "Thea-macOS" \
  -destination 'platform=macOS' \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO \
  build 2>&1 | grep -E "BUILD" | tail -1

echo "Quick check complete"
```

---

## Part 5: Maintenance

### Weekly Tasks
- Run full QA suite
- Update dependencies
- Review security advisories

### Before Each Release
- Run all sanitizers
- Complete Instruments profiling
- Verify notarization
- Update version numbers

### After Major Changes
- Run Thread Sanitizer (Swift 6 concurrency)
- Verify accessibility
- Test on all platforms

---

## References

- [Swift Testing - Apple Developer](https://developer.apple.com/xcode/swift-testing)
- [Xcode Sanitizers Documentation](https://developer.apple.com/documentation/xcode/diagnosing-memory-thread-and-crash-issues-early)
- [XCLogParser GitHub](https://github.com/MobileNativeFoundation/XCLogParser)
- [Accessibility Audits - WWDC23](https://developer.apple.com/videos/play/wwdc2023/10035/)
- [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [MLX Swift Documentation](https://www.swift.org/blog/mlx-swift/)
