# THEA Project

## CRITICAL SAFETY RULES

### ⚠️ MANDATORY: Commit After Every Edit

**This rule is NON-NEGOTIABLE and must be followed WITHOUT EXCEPTION:**

1. **After EVERY file edit** (create, modify, delete), immediately run:
   ```bash
   cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea"
   git add -A && git commit -m "Auto-save: <brief description of change>"
   ```

2. **Before ANY destructive command** (rm, clean, reset), ALWAYS commit first:
   ```bash
   git add -A && git commit -m "Checkpoint before cleanup"
   ```

3. **Push to remote regularly** (at minimum every 5 commits):
   ```bash
   git push origin main
   ```

### 🚫 FORBIDDEN Commands

**NEVER execute these commands under ANY circumstances:**

- `rm -rf` with wildcards (`*`) in ANY path
- `rm -rf ~/` or `rm -rf /`
- `rm -rf` on parent directories of the project
- `git clean -fdx` without explicit user confirmation
- `git reset --hard` without explicit user confirmation
- Any command that could delete the project directory

### ✅ Safe DerivedData Cleanup

**When cleaning Xcode DerivedData, ONLY use this exact command:**
```bash
# First, commit current state
cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea" && git add -A && git commit -m "Checkpoint before DerivedData cleanup" || true

# Then clean ONLY Thea-specific DerivedData (safe pattern)
find ~/Library/Developer/Xcode/DerivedData -maxdepth 1 -name "Thea-*" -type d -exec rm -rf {} + 2>/dev/null || true
```

**NEVER use:** `rm -rf ~/Library/Developer/Xcode/DerivedData/*`

---

## AI Behavior Guidelines

**IMPORTANT: For every task or instruction:**
1. **Research First** - Before implementing, perform qualitative web research for:
   - Current year's best practices for the relevant technology/framework
   - Common pitfalls and recommended solutions
   - Performance optimizations and security considerations
2. **Suggest Improvements** - Proactively offer pertinent recommendations based on research
3. **Verify Approach** - Cross-reference with official documentation when available

## Quick Reference

| Command | Description |
|---------|-------------|
| `xcodegen generate` | Regenerate Xcode project from project.yml |
| `swift test` | Run all 47 tests (~1 second) |
| `swift build` | Build Swift packages |
| `swiftlint lint` | Check code style |

## Build Commands

```bash
# macOS
xcodebuild -project Thea.xcodeproj -scheme Thea-macOS -destination "platform=macOS" build

# iOS
xcodebuild -project Thea.xcodeproj -scheme Thea-iOS -destination "generic/platform=iOS" build

# All platforms (Debug)
for scheme in Thea-macOS Thea-iOS Thea-watchOS Thea-tvOS; do
  xcodebuild -project Thea.xcodeproj -scheme "$scheme" -configuration Debug build
done
```

## Project Facts

- **Swift 6.0** with strict concurrency (actors, async/await)
- **XcodeGen** generates project from `project.yml`
- **Schemes**: Thea-macOS, Thea-iOS, Thea-watchOS, Thea-tvOS
- **Local models**: `~/.cache/huggingface/hub/`
- **Architecture**: MVVM with SwiftUI + SwiftData
- **Remote**: `https://github.com/Atchoum23/Thea.git`

## Orchestrator System

- **TaskClassifier**: Classifies queries (code, math, creative, etc.)
- **ModelRouter**: Routes to optimal model based on task
- **QueryDecomposer**: Breaks complex queries into sub-tasks

## Architecture Decision: MetaAI vs Intelligence (2026-02-07)

**IMPORTANT: The `Shared/AI/MetaAI/` folder is EXCLUDED from all builds.**

The Intelligence folder (`Shared/Intelligence/`) is the **canonical source** for AI orchestration:
- `Intelligence/Core/` - Core intelligence hub
- `Intelligence/Intent/` - Intent classification and disambiguation
- `Intelligence/Knowledge/` - Knowledge source management
- `Intelligence/Orchestration/` - Orchestrator implementation

**Why MetaAI is excluded:**
1. MetaAI and Intelligence had duplicate type definitions causing build conflicts
2. Intelligence folder has cleaner separation of concerns
3. Intelligence uses protocol-based design patterns

**If you need to re-enable MetaAI files:**
1. Check for type conflicts with Intelligence folder first
2. Rename conflicting types with `MetaAI` prefix (e.g., `MetaAIMCPServerInfo`)
3. Remove specific exclusions in `project.yml` rather than the blanket exclusion
4. Types already renamed: `MetaAIMCPServerInfo`, `AIErrorContext`, `ModelCapabilityRecord`, `ReActActionResult`, `HypothesisEvidence`

**DO NOT remove the MetaAI blanket exclusion without resolving all type conflicts.**

## MLX Integration

- Use `mlx-swift` and `mlx-swift-lm` for on-device inference
- Use `ChatSession` for multi-turn conversations (has KV cache)
- IMPORTANT: Never use raw prompts - always apply chat templates via ChatSession

## Gotchas

- IMPORTANT: Run `xcodegen generate` after ANY change to `project.yml`
- IMPORTANT: All 4 platform schemes must build with 0 errors, 0 warnings
- Swift Package tests are 60x faster than Xcode tests - prefer `swift test`
- App groups must use `group.app.theathe` consistently across all targets

## QA After Major Changes

Execute: `Read .claude/COMPREHENSIVE_QA_PLAN.md and run all phases`

See @.claude/COMPREHENSIVE_QA_PLAN.md for the full checklist.

## After Every Session

**IMPORTANT: Always commit and sync before ending:**
```bash
cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea"
git add -A && git status
# If changes exist, commit with descriptive message
git push origin main  # Only if user requests
```
