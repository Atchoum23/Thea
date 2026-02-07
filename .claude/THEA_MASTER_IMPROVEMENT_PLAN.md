# Thea Master Improvement Plan

**Created:** February 7, 2026
**Purpose:** Comprehensive analysis of Thea — its codebase, architecture, purposes, intents — identifying all shortcomings and deficiencies, with actionable roadmap to make everything production-grade.
**Execution:** Work through each section sequentially. After all improvements, run `COMPREHENSIVE_QA_PLAN.md` for validation.

---

## Table of Contents

1. [Project Analysis](#1-project-analysis)
2. [Architecture Audit](#2-architecture-audit)
3. [Code Quality Deficiencies](#3-code-quality-deficiencies)
4. [CI/CD Pipeline Repair](#4-cicd-pipeline-repair)
5. [Build System Hardening](#5-build-system-hardening)
6. [Feature Completeness Gap Analysis](#6-feature-completeness-gap-analysis)
7. [Security Posture](#7-security-posture)
8. [Performance Optimization](#8-performance-optimization)
9. [UI/UX Polish](#9-uiux-polish)
10. [Testing Strategy Gaps](#10-testing-strategy-gaps)
11. [Documentation & Developer Experience](#11-documentation--developer-experience)
12. [Multi-Platform Parity](#12-multi-platform-parity)
13. [Compliance & App Store Readiness](#13-compliance--app-store-readiness)
14. [Prioritized Execution Roadmap](#14-prioritized-execution-roadmap)
15. [Validation: Run QA Plan](#15-validation-run-qa-plan)

---

## 1. Project Analysis

### What is Thea?
Thea is a **multi-platform AI assistant application** built with SwiftUI + SwiftData across macOS, iOS, watchOS, and tvOS. It features:
- Local on-device AI inference via MLX (Llama 3.3 70B, Qwen 32B, DeepSeek R1, etc.)
- Cloud AI provider integration (OpenAI, Anthropic)
- Intelligent orchestration system (TaskClassifier → ModelRouter → QueryDecomposer)
- Safari web extension
- Chrome browser extension
- Multi-device sync via CloudKit
- Knowledge management system
- Security audit tooling (`thea-audit`)

### Core Architecture
- **Pattern:** MVVM with SwiftUI + SwiftData
- **Language:** Swift 6.0 with strict concurrency (`complete`)
- **Project Generation:** XcodeGen from `project.yml`
- **Platforms:** macOS, iOS, watchOS, tvOS (4 schemes)
- **Package Manager:** Swift Package Manager
- **CI/CD:** GitHub Actions (6 workflows)
- **Multi-Mac Sync:** `git pushsync` → SSH-triggered rebuild on second Mac

### Project Intent
Thea aims to be a **privacy-first, on-device AI assistant** that can:
1. Run large language models locally (no cloud dependency for basic tasks)
2. Route intelligently between local and cloud models based on task complexity
3. Provide a polished, native Apple experience across all platforms
4. Integrate deeply with the user's workflow (Safari, Chrome, system-wide)

---

## 2. Architecture Audit

### Strengths
- Clean MVVM separation with SwiftUI
- Protocol-based Intelligence system (good extensibility)
- Swift 6 strict concurrency from day one (forward-looking)
- XcodeGen ensures reproducible project files
- Comprehensive CI/CD pipeline (6 workflows)

### Shortcomings

#### 2.1 MetaAI / Intelligence Duplication
**Status:** MetaAI folder is excluded from all builds due to type conflicts with Intelligence.
**Problem:** Dead code in the repository. Increases confusion, repo size, and grep noise.
**Fix:**
- [ ] Audit MetaAI for any unique functionality not in Intelligence
- [ ] Migrate any unique pieces to Intelligence
- [ ] Delete MetaAI folder entirely (or archive to a branch)
- [ ] Remove MetaAI exclusions from `project.yml`

#### 2.2 File Length Violations
**Problem:** Some files likely exceed the 500-line guideline from CLAUDE.md.
**Fix:**
- [ ] Run file length audit: `find Shared -name "*.swift" -exec wc -l {} + | sort -rn | head -20`
- [ ] Split files exceeding 500 lines using extensions or separate types
- [ ] Ensure each file has a single clear responsibility

#### 2.3 Unused Code / Dead Imports
**Problem:** Rapid development accumulates unused imports, variables, and dead code paths.
**Fix:**
- [ ] Run Periphery (dead code detection): `brew install periphery && periphery scan`
- [ ] Remove all unused imports, types, and functions
- [ ] Verify builds still pass after cleanup

#### 2.4 Dependency Health
**Problem:** Third-party dependencies may have newer major versions or security patches.
**Fix:**
- [ ] Audit Package.resolved for outdated packages
- [ ] Check for deprecated APIs in dependencies
- [ ] Update to latest compatible versions
- [ ] Run `osv-scanner --lockfile Package.resolved`

---

## 3. Code Quality Deficiencies

### 3.1 SwiftLint Configuration
**Current state:** 111 warnings were auto-fixed in the last QA run. Many were `redundant_string_enum_value`.
**Problem:** The SwiftLint config may not be strict enough, allowing patterns to accumulate.
**Fix:**
- [ ] Review `.swiftlint.yml` — enable stricter rules:
  - `force_cast`, `force_try`, `force_unwrapping` → error level
  - `cyclomatic_complexity` → warning at 10, error at 20
  - `function_body_length` → warning at 50, error at 100
  - `type_body_length` → warning at 300, error at 500
- [ ] Add `--strict` flag to CI SwiftLint step
- [ ] Consider adding SwiftFormat for consistent style

### 3.2 Swift 6 Concurrency Compliance
**Current state:** Strict concurrency is enabled, but `@unchecked Sendable` and `nonisolated(unsafe)` may be overused as escape hatches.
**Fix:**
- [ ] Audit all uses of `@unchecked Sendable` — replace with proper actor isolation where possible
- [ ] Audit all uses of `nonisolated(unsafe)` — minimize to truly safe cases only
- [ ] Verify no data races with Thread Sanitizer under real usage patterns
- [ ] Document each remaining `@unchecked` usage with justification comment

### 3.3 Error Handling
**Problem:** Error handling patterns may be inconsistent (some `try?`, some `do/catch`, some `Result`).
**Fix:**
- [ ] Establish canonical error handling pattern (prefer `async throws` with typed errors)
- [ ] Replace `try?` silent failures with proper error propagation
- [ ] Ensure all user-facing errors have clear, actionable messages
- [ ] Add error telemetry/logging for debugging

### 3.4 Test Coverage
**Current state:** 47 tests in Swift Package, no Xcode test targets, no E2E tests passing.
**Fix:**
- [ ] Measure code coverage: `swift test --enable-code-coverage`
- [ ] Target >60% coverage for core modules (Intelligence, Orchestration)
- [ ] Add integration tests for AI provider connectivity
- [ ] Add snapshot tests for critical UI views
- [ ] Fix Maestro E2E tests (currently broken — see Section 4)

---

## 4. CI/CD Pipeline Repair

**This is the most urgent section. As of 2026-02-07, 3 out of 4 active workflows are failing.**

### 4.1 CI Workflow (`ci.yml`) — macOS Build Timeout
**Symptom:** CI #190 cancelled after 31m 13s. macOS Release build hit timeout at 29m 25s.
**Root Cause:** Release macOS build with Whole Module Optimization takes too long on GitHub runner.
**Fixes:**
- [ ] Add explicit `timeout-minutes: 60` to the Build job
- [ ] Enable DerivedData caching more aggressively (cache key by SPM resolved hash)
- [ ] Consider splitting macOS Release into its own job with longer timeout
- [ ] Add `SWIFT_COMPILATION_MODE=wholemodule` only for Release, use `incremental` for Debug
- [ ] Investigate if `ONLY_ACTIVE_ARCH=YES` can be used in CI for non-archive builds

### 4.2 E2E Tests Workflow (`e2e-tests.yml`) — App Path Mismatch
**Symptom:** Every run fails: `Thea.app not found in build directory`
**Root Cause:** Build uses `-derivedDataPath build` and the verify step does `find build -name "Thea.app" -type d | head -1`. The .app bundle is at `build/Build/Products/Debug-iphonesimulator/Thea.app` but `find` may not reach it.
**Fixes:**
- [ ] Fix the verify step: `find build -name "Thea.app" -type d -path "*Products*" | head -1`
- [ ] Or use explicit path: `build/Build/Products/Debug-iphonesimulator/Thea.app`
- [ ] Add debug logging: `find build -type d -name "*.app"` before the verify step
- [ ] Verify Maestro test flows are still valid for current UI
- [ ] Add retry logic to simulator app installation

### 4.3 Security Audit Workflow (`thea-audit-main.yml`) — Swift Compiler Crash
**Symptom:** `swift-frontend` segfault during `Build thea-audit`: `could not build Objective-C module '_Builtin_float'`
**Root Cause:** The `thea-audit` Swift package builds with Swift 6.0.3 from GitHub's hostedtoolcache, which is incompatible with Xcode 26.2's SDK headers.
**Fixes:**
- [ ] Use `xcrun swift build` instead of bare `swift build` to use Xcode's bundled toolchain
- [ ] Or add `TOOLCHAINS=com.apple.dt.toolchain.XcodeDefault` environment variable
- [ ] Verify `thea-audit` builds locally with the same Swift version as CI
- [ ] Add Swift version logging step: `swift --version && xcrun swift --version`

### 4.4 GitHub CLI Authentication
**Problem:** `gh auth` token expired, preventing CI monitoring from Claude Code.
**Fix:**
- [ ] Re-authenticate: `gh auth login -h github.com`
- [ ] Use a PAT with `repo` and `workflow` scopes for longer-lived auth
- [ ] Add `gh auth status` check to Phase 0 (Environment Gate)

### 4.5 Missing Workflows
**Problem:** The `AUTONOMOUS_BUILD_QA.md` references 6 workflows, but Dependencies workflow may not trigger consistently.
**Fix:**
- [ ] Verify all 6 workflow files exist and have correct triggers
- [ ] Add manual dispatch triggers (`workflow_dispatch`) to all workflows for testing
- [ ] Create a meta-workflow or dashboard that shows all workflow statuses

---

## 5. Build System Hardening

### 5.1 iCloud DerivedData Conflict
**Problem:** Project in `~/Documents` (iCloud-synced) causes codesign failures with extended attributes.
**Current workaround:** Use `-derivedDataPath /tmp/TheaBuild` for CLI builds.
**Better fix:**
- [ ] Add `-derivedDataPath /tmp/TheaBuild` to ALL build scripts consistently
- [ ] Or move project out of iCloud-synced folder (to `~/Developer/Thea`)
- [ ] Document this in CLAUDE.md prominently

### 5.2 XcodeGen Fragility
**Problem:** Any change to `project.yml` requires `xcodegen generate`. Forgetting this causes build failures.
**Fix:**
- [ ] Add a pre-build script or Git hook that auto-runs `xcodegen generate` when `project.yml` changes
- [ ] Or add a CI step that verifies `project.yml` matches the checked-in `.xcodeproj`

### 5.3 Package Resolution Reliability
**Problem:** SPM cache corruption causes "Missing package product" errors.
**Fix:**
- [ ] Add `swift package resolve` to CI before builds
- [ ] Add package cache to GitHub Actions cache with proper invalidation keys
- [ ] Document the clean-resolve procedure in CLAUDE.md

---

## 6. Feature Completeness Gap Analysis

### 6.1 Intelligence System
- [ ] Verify TaskClassifier produces correct classifications for edge cases
- [ ] Test ModelRouter fallback behavior when preferred model is unavailable
- [ ] Test QueryDecomposer with complex multi-step queries
- [ ] Add telemetry for classification accuracy

### 6.2 MLX On-Device Inference
- [ ] Verify ChatSession KV cache works correctly across conversation turns
- [ ] Test model loading/unloading under memory pressure
- [ ] Add model download progress UI
- [ ] Handle model corruption gracefully (re-download)
- [ ] Verify chat templates are applied correctly for all supported models

### 6.3 Cloud Provider Integration
- [ ] Test OpenAI API integration with streaming responses
- [ ] Test Anthropic API integration with streaming responses
- [ ] Handle API key rotation gracefully
- [ ] Add rate limiting and retry logic with exponential backoff
- [ ] Handle API deprecation warnings

### 6.4 Safari Extension
- [ ] Verify extension works on current macOS/Safari versions
- [ ] Fix duplicate Launch Services registrations (documented in MEMORY.md)
- [ ] Test extension icon rendering at all required sizes
- [ ] Test extension-to-app communication

### 6.5 Chrome Extension
- [ ] Verify Chrome extension manifest v3 compliance
- [ ] Test extension communication with native app
- [ ] Handle Chrome updates gracefully

### 6.6 Multi-Device Sync
- [ ] Test CloudKit sync conflict resolution
- [ ] Test sync under poor network conditions
- [ ] Verify app group container (`group.app.theathe`) works across all targets
- [ ] Test data migration between app versions

---

## 7. Security Posture

### 7.1 API Key Storage
- [ ] Audit Keychain usage — ensure all API keys use Keychain, never UserDefaults
- [ ] Verify no API keys in source code (gitleaks)
- [ ] Test Keychain access after app reinstall
- [ ] Add Keychain error handling (locked keychain, denied access)

### 7.2 Network Security
- [ ] Verify all API calls use HTTPS with certificate pinning (for critical endpoints)
- [ ] Audit App Transport Security settings
- [ ] Test behavior under MITM proxy (should fail gracefully)

### 7.3 Data Privacy
- [ ] Audit what data is sent to cloud providers — ensure no PII leakage
- [ ] Verify local model inference truly stays local
- [ ] Add privacy manifest (`PrivacyInfo.xcprivacy`) for App Store compliance
- [ ] Document data handling in privacy policy

### 7.4 thea-audit Tool
- [ ] Fix thea-audit build on CI (Section 4.3)
- [ ] Run thea-audit locally and address all findings
- [ ] Integrate thea-audit into pre-commit hook (optional, for critical findings)

---

## 8. Performance Optimization

### 8.1 App Launch Time
- [ ] Profile launch time with Instruments (Time Profiler)
- [ ] Defer non-critical initialization (model loading, sync checks)
- [ ] Target <1s cold launch on macOS, <2s on iOS

### 8.2 Memory Usage
- [ ] Profile memory with Instruments (Allocations)
- [ ] Verify no memory leaks (`leaks` tool)
- [ ] Test under memory pressure (simulate on iOS)
- [ ] Ensure models are unloaded when backgrounded on iOS

### 8.3 Build Performance
- [ ] Identify slow-compiling files: `xcodebuild -buildTimingSummary`
- [ ] Split large files that cause long compilation
- [ ] Optimize generic usage that causes type-checker slowdowns

### 8.4 CI/CD Performance
- [ ] Optimize GitHub Actions cache usage (SPM, DerivedData, XcodeGen)
- [ ] Parallelize independent CI jobs
- [ ] Consider self-hosted runners for faster macOS builds (eliminates timeout issues)

---

## 9. UI/UX Polish

**Reference:** See `.claude/UI_UX_IMPLEMENTATION_PLAN.md` for the detailed view-by-view enhancement plan.

### Critical Items
- [ ] Markdown rendering quality (MarkdownUI integration)
- [ ] Code syntax highlighting (Highlightr integration)
- [ ] Streaming response indicators
- [ ] Conversation branching support
- [ ] Keyboard shortcuts (power user workflow)
- [ ] Dark/light mode consistency across all views
- [ ] Accessibility audit (VoiceOver, Dynamic Type)
- [ ] Localization readiness (even if not shipping L10n yet)

### Platform-Specific
- [ ] macOS: Liquid Glass design compliance (see APRIL_2026_COMPLIANCE.md)
- [ ] iOS: Responsive layout for all device sizes
- [ ] watchOS: Minimal viable interaction (voice query, quick answers)
- [ ] tvOS: Focus-driven navigation

---

## 10. Testing Strategy Gaps

### Current State
- **47 Swift Package tests** — passing, fast (<1s)
- **0 Xcode test targets** — no XCTest integration tests
- **0 passing E2E tests** — Maestro workflow broken
- **0 UI tests** — no XCUITest

### Required Additions
- [ ] **Integration tests:** Test Intelligence orchestration end-to-end (mock providers)
- [ ] **UI tests (XCUITest):** Critical user flows (send message, switch model, settings)
- [ ] **E2E tests (Maestro):** Fix workflow, add smoke test for app launch + basic chat
- [ ] **Snapshot tests:** Key views (chat bubble, settings, model selector)
- [ ] **Performance tests:** Measure and regress on launch time, memory, response latency
- [ ] **Fuzz testing:** Malformed API responses, corrupt model files, invalid user input

---

## 11. Documentation & Developer Experience

### 11.1 README.md
- [ ] Verify README accurately describes current features
- [ ] Add setup instructions for new contributors
- [ ] Add architecture diagram
- [ ] Add screenshot/demo GIF

### 11.2 Inline Documentation
- [ ] Add doc comments (`///`) to all public types and methods
- [ ] Add `MARK:` sections to large files
- [ ] Document non-obvious architectural decisions inline

### 11.3 .claude/ Documentation
- [ ] Consolidate overlapping docs (AUTONOMOUS_BUILD_QA.md vs COMPREHENSIVE_QA_PLAN.md vs XCODE_BUILD_FIX_MODUS_OPERANDI.md share significant content)
- [ ] Create a single QUICKSTART.md for common operations
- [ ] Keep CLAUDE.md as the authoritative reference, with other docs as specialized addenda

### 11.4 Developer Tooling
- [ ] Add `Makefile` or `justfile` with common commands (`make build`, `make test`, `make lint`)
- [ ] Add pre-commit hooks for SwiftLint
- [ ] Add commit message format enforcement (conventional commits)

---

## 12. Multi-Platform Parity

### Feature Matrix (Current)

| Feature | macOS | iOS | watchOS | tvOS |
|---------|-------|-----|---------|------|
| Chat UI | ✓ | ✓ | ? | ? |
| Local MLX | ✓ (M3U) | ✗ | ✗ | ✗ |
| Cloud AI | ✓ | ✓ | ? | ? |
| Safari Ext | ✓ | ✗ | N/A | N/A |
| Chrome Ext | ✓ | ✗ | N/A | N/A |
| Widgets | ✗ (excl.) | ✓ | ✓ | ✗ |
| Sync | ✓ | ✓ | ? | ? |

### Gaps
- [ ] Verify watchOS and tvOS have meaningful UIs (not just stub views)
- [ ] Ensure shared code compiles correctly with platform-conditional compilation
- [ ] Widgets excluded from macOS — evaluate if this is intentional
- [ ] Test actual user experience on each platform (not just "builds clean")

---

## 13. Compliance & App Store Readiness

**Reference:** See `.claude/APRIL_2026_COMPLIANCE.md` for the detailed checklist.

### Requirements
- [ ] Built with Xcode 26 / watchOS 26 SDK (April 2026 deadline)
- [ ] Liquid Glass design audit
- [ ] Privacy manifest (`PrivacyInfo.xcprivacy`)
- [ ] App Store screenshots for all required device sizes
- [ ] App Store description and metadata
- [ ] Entitlements audit (remove development-only entitlements)
- [ ] Code signing configuration for distribution
- [ ] TestFlight beta testing before submission

---

## 14. Prioritized Execution Roadmap

### Priority 1: CRITICAL (Do First — Blocking CI/CD)
1. **Fix E2E Tests workflow** — app path mismatch in `e2e-tests.yml`
2. **Fix CI workflow** — increase macOS build timeout
3. **Fix Security Audit workflow** — Swift toolchain mismatch
4. **Re-authenticate `gh` CLI** — enables CI monitoring
5. **Run all fixes through QA plan** — verify green CI

### Priority 2: HIGH (Code Health)
6. Clean up MetaAI dead code
7. Audit and fix `@unchecked Sendable` usage
8. Run Periphery dead code detection
9. Increase test coverage (target 60%)
10. Fix Maestro E2E tests

### Priority 3: MEDIUM (Quality & UX)
11. SwiftLint strictness increase
12. UI/UX improvements (see UI_UX_IMPLEMENTATION_PLAN.md)
13. Performance profiling and optimization
14. Accessibility audit
15. Documentation consolidation

### Priority 4: STANDARD (App Store Prep)
16. April 2026 compliance items
17. Privacy manifest
18. Code signing for distribution
19. TestFlight beta
20. App Store submission

---

## 15. Validation: Run QA Plan

**After completing improvements from this plan, execute the QA plan for full validation:**

```
Read .claude/COMPREHENSIVE_QA_PLAN.md and execute autonomously.
Loop through all phases (0 → 11.5) until ALL success criteria are met.
Fix any issues found. Do not stop until completion.
ALL 6 GitHub Actions workflows must be GREEN.
ALL 16 builds must pass (4 platforms × 2 configs × CLI + GUI).
```

**The mission is NOT complete until:**
1. All 16 builds pass with 0 warnings (CLI + GUI)
2. All 47+ tests pass
3. All 6 GitHub Actions workflows are GREEN
4. All security audits pass
5. E2E tests pass
6. Memory leak check clean

**Reference:** `.claude/COMPREHENSIVE_QA_PLAN.md` v3.0

---

## Appendix: Related Documentation

| Document | Purpose |
|----------|---------|
| `.claude/CLAUDE.md` | Project facts, commands, gotchas |
| `.claude/COMPREHENSIVE_QA_PLAN.md` | Autonomous QA execution (Phases 0–11.5) |
| `.claude/AUTONOMOUS_BUILD_QA.md` | Full 16-build guide (CLI + GUI) |
| `.claude/XCODE_BUILD_FIX_MODUS_OPERANDI.md` | Build error diagnosis & fix patterns |
| `.claude/UI_UX_IMPLEMENTATION_PLAN.md` | View-by-view UI/UX enhancement plan |
| `.claude/APRIL_2026_COMPLIANCE.md` | April 2026 App Store deadline items |
| `.claude/COMPREHENSIVE_QA_STRATEGY.md` | QA strategy details |

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | Feb 07, 2026 | Initial comprehensive analysis covering all 15 sections |
