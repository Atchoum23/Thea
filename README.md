# THEA - AI-Powered Life Coach & Productivity Assistant

**Version:** 1.0.0
**Build:** 1
**Last Updated:** January 30, 2026
**Status:** Production Ready ✅ | Security Audit: Passed ✅

## Overview

THEA is a privacy-first, AI-powered life coach and productivity assistant for macOS, iOS, watchOS, and tvOS. Built with Swift 6.0, SwiftUI, and SwiftData, THEA provides intelligent assistance while keeping all your data local and secure.

## Features

### 🤖 Intelligent AI Orchestration
- **TaskClassifier**: Classifies queries by type (code, math, creative, etc.)
- **ModelRouter**: Routes to optimal model based on task and preferences
- **QueryDecomposer**: Breaks complex queries into sub-tasks
- Automatic prompt optimization via Meta-AI system

### 💻 On-Device ML with MLX
- Local inference using mlx-swift and mlx-swift-lm
- ChatSession for multi-turn conversations with KV cache
- Dynamic model selection based on task complexity
- Models stored in ~/.cache/huggingface/hub/

### 🪟 Multi-Window & Multi-Tab Support
- Native macOS multi-window architecture
- Persistent window state across sessions
- Tab management like Safari/Xcode

### 📊 Comprehensive Life Tracking
- Health data tracking (iOS/watchOS via HealthKit)
- Screen time monitoring (macOS)
- Input activity tracking (macOS via Accessibility)
- Browser history tracking
- Location tracking (iOS via CoreLocation)
- Privacy-first design - all data stays local

### 🔒 Privacy-First Design
- All data stored locally on-device
- No cloud sync by default
- SwiftData persistence
- Optional CloudKit sync
- AgentSec framework for AI safety boundaries

## Requirements

- **macOS:** 14.0+ (Sonoma)
- **iOS:** 17.0+
- **watchOS:** 10.0+
- **tvOS:** 17.0+
- **Swift:** 6.0 (strict concurrency)
- **Xcode:** 16.2+

## Building

### Swift Package Manager (Recommended - 60x Faster Tests)
```bash
# Run all tests (47 tests in ~1 second)
swift test

# Debug build
swift build

# Release build
swift build -c release

# With sanitizers
swift test --sanitize=address
swift test --sanitize=thread
```

### Xcode (XcodeGen)
```bash
# Generate Xcode project from project.yml
xcodegen generate

# Open project
open Thea.xcodeproj

# Build all platforms from CLI
xcodebuild -project Thea.xcodeproj -scheme Thea-macOS \
    -destination "platform=macOS" build
```

### Available Schemes
| Scheme | Platform | Destination |
|--------|----------|-------------|
| Thea-macOS | macOS | `platform=macOS` |
| Thea-iOS | iOS | `generic/platform=iOS` |
| Thea-watchOS | watchOS | `generic/platform=watchOS` |
| Thea-tvOS | tvOS | `generic/platform=tvOS` |

## Project Structure

```
Thea/
├── Sources/
│   ├── TheaModels/      # SwiftData models (extracted package)
│   ├── TheaInterfaces/  # Protocol definitions (extracted package)
│   └── TheaServices/    # Business logic services (extracted package)
├── Shared/              # Shared code for all platforms
│   ├── AI/             # AI providers and orchestration
│   ├── Code/           # Code intelligence and validation
│   ├── Core/           # Core managers and models
│   ├── Knowledge/      # Knowledge management
│   ├── Orchestrator/   # TaskClassifier, ModelRouter, QueryDecomposer
│   ├── Tracking/       # Life tracking systems
│   └── UI/             # SwiftUI views
├── macOS/              # macOS-specific code
├── iOS/                # iOS-specific code
├── watchOS/            # watchOS-specific code
├── tvOS/               # tvOS-specific code
├── Tests/              # Unit tests (47 tests)
├── Tools/              # Build helpers and utilities
├── Package.swift       # Swift Package Manager manifest
└── project.yml         # XcodeGen project definition
```

## Quality Assurance

### Current Status
- ✅ All 47 tests passing
- ✅ 0 SwiftLint errors
- ✅ All 4 platforms build (Debug + Release)
- ✅ Security audit passed (January 2026)
- ✅ Memory leak check: 0 leaks

### Running Full QA
```bash
# See comprehensive QA plan
cat .claude/COMPREHENSIVE_QA_PLAN.md

# Quick test run
swift test

# SwiftLint check
swiftlint lint
```

## AI Providers Supported

- **Anthropic** (Claude)
- **OpenAI** (GPT-4)
- **Google** (Gemini)
- **Groq**
- **Perplexity**
- **OpenRouter**
- **Local Models** (Ollama, MLX)

## Meta-AI Systems

- Sub-Agent Orchestration
- Reflection Engine
- Knowledge Graph
- Memory System
- Multi-Step Reasoning
- Dynamic Tools
- Code Sandbox
- Browser Automation
- Agent Swarms
- Plugin System

## Documentation

| Document | Description |
|----------|-------------|
| `.claude/CLAUDE.md` | Project guidelines for Claude Code |
| `.claude/COMPREHENSIVE_QA_PLAN.md` | Full QA checklist (execute after major changes) |
| `QA_MASTER_PLAN.md` | Detailed QA plan with security audit results |
| `Documentation/` | User guides, developer guides, architecture |

## License

Copyright © 2026 Thea. All rights reserved.

## Contact

For support or questions, visit: https://thea.app

---

**Built with ❤️ using Swift 6.0**
