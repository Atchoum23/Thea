# Changelog

All notable changes to THEA will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.4.1] - 2026-01-21

### Security - Red Hat Security Audit (Adversarial Review)
Comprehensive adversarial security review identified and fixed multiple injection vulnerabilities.

#### CRITICAL Fixes
- **AppleScript Injection (TerminalIntegration)** - Fixed command injection via malicious input in Terminal commands; added proper escaping and validation
- **AppleScript Injection (MailIntegration)** - Fixed path injection in email attachments; added validation and proper AppleScript escaping
- **JavaScript Injection (BrowserAutomationService)** - Fixed XSS-style injection in form filling; now uses JSON-encoded parameters
- **Command Injection (XcodeIntegration)** - Fixed shell command injection in xcodebuild; now uses Process with arguments array instead of shell strings
- **Command Injection (ShortcutsIntegration)** - Fixed command injection via shortcut names; now uses Process with arguments array

#### HIGH Fixes
- **WebView File Access** - Disabled `allowFileAccessFromFileURLs` which allowed JavaScript to read local files
- **API Key Exposure** - Moved API keys from URL query parameters to HTTP headers in NutritionService
- **Path Traversal (FolderAccessManager)** - Fixed path validation to use component comparison instead of string prefix matching; prevents `/allowed/../etc/passwd` style attacks

#### Security Improvements
- Added `securityError` and `invalidPath` error cases to `AppIntegrationModuleError`
- All shell command execution now uses `Process` with arguments array (prevents injection)
- All AppleScript string interpolation now uses proper escaping functions
- All path validation now resolves symlinks and uses canonical path comparison

### Changed
- WebView configuration now restricts JavaScript window opening
- Added input validation for scheme names, configuration names, and email addresses

## [1.4.0] - 2026-01-21

### Security - Comprehensive Security Audit Fixes
- **CRITICAL: QA Token Exposure** - Fixed tokens being passed as command-line arguments; now use environment variables (CODECOV_TOKEN, SONAR_TOKEN)
- **HIGH: API Key Storage** - Migrated all API keys from UserDefaults to Keychain via SecureStorage
- **HIGH: Weak Encryption** - Replaced XOR encryption in ActivityLogger with AES-GCM (CryptoKit)
- **HIGH: Hardcoded Paths** - Removed all developer hardcoded paths; created ProjectPathManager for centralized path resolution
- **MEDIUM: Path Traversal** - Added comprehensive path traversal validation in FileCreator to prevent directory escape attacks
- **MEDIUM: Terminal Security** - Strengthened default security policy: sudo disabled by default, added blocked patterns for reverse shells/cryptominers/data exfiltration

### Added
- **ProjectPathManager** - Centralized path resolution with runtime detection
- **PathSecurityError** - Security-specific error types for path validation
- **iPad-Optimized UI** - Three-column NavigationSplitView layout for iPad
- **AdaptiveHomeView** - Automatic layout switching based on device size class
- **Apple Liquid Glass** - iOS 26+ Liquid Glass design support with fallbacks

### Changed
- Terminal security defaults now require explicit opt-in for sudo commands
- Execution timeout reduced from 5 to 2 minutes
- Added confirmation requirements for chmod, chown, osascript, security commands

### Documentation
- Created SECURITY.md with security policy and vulnerability reporting

## [1.2.3] - 2026-01-15 (PENDING)

### Fixed
- **CRITICAL: Settings Crash** - App crashed when opening Settings (Cmd+,) due to CloudSyncManager eagerly initializing CloudKit without error handling
- **CRITICAL: Message Ordering** - AI responses appeared before user messages due to timestamp-based sorting; now uses orderIndex
- **Keychain Prompts** - Repeated keychain access prompts due to mismatched service name ("ai.thea.app" vs bundle ID "app.thea.macos")
- **API Key Storage** - Unified API key storage to use Keychain (SecureStorage) instead of mixed UserDefaults/Keychain approach

### Changed
- CloudSyncManager now lazily initializes CloudKit and gracefully handles unavailable CloudKit
- Message model now includes `orderIndex` property for reliable ordering
- SecureStorage service name now matches bundle identifier
- SettingsManager API key methods now delegate to SecureStorage

