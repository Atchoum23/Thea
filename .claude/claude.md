# THEA Project

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

## Orchestrator System

- **TaskClassifier**: Classifies queries (code, math, creative, etc.)
- **ModelRouter**: Routes to optimal model based on task
- **QueryDecomposer**: Breaks complex queries into sub-tasks

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
