# THEA Project Guidelines

## Critical: Issue Resolution Policy

**All issues encountered must be fixed systematically.** When working on any task:

1. **Fix discovered issues immediately** - Any errors, warnings, bugs, or inconsistencies found during work (even if unrelated to the current task) must be addressed before completing the task
2. **No "pre-existing" excuses** - Issues cannot be dismissed as "pre-existing" or "unrelated to current changes"
3. **Follow best practices** - All fixes must follow current year's best practices (verify online when needed)
4. **Prevent new issues** - Ensure fixes don't introduce new problems
5. **Verify fixes** - After fixing, rebuild and verify the issue is resolved

This applies to: compilation errors, runtime errors, warnings, linter issues, deprecated APIs, missing dependencies, configuration problems, and any other code quality issues.

## Development Standards

### Research Before Implementation
Before modifying any code, **always verify online the latest best practices** for:
- Swift and SwiftUI (current year standards)
- macOS/iOS native app development patterns
- MLX and on-device ML frameworks (Apple Silicon optimization)
- Relevant platform-specific APIs and conventions

This ensures code quality, performance, and compatibility with the latest platform capabilities.

### Code Quality Requirements
- Follow Apple's Human Interface Guidelines
- Use modern Swift concurrency (async/await, actors)
- Implement proper error handling with descriptive messages
- Write self-documenting code with meaningful names
- Add comments only for complex logic or non-obvious decisions

### Architecture Principles
- Maintain separation of concerns (MVVM pattern)
- Use dependency injection for testability
- Prefer composition over inheritance
- Keep files focused and modular (<500 lines when practical)

### Testing Standards
- Write unit tests for business logic
- Test edge cases and error conditions
- Verify UI behavior on different screen sizes

## Project-Specific Notes

### MLX Integration
- Use mlx-swift and mlx-swift-lm for on-device inference
- Leverage ChatSession for multi-turn conversations with KV cache
- Apply proper chat templates via ChatSession (never raw prompts)

### Orchestrator System
- TaskClassifier: Classifies queries by type (code, math, creative, etc.)
- ModelRouter: Routes to optimal model based on task and preferences
- QueryDecomposer: Breaks complex queries into sub-tasks
- All components should log decisions when debugging is enabled

### Local Models
- Located in ~/.cache/huggingface/hub/
- Use ModelConfiguration(directory:) for local paths
- Support dynamic model selection based on task complexity