## [1.2.2] - 2026-01-15

### Fixed
- **CloudKit Crash Fix** - Prevented crash on launch caused by CloudSyncManager eagerly creating CKContainer
- Fixed typo in CloudKit container identifier ("iCloud.app.teathe.thea" → "iCloud.app.thea.macos")
- Made CloudKit initialization lazy and optional with availability checking

### Added
- `isCloudKitAvailable` and `cloudKitStatus` published properties in CloudSyncManager
- Dynamic CloudKit status display in Sync settings

## [1.2.1] - 2026-01-15

### Fixed
- **Message Ordering Bug** - Fixed issue where AI responses could appear before user messages
- **Settings Persistence** - Fixed API key storage disconnect between SettingsManager (UserDefaults) and providers (Keychain)
- Changed MacSettingsView from @StateObject to @ObservedObject for SettingsManager.shared

### Changed
- SettingsManager API key methods now use consistent key naming format

## [1.2.0] - 2026-01-15

### Added
- **AI Orchestration System** - Intelligent query decomposition and model routing
- **Query Decomposer** - Breaks complex queries into sub-tasks
- **Model Router** - Routes tasks to appropriate AI models based on capabilities
- **Agent Registry** - Centralized registry for AI agents and their capabilities
- **Result Aggregator** - Combines results from multiple agents
- **Task Classifier** - Classifies tasks for optimal routing

### Technical
- Phase 6 AI Orchestration complete
- All orchestration components integrated and functional

## [1.1.6] - 2026-01-15

### Added
- Core chat functionality with streaming responses
- Message bubbles with proper styling
- Chat input view with send functionality
- Conversation document export

## [1.1.5] - 2026-01-15

### Added
- Local models settings UI (MLX and Ollama configuration)
- Model selection settings view
- Orchestrator settings view
- Complete settings manager with all configuration options

## [1.1.1] - 2026-01-15

### Fixed
- Phase 5 build errors and crashes
- Settings persistence issues

## [1.1.0] - 2026-01-15

### Added
- Self-execution system foundation
- Autonomous build loop capability
- Code fixer integration
- Error parser and knowledge base

## [1.0.0] - 2026-01-13

### Added
- **Automatic Prompt Engineering**: Meta-AI system that optimizes all prompts without user intervention
- **Swift Code Excellence**: Zero-error code generation with learning from every compilation error
- **Multi-Window Support**: Native macOS multi-window architecture with persistent state
- **Multi-Tab Support**: Tab management for conversations and projects
- **Comprehensive Life Tracking**:
  - Health data tracking (HealthKit integration for iOS/watchOS)
  - Screen time monitoring (macOS via AppKit workspace APIs)
  - Input activity tracking (macOS via Accessibility APIs)
  - Browser history tracking
  - Location tracking (iOS via CoreLocation)
- **Privacy-First Design**: All data stored locally, optional CloudKit sync
- **SwiftData Persistence**: Modern data persistence with CloudKit support
- **AI Provider Support**: Anthropic, OpenAI, Google, Groq, Perplexity, OpenRouter
- **Local Models**: Ollama and MLX support for on-device AI
- **Meta-AI Systems**:
  - Sub-agent orchestration
  - Reflection engine
  - Knowledge graph
  - Memory system
  - Multi-step reasoning
  - Dynamic tools
  - Code sandbox
  - Browser automation
  - Agent swarms
  - Plugin system

### Technical
- Built with Swift 6.0 and strict concurrency
- SwiftUI with @Observable macro (iOS 17+, macOS 14+)
- Zero compilation errors and warnings
- SwiftLint configured and passing
- Production-ready Release build
- Comprehensive test coverage

### Fixed
- All Color API errors across codebase
- Notification name errors in multiple views
- Missing file references in Xcode project
- SwiftLint violations (auto-fixed 122 files)

## [Unreleased]

### Planned
- GitHub CI/CD integration
- Automated testing in CI
- Code coverage reports
- App Store distribution
- TestFlight beta program
