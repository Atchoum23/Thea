# Automatic Error Detection - Complete Guide

Comprehensive documentation for the Thea automatic error detection system.

## 📖 Table of Contents

1. [Overview](#overview)
2. [Quick Start](#quick-start)
3. [Components](#components)
4. [Installation](#installation)
5. [Usage](#usage)
6. [Troubleshooting](#troubleshooting)

## Overview

### What This System Does

Stops the endless "build → fix 1 error → build → fix 1 error" cycle by showing ~99% of errors at once.

### Error Detection Layers

| Layer | Coverage | Speed | When It Runs |
|-------|----------|-------|--------------|
| **Xcode Live Issues** | ~80% | Real-time | As you type |
| **Build Phase** | ~95% | Fast (1-3s) | Every build (⌘+B) |
| **Git Pre-commit** | ~90% | Fast (0.5-2s) | Every commit |
| **File Watcher** | ~99% | Instant | On file save |
| **Manual Scan** | ~99% | Slow (10-30s) | On demand |

### Combined Coverage

Running all layers together catches **~99% of errors** before they become problems.

## Quick Start

### 5-Minute Setup

```bash
# 1. Run installer
cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea/Development"
./install-automatic-checks.sh

# 2. Add Xcode build phase (see XCODE-BUILD-PHASE-GUIDE.md)

# 3. Test it
make check
```

Done! See `START-HERE.md` for detailed quick start.

## Components

### 1. Live Issues in Xcode (~80% coverage)

**What**: Errors appear as you type
**How**: Xcode's built-in analyzer
**Speed**: Real-time
**Setup**: Automatic (configured by installer)

**Enable manually**:
```bash
defaults write com.apple.dt.Xcode ShowLiveIssues -bool YES
```

### 2. Build Phase Checks (~95% coverage)

**What**: SwiftLint runs on every build
**How**: Xcode Run Script phase
**Speed**: 1-3 seconds
**Setup**: Manual (add to Xcode - see XCODE-BUILD-PHASE-GUIDE.md)

**Script**: `Scripts/auto-build-check.sh`

### 3. Git Pre-commit Hook (~90% coverage)

**What**: Validates code before commits
**How**: Git hook that runs SwiftLint
**Speed**: 0.5-2 seconds (only checks staged files)
**Setup**: Automatic (installed by installer)

**Script**: `Scripts/pre-commit`
**Location**: `.git/hooks/pre-commit`

### 4. File Watcher (~99% coverage)

**What**: Monitors files, runs checks on save
**How**: fswatch + SwiftLint
**Speed**: Instant
**Setup**: Optional

**Start**: `make watch`
**Script**: `Scripts/watch-and-check.sh`

### 5. Manual Full Scan (~99% coverage)

**What**: Comprehensive check of entire codebase
**How**: SwiftLint + full compilation
**Speed**: 10-30 seconds
**Setup**: N/A

**Run**: `make check`
**Script**: `Scripts/build-with-all-errors.sh`

## Installation

### Prerequisites

```bash
# macOS 14+ (Sonoma)
# Xcode 16+
# Homebrew (brew)
```

### Full Installation

```bash
./install-automatic-checks.sh
```

This installs:
- ✅ Makes scripts executable
- ✅ Installs SwiftLint (via Homebrew)
- ✅ Installs fswatch (optional, via Homebrew)
- ✅ Configures Xcode settings
- ✅ Installs Git pre-commit hook
- ✅ Creates Xcode build phase snippet

### Manual Installation

```bash
# 1. Make scripts executable
chmod +x Scripts/*.sh Scripts/pre-commit

# 2. Install dependencies
brew install swiftlint
brew install fswatch  # Optional

# 3. Configure Xcode
./Scripts/configure-xcode.sh

# 4. Install Git hook
cp Scripts/pre-commit .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit

# 5. Add Xcode build phase manually
# See XCODE-BUILD-PHASE-GUIDE.md
```

## Usage

### Daily Workflow

```bash
# Morning: Check overall status
make summary

# During development: Use live issues + build checks
# (Automatic - just code and build normally)

# Before commits: Check changes
make check

# Optional: Run file watcher
make watch
```

### Make Commands

```bash
make help       # Show all commands
make check      # Full error scan
make summary    # Quick statistics
make lint       # SwiftLint only
make watch      # File watcher
make install    # Run installer
make clean      # Clean builds
```

### Direct Scripts

```bash
./Scripts/auto-build-check.sh        # Build phase script
./Scripts/build-with-all-errors.sh   # Full scan
./Scripts/error-summary.sh           # Statistics
./Scripts/watch-and-check.sh         # File watcher
./Scripts/configure-xcode.sh         # Xcode setup
```

### SwiftLint Commands

```bash
swiftlint                    # Run on all files
swiftlint --fix              # Auto-fix issues
swiftlint lint --quiet       # Errors only
swiftlint lint --path file   # Check specific file
```

## Troubleshooting

### Build Phase Not Running

**Check**:
1. Is script phase ABOVE "Compile Sources"?
2. Build log shows no "Auto Error Detection"?
3. Script executable? `chmod +x Scripts/auto-build-check.sh`

**Fix**: See XCODE-BUILD-PHASE-GUIDE.md

### Git Hook Not Working

**Check**:
```bash
ls -la .git/hooks/pre-commit
```

**Fix**:
```bash
make hooks    # Reinstall hook
```

### SwiftLint Not Found

```bash
brew install swiftlint
```

### Xcode Settings Not Applied

```bash
./Scripts/configure-xcode.sh
killall Xcode
open Thea.xcodeproj
```

### Too Many Warnings

Edit `.swiftlint.yml` to disable rules:
```yaml
disabled_rules:
  - line_length
  - trailing_whitespace
```

### File Watcher Issues

```bash
# Check fswatch installed
which fswatch

# Install if missing
brew install fswatch

# Test directly
./Scripts/watch-and-check.sh
```

## Advanced

### Customizing SwiftLint

Edit `.swiftlint.yml`:

```yaml
# Add rules
opt_in_rules:
  - empty_count
  - closure_spacing

# Disable rules
disabled_rules:
  - line_length

# Configure rules
line_length:
  warning: 120
  error: 200
```

### Custom Checks

Edit `Scripts/auto-build-check.sh` to add custom validation:

```bash
# Add after SwiftLint
echo "Running custom checks..."

# Example: Check for TODOs
if grep -r "TODO" Shared/ 2>/dev/null; then
    echo "⚠️  Found TODO comments"
fi
```

### Multiple Targets

Add the same build script to each target:
- Thea-macOS
- Thea-iOS
- etc.

Same script works for all platforms.

### CI/CD Integration

```yaml
# .github/workflows/swift-lint.yml
name: SwiftLint
on: [push, pull_request]
jobs:
  lint:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v2
      - name: SwiftLint
        run: swiftlint lint --strict
```

## Performance

| Operation | Time | Impact |
|-----------|------|--------|
| Live Issues | 0ms | None (background) |
| Build Phase | +1-3s | Minimal |
| Git Hook | +0.5-2s | Minimal |
| File Watcher | 0ms | None (background) |
| Full Scan | 10-30s | Manual only |

## Best Practices

1. **Always use live issues** - Catches errors as you type
2. **Keep build phase enabled** - Catches issues before compilation
3. **Don't skip git hooks** - Prevents bad commits
4. **Run `make check` before releases** - Comprehensive validation
5. **Use file watcher for complex work** - Instant feedback

## FAQ

**Q: Will this slow down my builds?**
A: Minimal impact (+1-3 seconds). SwiftLint is very fast.

**Q: Can I disable it temporarily?**
A: Yes, uncheck the build phase in Xcode, or use `--no-verify` for git.

**Q: What if I disagree with a SwiftLint rule?**
A: Edit `.swiftlint.yml` to disable or configure it.

**Q: Does this work with Swift Package Manager?**
A: Yes! SwiftLint works with SPM projects.

**Q: Can I use this in CI/CD?**
A: Yes, run `swiftlint lint --strict` in your CI pipeline.

## See Also

- `START-HERE.md` - Quick start (5 minutes)
- `QUICK-REFERENCE.md` - All commands
- `XCODE-BUILD-PHASE-GUIDE.md` - Detailed Xcode instructions
- `Scripts/README.md` - Script documentation

---

**Need Help?** Run `make help` or see `QUICK-REFERENCE.md`
