# Scripts Directory

Automatic error detection scripts for Thea project.

## 📁 Scripts Overview

### Automatic Scripts (Run Automatically)

| Script | When It Runs | Purpose |
|--------|--------------|---------|
| `auto-build-check.sh` | Every Xcode build (⌘+B) | Runs SwiftLint during compilation |
| `pre-commit` | Every Git commit | Validates code before committing |

### Configuration Scripts (Run Once)

| Script | Usage | Purpose |
|--------|-------|---------|
| `configure-xcode.sh` | `./Scripts/configure-xcode.sh` | Enables live issues & parallel builds |

### Manual Scripts (Run On Demand)

| Script | Usage | Purpose |
|--------|-------|---------|
| `build-with-all-errors.sh` | `make check` | Full error scan |
| `error-summary.sh` | `make summary` | Quick error statistics |
| `watch-and-check.sh` | `make watch` | Continuous file monitoring |

## 🚀 Quick Start

1. **Make scripts executable** (done automatically by installer):
   ```bash
   chmod +x Scripts/*.sh Scripts/pre-commit
   ```

2. **Configure Xcode settings**:
   ```bash
   ./Scripts/configure-xcode.sh
   ```

3. **Install Git hook**:
   ```bash
   cp Scripts/pre-commit .git/hooks/pre-commit
   chmod +x .git/hooks/pre-commit
   ```

4. **Add Xcode Build Phase** (manual step in Xcode):
   - See `XCODE-BUILD-PHASE-GUIDE.md` for instructions

## 📋 Script Details

### auto-build-check.sh
- Runs during Xcode build phase
- Executes SwiftLint on all files
- Fails build if errors found
- Shows colored output in build log

### pre-commit
- Git hook that runs before commits
- Checks only staged Swift files
- Fast (only validates changed files)
- Can be bypassed with `--no-verify`

### configure-xcode.sh
- Enables live issues (errors as you type)
- Enables parallel compilation
- Shows build timing
- Run once after cloning project

### build-with-all-errors.sh
- Comprehensive scan of entire codebase
- Runs SwiftLint + full compilation
- Shows all errors at once
- Use for pre-release checks

### error-summary.sh
- Quick statistics dashboard
- Shows error/warning counts
- Code quality rating
- Useful for daily status check

### watch-and-check.sh
- Monitors files for changes
- Runs checks automatically on save
- Background process
- Requires `fswatch` (brew install fswatch)

## 🔧 Requirements

- **SwiftLint**: `brew install swiftlint`
- **fswatch** (optional, for watcher): `brew install fswatch`
- **Xcode**: 16.0 or later
- **Git**: For pre-commit hooks

## 📚 See Also

- `../QUICK-REFERENCE.md` - All commands with examples
- `../XCODE-BUILD-PHASE-GUIDE.md` - Xcode setup instructions
- `../AUTO-ERROR-DETECTION-COMPLETE-GUIDE.md` - Full documentation
