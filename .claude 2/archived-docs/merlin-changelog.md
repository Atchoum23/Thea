# Changelog

All notable changes to Nexus will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2025-10-28

### Added
- Touch ID support for keychain authentication
- NexusKeychainStorage: Unified storage (all keys in ONE item = ONE Touch ID prompt)
- Last scan timestamp displayed in Settings
- "Scan & Import" button (imports system keys to Nexus keychain)
- Pre-authentication with Touch ID before scanning
- Progress indicator showing which key is being accessed
- Better categorization: AI Providers vs AI Aggregators
- 30+ service patterns (DeepL, GitHub, AWS, Context7, Brave, Smithery, etc.)
- Only show NEW keys (track already configured)
- Cmd+, keyboard shortcut to open Settings
- Esc/Cmd+W to close Settings
- Red X button in Settings header
- Appearance Settings (Auto/Light/Dark theme)
- Secure config file (permissions 600)
- SecureConfigManager for Touch ID-encrypted config
- Versioning system (VERSION file + auto-increment builds)
- Pattern matching for various API key formats
- Better info text explaining macOS per-item authorization

### Fixed
- Settings button now triggers (NSApp.sendAction pattern from Whisky app)
- Scan button works (state-based trigger)
- Keychain query error -50 (proper two-step approach)
- Keys persist across updates (saved to UserDefaults)
- Lazy keychain manager (no auto-load on init)
- Handle user denial gracefully (stop scan silently)
- Removed duplicate Settings scene from NexusApp
- Pattern matching detects "anthropic-api-key" format (with "KEY" not just "API")

### Security
- API keys stored in macOS keychain (encrypted)
- Config file permissions 600 (owner-only)
- Touch ID protection for unified keychain
- Actual key values never stored in UserDefaults

## [1.0.0] - 2025-10-27

### Added
- Phase 0: Core foundation
  - TextField input (NSEvent pattern from Sidekick)
  - Core Data persistence
  - Beautiful UI
  - Conversation management
  
- Phase 1: Core Architecture
  - ChromaDB semantic memory
  - AI Model Client (OpenAI, Anthropic, Perplexity, DeepSeek)
  - MCP Workflow Engine
  - Advanced File Search
  
- Phase 2: Enhanced UI
  - Settings View
  - Hybrid AI Router
  - Markdown rendering
  - File attachments UI
  
- Apple Design System
  - Liquid Glass materials (macOS Tahoe 26)
  - Apple message bubbles
  - Glass orb send button
  - Spring animations
  
- Backend Systems
  - RAG Engine
  - Document Indexer
  - Conversation Context
  - Cost Tracker
  - Cache Manager
  - Performance Monitor
  - Streaming Responses
  - Voice Manager foundation

### Fixed
- TextField input not working (NSEvent monitoring from Sidekick)
- Core Data Message→Conversation relationship
- Send button triggering

### Known Issues
- Settings buttons in sheets require special handling
- macOS keychain requires per-item authorization (by design)

---

## Version Numbering

For version numbering guidelines and tools, see: [`../../docs/VERSIONING_GUIDE.md`](../../docs/VERSIONING_GUIDE.md)

**Current Version:** 1.1.0+127 (SemVer format: version+build)

