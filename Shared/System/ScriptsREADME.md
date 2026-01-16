# Error Detection Scripts

This directory contains scripts to help you catch all errors and warnings at once, minimizing the build-fix-build cycle.

## Quick Start

### 1. Configure Xcode (Run Once)
```bash
chmod +x Scripts/configure-xcode.sh
./Scripts/configure-xcode.sh
```
Then restart Xcode.

### 2. Check All Errors
```bash
chmod +x Scripts/build-with-all-errors.sh
./Scripts/build-with-all-errors.sh
```

### 3. Get Error Summary
```bash
chmod +x Scripts/error-summary.sh
./Scripts/error-summary.sh
```

## Available Scripts

### `configure-xcode.sh` ⚙️
Configures Xcode for optimal error detection:
- Enables live issues (errors shown as you type)
- Enables parallel compilation
- Auto-shows issue navigator on build failure
- Optimizes indexing

**Usage:** Run once, then restart Xcode
```bash
./Scripts/configure-xcode.sh
```

### `build-with-all-errors.sh` 🔍
Attempts to show all errors across all files in one go using Swift's `-continue-building-after-errors` flag.

**Usage:**
```bash
./Scripts/build-with-all-errors.sh
```

**Output:** 
- Console display of all errors
- Saved report file with timestamp

### `error-summary.sh` 📊
Provides a quick summary of errors grouped by type.

**Usage:**
```bash
./Scripts/error-summary.sh
```

**Shows:**
- Count of each error type
- Top 20 most common errors
- Top 20 most common warnings

### `watch-and-check.sh` 👀
Continuously watches for file changes and type-checks automatically.

**Requirements:** 
```bash
brew install fswatch
```

**Usage:**
```bash
./Scripts/watch-and-check.sh
```

Press Ctrl+C to stop.

### `xcode-build-phase.sh` 🎯
Script to add to Xcode Build Phases for enhanced compile-time checking.

**Setup:**
1. Open your Xcode project
2. Select your target
3. Go to "Build Phases"
4. Click "+" → "New Run Script Phase"
5. Copy content from this file
6. Drag it to run before "Compile Sources"

## SwiftLint Integration

If you have SwiftLint installed, it will automatically check your code:

```bash
brew install swiftlint
```

Configuration is in `.swiftlint.yml` at the project root.

## Recommended Workflow

### Daily Development:
1. Enable "Show Live Issues" in Xcode (already configured)
2. Run `watch-and-check.sh` in a terminal while coding
3. Check Xcode's Issue Navigator (⌘+5) frequently

### Before Committing:
```bash
# Quick check
./Scripts/error-summary.sh

# Full check
./Scripts/build-with-all-errors.sh
```

### When Fixing Many Errors:
1. Run `build-with-all-errors.sh` to see all issues
2. Fix errors from top to bottom in the generated report
3. Re-run to verify

## Keyboard Shortcuts

Add these to Xcode (Preferences → Key Bindings):

- **⌘+5**: Show Issue Navigator
- **⌘+B**: Build
- **⌘+Shift+K**: Clean Build Folder
- **⌘+Shift+B**: Analyze

## Tips

1. **Fix structural errors first** (syntax, missing imports)
2. **Then fix type errors**
3. **Then fix warnings**
4. **Use the Issue Navigator** (⌘+5) to see all issues at once
5. **Build frequently** - don't wait until you have hundreds of errors

## Troubleshooting

### Scripts don't have permission
```bash
chmod +x Scripts/*.sh
```

### fswatch not found
```bash
brew install fswatch
```

### SwiftLint not found
```bash
brew install swiftlint
```

### Too many errors shown
Adjust the `-continue-building-after-errors` behavior or focus on one module at a time.

## Advanced Configuration

### Adjust Parallel Build Tasks
Edit `configure-xcode.sh` and change this line:
```bash
defaults write com.apple.dt.Xcode IDEBuildOperationMaxNumberOfConcurrentCompileTasks 8
```

Use `sysctl -n hw.ncpu` to see your CPU core count.

### Custom SwiftLint Rules
Edit `.swiftlint.yml` to add your own rules.

## Files

- `configure-xcode.sh` - One-time Xcode setup
- `build-with-all-errors.sh` - Show all errors at once
- `error-summary.sh` - Quick error statistics
- `watch-and-check.sh` - Continuous type checking
- `xcode-build-phase.sh` - Xcode build phase template
- `../.swiftlint.yml` - SwiftLint configuration

---

**Note:** While these scripts help catch more errors at once, Swift's type system means some errors can only be discovered after fixing earlier ones. These tools minimize but don't completely eliminate iterative building.
