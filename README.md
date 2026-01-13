# THEA - AI-Powered Life Coach & Productivity Assistant

**Version:** 1.0.0  
**Build:** 1  
**Status:** Production Ready ✅

## Overview

THEA is a privacy-first, AI-powered life coach and productivity assistant for macOS and iOS. Built with Swift 6.0, SwiftUI, and SwiftData, THEA provides intelligent assistance while keeping all your data local and secure.

## Features

### 🤖 Automatic Prompt Engineering
- Meta-AI system optimizes all prompts automatically
- No user intervention required for prompt tuning
- Learns from every interaction

### 💻 Swift Code Excellence
- Zero-error code generation with Swift 6.0
- Learns from every compilation error
- Best practices library integration
- Automatic code validation

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

## Requirements

- **macOS:** 14.0+ (Sonoma)
- **iOS:** 17.0+
- **Swift:** 6.0
- **Xcode:** 15.2+

## Building

### Swift Package Manager (Recommended)
```bash
# Debug build
swift build

# Release build
swift build -c release

# Run tests
swift test
```

### Xcode
Open `Thea.xcodeproj` in Xcode 15.2+

## Project Structure

```
Thea/
├── Shared/              # Shared code for all platforms
│   ├── AI/             # AI providers and Meta-AI systems
│   ├── Code/           # Code intelligence and validation
│   ├── Core/           # Core managers and models
│   ├── Knowledge/      # Knowledge management
│   ├── Tracking/       # Life tracking systems
│   └── UI/             # SwiftUI views
├── macOS/              # macOS-specific code
├── iOS/                # iOS-specific code
├── Tests/              # Unit and integration tests
└── Package.swift       # Swift Package Manager manifest
```

## Key Technologies

- **Swift 6.0** with strict concurrency
- **SwiftUI** with @Observable macro
- **SwiftData** for persistence
- **HealthKit** (iOS/watchOS)
- **CoreLocation** (iOS)
- **Accessibility APIs** (macOS)
- **SwiftLint** for code quality

## Development

### Code Quality
- Zero compilation errors ✅
- Zero warnings ✅
- SwiftLint configured and passing
- Production-ready Release build

### Testing
```bash
swift test --parallel
```

## AI Providers Supported

- Anthropic (Claude)
- OpenAI (GPT-4)
- Google (Gemini)
- Groq
- Perplexity
- OpenRouter
- Local Models (Ollama, MLX)

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

## License

Copyright © 2026 Thea. All rights reserved.

## Contact

For support or questions, visit: https://thea.app

---

**Built with ❤️ using Swift 6.0**
