# THEA - Complete Technical Specification
**The AI Life Companion**

Version: 2.0 (Clean Build)
Date: 2026-01-11
Author: Autonomous Claude Code Build System

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Product Vision](#product-vision)
3. [Architecture Overview](#architecture-overview)
4. [Core Features](#core-features)
5. [Technical Stack](#technical-stack)
6. [Data Models](#data-models)
7. [API Integration System](#api-integration-system)
8. [Migration System](#migration-system)
9. [Voice Activation](#voice-activation)
10. [Privacy & Security](#privacy--security)
11. [UI/UX Specifications](#uiux-specifications)
12. [Development Roadmap](#development-roadmap)
13. [Competitor Analysis](#competitor-analysis)
14. [Testing Strategy](#testing-strategy)

---

## 1. Executive Summary

**THEA** (named after the Greek Titaness and goddess, meaning "goddess" and "divine") is a comprehensive AI life companion application designed to replace and surpass existing solutions (Claude.app, ChatGPT.app, Cursor.app, Perplexity.app).

### Key Differentiators

1. **Universal AI Provider Support** - Dynamic plugin system for any AI service
2. **Complete Migration Tools** - Import all data from competitor apps
3. **Voice Activation** - "Hey Thea" wake word like Siri
4. **Privacy-First** - Local-first architecture, GDPR compliant by design
5. **Cross-Platform** - Native macOS, iOS, iPadOS, with future Windows/Android support
6. **Financial Integration** - Bank/crypto account monitoring and strategy engine
7. **Knowledge Management** - HD scanning, indexing, local model support
8. **Code Intelligence** - Claude Code-like capabilities integrated
9. **Project Merging** - Combine projects from different AI apps seamlessly

### Target Users

- **Primary**: Power users who currently use multiple AI apps (Claude, ChatGPT, Cursor, Perplexity)
- **Secondary**: Privacy-conscious individuals wanting local-first AI
- **Tertiary**: Developers needing code assistance with full data control

---

## 2. Product Vision

### Mission Statement
"To provide the most comprehensive, privacy-respecting, and powerful AI companion that consolidates all AI interactions into a single, beautiful, voice-activated interface."

### Core Principles

1. **Privacy First** - User data never leaves device without explicit consent
2. **Universal Compatibility** - Support every major AI provider through plugins
3. **Seamless Migration** - Zero friction importing from competitor apps
4. **Voice Native** - Primary interaction via "Hey Thea" wake word
5. **Beautiful Design** - Native SwiftUI, following Apple Human Interface Guidelines
6. **Extensible Architecture** - Plugin system for unlimited expansion

### Success Metrics

- User eliminates need for Claude.app, ChatGPT.app, Cursor.app, Perplexity.app
- 100% data migration accuracy from competitor apps
- <500ms voice activation response time
- Zero data breaches (local-first architecture)
- 95%+ user satisfaction rating

---

## 3. Architecture Overview

### System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         THEA Frontend                            │
│  ┌───────────────┐  ┌───────────────┐  ┌───────────────┐       │
│  │   SwiftUI     │  │  Voice Engine │  │  Chat Interface│       │
│  │   Native UI   │  │  (Hey Thea)   │  │  Multi-modal   │       │
│  └───────────────┘  └───────────────┘  └───────────────┘       │
└─────────────────────────────────────────────────────────────────┘
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      THEA Core Engine                            │
│  ┌───────────────┐  ┌───────────────┐  ┌───────────────┐       │
│  │  Conversation │  │   Project     │  │   Knowledge   │       │
│  │   Manager     │  │   Manager     │  │   Manager     │       │
│  └───────────────┘  └───────────────┘  └───────────────┘       │
│  ┌───────────────┐  ┌───────────────┐  ┌───────────────┐       │
│  │  AI Provider  │  │   Plugin      │  │   Migration   │       │
│  │   Manager     │  │   System      │  │   Engine      │       │
│  └───────────────┘  └───────────────┘  └───────────────┘       │
└─────────────────────────────────────────────────────────────────┘
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Data Layer (Local-First)                    │
│  ┌───────────────┐  ┌───────────────┐  ┌───────────────┐       │
│  │   SwiftData   │  │   Keychain    │  │  File System  │       │
│  │   Database    │  │   (Secrets)   │  │  (Documents)  │       │
│  └───────────────┘  └───────────────┘  └───────────────┘       │
└─────────────────────────────────────────────────────────────────┘
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                   External Services (Optional)                   │
│  ┌───────────────┐  ┌───────────────┐  ┌───────────────┐       │
│  │   OpenAI API  │  │ Anthropic API │  │  Google AI    │       │
│  │   (ChatGPT)   │  │   (Claude)    │  │   (Gemini)    │       │
│  └───────────────┘  └───────────────┘  └───────────────┘       │
│  ┌───────────────┐  ┌───────────────┐  ┌───────────────┐       │
│  │  Perplexity   │  │    Grok       │  │  Custom APIs  │       │
│  │      API      │  │     API       │  │   (Plugins)   │       │
│  └───────────────┘  └───────────────┘  └───────────────┘       │
└─────────────────────────────────────────────────────────────────┘
```

### Technology Stack

#### Frontend
- **SwiftUI** - Native macOS/iOS interface
- **Combine** - Reactive data flow
- **AVFoundation** - Voice recognition and synthesis
- **Speech Framework** - "Hey Thea" wake word detection

#### Backend/Core
- **Swift 6.0** - Strict concurrency, modern Swift
- **SwiftData** - Local database (Core Data successor)
- **KeychainAccess** - Secure credential storage
- **CryptoKit** - End-to-end encryption

#### AI Integration
- **OpenAI SDK** - ChatGPT integration
- **Anthropic SDK** - Claude integration
- **Google GenerativeAI SDK** - Gemini integration
- **Custom HTTP Client** - Universal API adapter

#### Build System
- **Xcode 16+** - Native IDE
- **Swift Package Manager** - Dependency management
- **XCTest** - Unit and integration testing

---

## 4. Core Features

### 4.1 Universal Chat Interface

**Description**: Single, unified chat interface supporting all AI providers.

**Features**:
- Multi-turn conversations with context retention
- Model switching mid-conversation
- Streaming responses with token-by-token display
- Image uploads (vision models)
- Code syntax highlighting
- Markdown rendering
- LaTeX math rendering
- Artifact support (Claude-style)
- Conversation forking
- Message editing and regeneration

**Technical Implementation**:
```swift
// Unified message protocol
protocol AIMessage: Sendable {
    var id: UUID { get }
    var conversationID: UUID { get }
    var role: MessageRole { get }
    var content: MessageContent { get }
    var timestamp: Date { get }
    var model: AIModel { get }
    var tokenCount: Int? { get }
    var metadata: MessageMetadata { get }
}

enum MessageRole: String, Codable, Sendable {
    case user
    case assistant
    case system
}

enum MessageContent: Codable, Sendable {
    case text(String)
    case multimodal([ContentPart])
}

struct ContentPart: Codable, Sendable {
    enum PartType: Codable {
        case text(String)
        case image(ImageData)
        case file(FileAttachment)
    }
    let type: PartType
}
```

### 4.2 Voice Activation System

**Wake Word**: "Hey Thea"

**Features**:
- Always-on listening mode (privacy-protected, local processing)
- Conversation mode (continuous dialogue without wake word)
- Voice commands ("Hey Thea, create a new project")
- Text-to-speech responses with natural voices
- Multi-language support
- Offline voice recognition fallback

**Technical Implementation**:
```swift
@MainActor
final class VoiceActivationEngine: ObservableObject {
    @Published var isListening: Bool = false
    @Published var isProcessing: Bool = false
    @Published var conversationMode: Bool = false

    private let speechRecognizer: SFSpeechRecognizer
    private let audioEngine: AVAudioEngine
    private let speechSynthesizer: AVSpeechSynthesizer

    // Wake word detection
    func startWakeWordDetection() async throws {
        // Continuous local processing for "Hey Thea"
        // Uses on-device speech recognition (privacy)
        // Zero network calls during detection
    }

    // Process voice command
    func processVoiceCommand(_ command: String) async throws -> VoiceResponse {
        // Natural language understanding
        // Route to appropriate AI provider
        // Return synthesized speech response
    }
}
```

**Privacy Guarantees**:
- Wake word detection runs 100% on-device
- No audio sent to cloud until wake word detected + user consent
- Visual indicator when microphone is active
- Settings to disable voice activation entirely

### 4.3 AI Provider Management

**Universal Plugin System**: Add any AI service dynamically.

**Built-in Providers**:
1. **OpenAI** (GPT-4, GPT-4 Turbo, GPT-4o, o1, o3)
2. **Anthropic** (Claude 3.5 Sonnet, Claude Opus 4)
3. **Google** (Gemini 1.5 Pro, Gemini 2.0 Flash)
4. **Perplexity** (Sonar models)
5. **xAI** (Grok)
6. **Meta** (Llama models via API)
7. **Local Models** (Ollama, MLX, GGUF)

**Plugin Architecture**:
```swift
protocol AIProvider: Sendable {
    var id: UUID { get }
    var name: String { get }
    var displayName: String { get }
    var supportedModels: [AIModel] { get }
    var capabilities: ProviderCapabilities { get }
    var requiresAPIKey: Bool { get }
    var apiKeyInstructions: String { get }

    func validateAPIKey(_ key: String) async throws -> Bool
    func sendMessage(_ message: AIMessage, model: AIModel) async throws -> AsyncStream<AIMessageChunk>
    func listModels() async throws -> [AIModel]
}

struct ProviderCapabilities: Codable, Sendable {
    let supportsStreaming: Bool
    let supportsVision: Bool
    let supportsCodeInterpreter: Bool
    let supportsWebSearch: Bool
    let supportsFunctionCalling: Bool
    let maxContextTokens: Int
    let maxOutputTokens: Int
}
```

**Dynamic Provider Discovery**:
- User types service name in "Add Provider" screen
- App fetches provider metadata from online registry (with caching)
- Downloads provider plugin (sandboxed Swift package)
- Validates plugin signature
- User provides API key
- System validates key before saving to Keychain

**Online Service Discovery Flow**:
```swift
@MainActor
final class ProviderDiscoveryEngine: ObservableObject {
    @Published var searchResults: [ProviderMetadata] = []
    @Published var isSearching: Bool = false

    // Real-time search as user types
    func searchProviders(_ query: String) async throws {
        guard !query.isEmpty else { return }

        isSearching = true
        defer { isSearching = false }

        // Fetch from online provider registry
        let url = URL(string: "https://api.theaapp.ai/providers/search?q=\(query)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let results = try JSONDecoder().decode([ProviderMetadata].self, from: data)

        searchResults = results
    }

    // Download and install provider plugin
    func installProvider(_ metadata: ProviderMetadata) async throws {
        // Download plugin package
        // Verify signature
        // Install to app plugins directory
        // Add to available providers
    }
}

struct ProviderMetadata: Codable, Identifiable {
    let id: UUID
    let name: String
    let displayName: String
    let description: String
    let logoURL: URL
    let pluginURL: URL
    let version: String
    let requiresAPIKey: Bool
    let apiKeyInstructions: String
    let popularityRank: Int
}
```

### 4.4 Migration Engine

**Goal**: Import 100% of data from competitor apps with zero manual work.

**Supported Sources**:
1. **Claude.app** (Anthropic)
2. **ChatGPT.app** (OpenAI)
3. **Cursor.app** (coding assistant)
4. **Perplexity.app** (search-focused)
5. **Claude Code CLI** (conversation exports)

**Migration Types**:
- Conversation history (all messages, attachments)
- Projects (Claude Projects, ChatGPT Custom GPTs)
- Settings and preferences
- Favorite prompts
- Custom instructions
- File attachments
- Conversation metadata (timestamps, models used)

**Technical Implementation**:
```swift
protocol MigrationSource {
    var sourceName: String { get }
    var sourceIcon: String { get }

    func detectInstallation() async -> Bool
    func estimateMigrationSize() async throws -> MigrationEstimate
    func migrate() async throws -> AsyncStream<MigrationProgress>
}

struct MigrationEstimate {
    let conversationCount: Int
    let projectCount: Int
    let attachmentCount: Int
    let totalSizeBytes: Int64
    let estimatedDurationSeconds: Int
}

struct MigrationProgress: Sendable {
    let stage: MigrationStage
    let currentItem: String
    let itemsProcessed: Int
    let totalItems: Int
    let percentage: Double
}

enum MigrationStage {
    case scanning
    case conversations
    case projects
    case attachments
    case settings
    case finalizing
    case complete
}
```

**Claude.app Migration**:
```swift
final class ClaudeAppMigration: MigrationSource {
    let sourceName = "Claude.app"
    let sourceIcon = "claude_icon"

    // Claude.app stores data in:
    // ~/Library/Application Support/Claude/
    private let claudeDataPath = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/Claude")

    func detectInstallation() async -> Bool {
        FileManager.default.fileExists(atPath: claudeDataPath.path)
    }

    func migrate() async throws -> AsyncStream<MigrationProgress> {
        AsyncStream { continuation in
            Task {
                // 1. Read Claude conversation database
                let conversations = try await readClaudeConversations()

                // 2. Read Claude Projects
                let projects = try await readClaudeProjects()

                // 3. Import into Thea format
                for (index, conv) in conversations.enumerated() {
                    let theaConv = try await convertClaudeConversation(conv)
                    try await saveConversation(theaConv)

                    continuation.yield(MigrationProgress(
                        stage: .conversations,
                        currentItem: conv.title,
                        itemsProcessed: index + 1,
                        totalItems: conversations.count,
                        percentage: Double(index + 1) / Double(conversations.count)
                    ))
                }

                continuation.finish()
            }
        }
    }
}
```

**ChatGPT.app Migration**:
```swift
final class ChatGPTMigration: MigrationSource {
    let sourceName = "ChatGPT.app"

    // ChatGPT export format (JSON)
    func migrate() async throws -> AsyncStream<MigrationProgress> {
        // User exports from ChatGPT settings
        // Thea imports the JSON file
        // Converts to Thea format
    }
}
```

### 4.5 Project Management

**Concept**: Organize conversations into projects with context, files, and instructions.

**Features**:
- Create projects with custom instructions
- Attach files (code, docs, images) to project context
- Project-specific AI provider/model settings
- Project templates (e.g., "Swift Development", "Data Analysis")
- Project merging (combine projects from different sources)
- Project export/import
- Project sharing (encrypted)

**Project Merging**:
```swift
@MainActor
final class ProjectMerger: ObservableObject {
    func mergeProjects(_ projects: [Project]) async throws -> Project {
        // Combines conversations from multiple projects
        // Deduplicates messages
        // Merges file attachments
        // Consolidates custom instructions
        // Resolves conflicts intelligently

        let mergedProject = Project(
            id: UUID(),
            title: "Merged: \(projects.map(\.title).joined(separator: " + "))",
            customInstructions: mergeInstructions(projects.map(\.customInstructions)),
            conversations: try await mergeConversations(projects.flatMap(\.conversations)),
            files: try await mergeFiles(projects.flatMap(\.files))
        )

        return mergedProject
    }
}
```

### 4.6 Knowledge Management

**HD Knowledge Scanning**: Index all documents on your system for AI context.

**Features**:
- Full-text search across all documents
- Smart file type detection (code, PDF, markdown, etc.)
- Automatic embedding generation (local or cloud)
- Semantic search
- File watching (auto-reindex on changes)
- Privacy controls (exclude folders)
- Local model support (Ollama, MLX)

**Supported File Types**:
- Code: .swift, .py, .js, .ts, .go, .rs, .java, .cpp, etc.
- Documents: .md, .txt, .pdf, .docx
- Data: .json, .yaml, .xml, .csv
- Notes: .note, .fountain

**Technical Implementation**:
```swift
@MainActor
final class KnowledgeManager: ObservableObject {
    @Published var indexedFiles: [IndexedFile] = []
    @Published var isIndexing: Bool = false

    func scanDirectories(_ paths: [URL]) async throws {
        for path in paths {
            try await scanDirectory(path)
        }
    }

    private func scanDirectory(_ url: URL) async throws {
        let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        )

        while let fileURL = enumerator?.nextObject() as? URL {
            guard shouldIndex(fileURL) else { continue }

            let content = try String(contentsOf: fileURL, encoding: .utf8)
            let embedding = try await generateEmbedding(content)

            let indexedFile = IndexedFile(
                url: fileURL,
                content: content,
                embedding: embedding,
                lastModified: try fileURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate!
            )

            indexedFiles.append(indexedFile)
        }
    }

    func semanticSearch(_ query: String, topK: Int = 10) async throws -> [IndexedFile] {
        let queryEmbedding = try await generateEmbedding(query)

        return indexedFiles
            .map { (file: $0, similarity: cosineSimilarity(queryEmbedding, $0.embedding)) }
            .sorted { $0.similarity > $1.similarity }
            .prefix(topK)
            .map(\.file)
    }
}
```

### 4.7 Financial Integration

**Goal**: Monitor bank accounts, crypto wallets, and provide financial insights.

**Features**:
- Bank account connection (Plaid, TrueLayer, direct API)
- Crypto wallet monitoring (read-only)
- Transaction categorization (AI-powered)
- Spending insights and trends
- Budget recommendations
- Investment strategy suggestions
- Alert system (unusual spending, bill reminders)

**Supported Services**:
- **Banking**: Revolut, Chase, Bank of America, etc.
- **Crypto**: Binance, Coinbase, Kraken, MetaMask (read-only)
- **Investments**: Robinhood, Vanguard, etc.

**Privacy Architecture**:
- All API keys stored in Keychain
- Financial data never leaves device
- Optional cloud sync (end-to-end encrypted)
- No third-party analytics

**Technical Implementation**:
```swift
protocol FinancialProvider: Sendable {
    var providerName: String { get }
    var providerType: FinancialProviderType { get }

    func authenticate(credentials: FinancialCredentials) async throws
    func fetchAccounts() async throws -> [FinancialAccount]
    func fetchTransactions(accountID: String, from: Date, to: Date) async throws -> [Transaction]
    func fetchBalance(accountID: String) async throws -> Decimal
}

enum FinancialProviderType {
    case banking
    case crypto
    case investment
}

struct Transaction: Identifiable, Codable, Sendable {
    let id: UUID
    let accountID: String
    let date: Date
    let amount: Decimal
    let currency: String
    let description: String
    let category: TransactionCategory?
    let merchant: String?
}

@MainActor
final class FinancialStrategyEngine: ObservableObject {
    func analyzeSpending() async throws -> SpendingAnalysis {
        // AI-powered categorization
        // Trend detection
        // Anomaly detection
    }

    func generateBudgetRecommendations() async throws -> [BudgetRecommendation] {
        // AI suggests optimal budget based on spending patterns
    }
}
```

### 4.8 Code Intelligence (Claude Code-like)

**Goal**: Provide Claude Code CLI capabilities directly in the app.

**Features**:
- Code generation with context awareness
- Multi-file editing
- Git integration
- Terminal command execution
- Code search and navigation
- Refactoring suggestions
- Test generation
- Documentation generation

**Technical Implementation**:
```swift
@MainActor
final class CodeIntelligenceEngine: ObservableObject {
    func analyzeCodebase(_ rootURL: URL) async throws -> CodebaseAnalysis {
        // Parse all code files
        // Build symbol index
        // Generate dependency graph
    }

    func generateCode(_ prompt: String, context: CodeContext) async throws -> CodeGenerationResult {
        // Use AI to generate code
        // Apply to correct files
        // Validate syntax
    }

    func executeTerminalCommand(_ command: String) async throws -> CommandResult {
        // Sandboxed execution
        // Stream output
    }
}
```

---

## 5. Technical Stack

### Platform Support

**Phase 1 (Initial Release)**:
- macOS 14.0+ (Sonoma and later)
- iOS 17.0+
- iPadOS 17.0+

**Phase 2 (Future)**:
- Windows 11 (via Swift on Windows)
- Android 13+ (via Kotlin Multiplatform or Flutter)
- Web (via WebAssembly)

### Development Tools

- **Xcode 16+** - Primary IDE
- **Swift 6.0** - Programming language
- **SwiftUI** - UI framework
- **SwiftData** - Local persistence
- **Combine** - Reactive framework
- **Swift Package Manager** - Dependencies
- **XCTest** - Testing framework
- **Instruments** - Performance profiling

### Dependencies

```swift
// Package.swift
dependencies: [
    // AI SDKs
    .package(url: "https://github.com/openai/openai-swift", from: "1.0.0"),
    .package(url: "https://github.com/anthropics/anthropic-sdk-swift", from: "1.0.0"),
    .package(url: "https://github.com/google/generative-ai-swift", from: "1.0.0"),

    // Security
    .package(url: "https://github.com/kishikawakatsumi/KeychainAccess", from: "4.2.0"),

    // Utilities
    .package(url: "https://github.com/realm/SwiftLint", from: "0.54.0"),
    .package(url: "https://github.com/nicklockwood/SwiftFormat", from: "0.52.0"),

    // Markdown rendering
    .package(url: "https://github.com/gonzalezreal/swift-markdown-ui", from: "2.0.0"),

    // Syntax highlighting
    .package(url: "https://github.com/raspu/Highlightr", from: "2.1.0"),
]
```

---

## 6. Data Models

### Core Data Schema

Using **SwiftData** (modern Core Data successor):

```swift
import SwiftData

// MARK: - Conversation

@Model
final class Conversation {
    @Attribute(.unique) var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var isPinned: Bool
    var projectID: UUID?

    @Relationship(deleteRule: .cascade)
    var messages: [Message]

    var metadata: ConversationMetadata

    init(id: UUID = UUID(), title: String) {
        self.id = id
        self.title = title
        self.createdAt = Date()
        self.updatedAt = Date()
        self.isPinned = false
        self.messages = []
        self.metadata = ConversationMetadata()
    }
}

struct ConversationMetadata: Codable {
    var totalTokens: Int = 0
    var totalCost: Decimal = 0
    var preferredModel: String?
    var tags: [String] = []
}

// MARK: - Message

@Model
final class Message {
    @Attribute(.unique) var id: UUID
    var conversationID: UUID
    var role: String // "user", "assistant", "system"
    var content: Data // Encoded MessageContent
    var timestamp: Date
    var model: String?
    var tokenCount: Int?
    var metadata: Data? // Encoded MessageMetadata

    init(id: UUID = UUID(), conversationID: UUID, role: String, content: MessageContent, timestamp: Date = Date()) {
        self.id = id
        self.conversationID = conversationID
        self.role = role
        self.content = try! JSONEncoder().encode(content)
        self.timestamp = timestamp
    }
}

enum MessageContent: Codable, Sendable {
    case text(String)
    case multimodal([ContentPart])

    struct ContentPart: Codable, Sendable {
        enum PartType: Codable {
            case text(String)
            case image(Data)
            case file(String) // File path
        }
        let type: PartType
    }
}

// MARK: - Project

@Model
final class Project {
    @Attribute(.unique) var id: UUID
    var title: String
    var customInstructions: String
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade)
    var conversations: [Conversation]

    var files: [ProjectFile]
    var settings: ProjectSettings

    init(id: UUID = UUID(), title: String, customInstructions: String = "") {
        self.id = id
        self.title = title
        self.customInstructions = customInstructions
        self.createdAt = Date()
        self.updatedAt = Date()
        self.conversations = []
        self.files = []
        self.settings = ProjectSettings()
    }
}

struct ProjectFile: Codable, Identifiable {
    let id: UUID
    let name: String
    let path: String
    let size: Int64
    let addedAt: Date
}

struct ProjectSettings: Codable {
    var defaultModel: String?
    var defaultProvider: String?
    var temperature: Double = 1.0
    var maxTokens: Int?
}

// MARK: - AI Provider Configuration

@Model
final class AIProviderConfig {
    @Attribute(.unique) var id: UUID
    var providerName: String
    var displayName: String
    var isEnabled: Bool
    var hasValidAPIKey: Bool
    var installedAt: Date
    var pluginVersion: String?

    init(id: UUID = UUID(), providerName: String, displayName: String) {
        self.id = id
        self.providerName = providerName
        self.displayName = displayName
        self.isEnabled = true
        self.hasValidAPIKey = false
        self.installedAt = Date()
    }
}

// MARK: - Financial Account

@Model
final class FinancialAccount {
    @Attribute(.unique) var id: UUID
    var providerName: String
    var accountName: String
    var accountType: String // "checking", "savings", "crypto", "investment"
    var currency: String
    var lastSynced: Date?

    @Relationship(deleteRule: .cascade)
    var transactions: [FinancialTransaction]

    init(id: UUID = UUID(), providerName: String, accountName: String, accountType: String, currency: String) {
        self.id = id
        self.providerName = providerName
        self.accountName = accountName
        self.accountType = accountType
        self.currency = currency
        self.transactions = []
    }
}

@Model
final class FinancialTransaction {
    @Attribute(.unique) var id: UUID
    var accountID: UUID
    var date: Date
    var amount: Decimal
    var description: String
    var category: String?
    var merchant: String?

    init(id: UUID = UUID(), accountID: UUID, date: Date, amount: Decimal, description: String) {
        self.id = id
        self.accountID = accountID
        self.date = date
        self.amount = amount
        self.description = description
    }
}
```

---

## 7. API Integration System

### Universal API Adapter

**Goal**: Unified interface for all AI providers.

```swift
protocol AIProvider: Sendable {
    var metadata: ProviderMetadata { get }
    var capabilities: ProviderCapabilities { get }

    func validateAPIKey(_ key: String) async throws -> ValidationResult
    func chat(messages: [AIMessage], model: String, stream: Bool) async throws -> AsyncStream<ChatResponse>
    func listModels() async throws -> [AIModel]
}

struct ProviderMetadata: Codable, Sendable {
    let id: UUID
    let name: String
    let displayName: String
    let logoURL: URL?
    let websiteURL: URL
    let documentationURL: URL
}

struct ProviderCapabilities: Codable, Sendable {
    let supportsStreaming: Bool
    let supportsVision: Bool
    let supportsFunctionCalling: Bool
    let supportsWebSearch: Bool
    let maxContextTokens: Int
    let maxOutputTokens: Int
    let supportedModalities: [Modality]

    enum Modality: String, Codable {
        case text
        case image
        case audio
        case video
    }
}

struct ChatResponse: Sendable {
    enum ResponseType {
        case delta(String) // Streaming chunk
        case complete(AIMessage) // Final message
        case error(Error)
    }
    let type: ResponseType
}
```

### Built-in Provider Implementations

**OpenAI Provider**:
```swift
final class OpenAIProvider: AIProvider {
    let metadata = ProviderMetadata(
        id: UUID(),
        name: "openai",
        displayName: "OpenAI",
        logoURL: URL(string: "https://openai.com/logo.png"),
        websiteURL: URL(string: "https://openai.com")!,
        documentationURL: URL(string: "https://platform.openai.com/docs")!
    )

    let capabilities = ProviderCapabilities(
        supportsStreaming: true,
        supportsVision: true,
        supportsFunctionCalling: true,
        supportsWebSearch: false,
        maxContextTokens: 128000,
        maxOutputTokens: 16384,
        supportedModalities: [.text, .image]
    )

    private let apiKey: String

    func chat(messages: [AIMessage], model: String, stream: Bool) async throws -> AsyncStream<ChatResponse> {
        // Use OpenAI SDK
        // Convert THEA messages to OpenAI format
        // Stream responses
    }
}
```

**Anthropic Provider**:
```swift
final class AnthropicProvider: AIProvider {
    let metadata = ProviderMetadata(
        id: UUID(),
        name: "anthropic",
        displayName: "Anthropic (Claude)",
        logoURL: URL(string: "https://anthropic.com/logo.png"),
        websiteURL: URL(string: "https://anthropic.com")!,
        documentationURL: URL(string: "https://docs.anthropic.com")!
    )

    let capabilities = ProviderCapabilities(
        supportsStreaming: true,
        supportsVision: true,
        supportsFunctionCalling: true,
        supportsWebSearch: false,
        maxContextTokens: 200000,
        maxOutputTokens: 8192,
        supportedModalities: [.text, .image]
    )

    func chat(messages: [AIMessage], model: String, stream: Bool) async throws -> AsyncStream<ChatResponse> {
        // Use Anthropic SDK
    }
}
```

### Dynamic Provider Registry

**Online Service Discovery**:

```swift
@MainActor
final class ProviderRegistry: ObservableObject {
    static let shared = ProviderRegistry()

    @Published var availableProviders: [ProviderMetadata] = []
    @Published var installedProviders: [AIProvider] = []

    private let registryURL = URL(string: "https://api.theaapp.ai/providers")!

    func refreshAvailableProviders() async throws {
        let (data, _) = try await URLSession.shared.data(from: registryURL)
        availableProviders = try JSONDecoder().decode([ProviderMetadata].self, from: data)
    }

    func searchProviders(_ query: String) -> [ProviderMetadata] {
        availableProviders.filter { provider in
            provider.name.localizedCaseInsensitiveContains(query) ||
            provider.displayName.localizedCaseInsensitiveContains(query)
        }
    }

    func installProvider(_ metadata: ProviderMetadata) async throws {
        // Download plugin from metadata.pluginURL
        // Verify signature
        // Load plugin
        // Add to installedProviders
    }
}
```

---

## 8. Migration System

### Migration Architecture

```swift
protocol MigrationSource {
    var sourceName: String { get }
    var sourceApp: SupportedApp { get }

    func detect() async -> MigrationDetectionResult
    func estimate() async throws -> MigrationEstimate
    func migrate(to context: ModelContext) async throws -> AsyncStream<MigrationProgress>
}

enum SupportedApp: String, CaseIterable {
    case claude = "Claude.app"
    case chatGPT = "ChatGPT.app"
    case cursor = "Cursor.app"
    case perplexity = "Perplexity.app"
    case claudeCode = "Claude Code CLI"
}

struct MigrationDetectionResult {
    let isInstalled: Bool
    let installPath: URL?
    let version: String?
    let dataPath: URL?
}

struct MigrationEstimate {
    let conversationCount: Int
    let messageCount: Int
    let projectCount: Int
    let attachmentCount: Int
    let totalSizeBytes: Int64
    let estimatedDurationSeconds: Int
}

struct MigrationProgress: Sendable {
    enum Stage: String, Codable {
        case detecting
        case scanning
        case conversations
        case projects
        case attachments
        case settings
        case finalizing
        case complete
        case error
    }

    let stage: Stage
    let currentItem: String
    let itemsProcessed: Int
    let totalItems: Int
    let percentage: Double
    let errors: [MigrationError]
}

struct MigrationError: Error, Codable {
    let item: String
    let reason: String
    let isRecoverable: Bool
}
```

### Claude.app Migration

```swift
final class ClaudeAppMigration: MigrationSource {
    let sourceName = "Claude.app"
    let sourceApp = SupportedApp.claude

    private var claudeDataPath: URL? {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Claude")
    }

    func detect() async -> MigrationDetectionResult {
        guard let dataPath = claudeDataPath,
              FileManager.default.fileExists(atPath: dataPath.path) else {
            return MigrationDetectionResult(isInstalled: false, installPath: nil, version: nil, dataPath: nil)
        }

        return MigrationDetectionResult(
            isInstalled: true,
            installPath: URL(fileURLWithPath: "/Applications/Claude.app"),
            version: detectClaudeVersion(),
            dataPath: dataPath
        )
    }

    func migrate(to context: ModelContext) async throws -> AsyncStream<MigrationProgress> {
        AsyncStream { continuation in
            Task {
                do {
                    // 1. Scan conversations
                    continuation.yield(MigrationProgress(
                        stage: .scanning,
                        currentItem: "Scanning conversations...",
                        itemsProcessed: 0,
                        totalItems: 0,
                        percentage: 0,
                        errors: []
                    ))

                    let conversations = try await scanClaudeConversations()

                    // 2. Import conversations
                    for (index, claudeConv) in conversations.enumerated() {
                        let theaConv = try convertClaudeConversation(claudeConv)
                        context.insert(theaConv)

                        continuation.yield(MigrationProgress(
                            stage: .conversations,
                            currentItem: theaConv.title,
                            itemsProcessed: index + 1,
                            totalItems: conversations.count,
                            percentage: Double(index + 1) / Double(conversations.count),
                            errors: []
                        ))
                    }

                    // 3. Import projects
                    let projects = try await scanClaudeProjects()
                    for (index, claudeProj) in projects.enumerated() {
                        let theaProj = try convertClaudeProject(claudeProj)
                        context.insert(theaProj)

                        continuation.yield(MigrationProgress(
                            stage: .projects,
                            currentItem: theaProj.title,
                            itemsProcessed: index + 1,
                            totalItems: projects.count,
                            percentage: Double(index + 1) / Double(projects.count),
                            errors: []
                        ))
                    }

                    // 4. Save
                    try context.save()

                    continuation.yield(MigrationProgress(
                        stage: .complete,
                        currentItem: "Migration complete!",
                        itemsProcessed: conversations.count + projects.count,
                        totalItems: conversations.count + projects.count,
                        percentage: 1.0,
                        errors: []
                    ))

                    continuation.finish()
                } catch {
                    continuation.yield(MigrationProgress(
                        stage: .error,
                        currentItem: "Migration failed",
                        itemsProcessed: 0,
                        totalItems: 0,
                        percentage: 0,
                        errors: [MigrationError(item: "System", reason: error.localizedDescription, isRecoverable: false)]
                    ))
                    continuation.finish()
                }
            }
        }
    }

    private func scanClaudeConversations() async throws -> [ClaudeConversation] {
        // Read Claude's SQLite database or JSON files
        // Parse conversation structure
        []
    }

    private func convertClaudeConversation(_ claude: ClaudeConversation) throws -> Conversation {
        let conv = Conversation(id: UUID(), title: claude.title)

        for claudeMsg in claude.messages {
            let content = MessageContent.text(claudeMsg.text)
            let msg = Message(
                conversationID: conv.id,
                role: claudeMsg.role,
                content: content,
                timestamp: claudeMsg.timestamp
            )
            msg.model = claudeMsg.model
            conv.messages.append(msg)
        }

        return conv
    }
}

struct ClaudeConversation {
    let id: String
    let title: String
    let messages: [ClaudeMessage]
    let createdAt: Date
}

struct ClaudeMessage {
    let role: String
    let text: String
    let timestamp: Date
    let model: String?
}
```

### ChatGPT Migration

```swift
final class ChatGPTMigration: MigrationSource {
    let sourceName = "ChatGPT.app"
    let sourceApp = SupportedApp.chatGPT

    // ChatGPT allows export as JSON
    func migrate(to context: ModelContext) async throws -> AsyncStream<MigrationProgress> {
        AsyncStream { continuation in
            Task {
                // 1. Prompt user to export from ChatGPT
                // 2. User selects exported JSON file
                // 3. Parse JSON
                // 4. Import to Thea

                continuation.finish()
            }
        }
    }
}
```

### Cursor Migration

```swift
final class CursorMigration: MigrationSource {
    let sourceName = "Cursor.app"
    let sourceApp = SupportedApp.cursor

    private var cursorDataPath: URL? {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Cursor")
    }

    func migrate(to context: ModelContext) async throws -> AsyncStream<MigrationProgress> {
        // Similar to Claude.app migration
        // Parse Cursor's conversation history
        // Import code context
        AsyncStream { _ in }
    }
}
```

---

## 9. Voice Activation

### "Hey Thea" Wake Word System

**Requirements**:
- Always-on listening (privacy-protected)
- On-device wake word detection
- <500ms activation latency
- Multi-language support
- Conversation mode (continuous listening)

**Architecture**:

```swift
@MainActor
final class VoiceActivationManager: ObservableObject {
    @Published var isListening: Bool = false
    @Published var conversationMode: Bool = false
    @Published var lastTranscript: String = ""

    private let speechRecognizer: SFSpeechRecognizer
    private let audioEngine: AVAudioEngine
    private let recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    init() {
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!
        self.audioEngine = AVAudioEngine()
        self.recognitionRequest = SFSpeechAudioBufferRecognitionRequest()

        requestPermissions()
    }

    func startWakeWordDetection() throws {
        guard !isListening else { return }

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        guard let recognitionRequest = recognitionRequest else {
            throw VoiceError.recognitionRequestFailed
        }

        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = true // Privacy: on-device only

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }

            if let result = result {
                let transcript = result.bestTranscription.formattedString.lowercased()

                // Detect wake word
                if transcript.contains("hey thea") || transcript.contains("hey tea") {
                    Task { @MainActor in
                        self.handleWakeWordDetected(transcript)
                    }
                }
            }
        }

        isListening = true
    }

    func stopWakeWordDetection() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionTask?.cancel()
        isListening = false
    }

    private func handleWakeWordDetected(_ transcript: String) {
        // Extract command after wake word
        let command = transcript.replacingOccurrences(of: "hey thea", with: "").trimmingCharacters(in: .whitespaces)

        if command.isEmpty {
            // Just wake word, enter conversation mode
            enterConversationMode()
        } else {
            // Execute command
            Task {
                await processCommand(command)
            }
        }
    }

    func enterConversationMode() {
        conversationMode = true
        playActivationSound()
        // Continue listening without requiring wake word
    }

    func exitConversationMode() {
        conversationMode = false
        playDeactivationSound()
    }

    func processCommand(_ command: String) async {
        // Send to AI provider
        // Get response
        // Speak response
    }
}

enum VoiceError: Error {
    case recognitionRequestFailed
    case audioEngineStartFailed
    case permissionDenied
}
```

**Privacy Controls**:
```swift
struct VoicePrivacySettings: Codable {
    var enableWakeWord: Bool = true
    var requireOnDeviceRecognition: Bool = true
    var saveVoiceHistory: Bool = false
    var visualIndicatorWhenListening: Bool = true
    var audioFeedbackOnActivation: Bool = true
}
```

**Multi-Language Support**:
```swift
extension VoiceActivationManager {
    func setLanguage(_ locale: Locale) {
        // Reinitialize speech recognizer with new locale
        // "Hey Thea" translates to:
        // - Spanish: "Oye Thea"
        // - French: "Hé Thea"
        // - German: "Hey Thea" (same)
        // - Japanese: "ねえ テア" (Nē Tea)
    }
}
```

---

## 10. Privacy & Security

### Privacy Architecture

**Core Principles**:
1. **Local-First**: All data stored on-device by default
2. **Explicit Consent**: Cloud features require explicit opt-in
3. **Zero Third-Party Tracking**: No analytics, no telemetry
4. **Encryption**: All sensitive data encrypted at rest and in transit
5. **Transparency**: User can see exactly what data is stored and where

**Data Storage**:
```swift
enum DataStorageLocation {
    case localOnly // SwiftData, encrypted
    case iCloudPrivate // End-to-end encrypted iCloud
    case cloudSync // Optional third-party sync (user-controlled)
}

struct PrivacySettings: Codable {
    var dataStorageLocation: DataStorageLocation = .localOnly
    var enableVoiceActivation: Bool = true
    var saveVoiceHistory: Bool = false
    var shareUsageData: Bool = false // Always false by default
    var enableCloudSync: Bool = false
    var enableFinancialSync: Bool = false
}
```

**Keychain Integration**:
```swift
@MainActor
final class SecureStorage {
    static let shared = SecureStorage()

    private let keychain = KeychainAccess.Keychain(service: "ai.thea.app")

    func saveAPIKey(_ key: String, for provider: String) throws {
        try keychain.set(key, key: "apikey.\(provider)")
    }

    func loadAPIKey(for provider: String) throws -> String? {
        try keychain.get("apikey.\(provider)")
    }

    func deleteAPIKey(for provider: String) throws {
        try keychain.remove("apikey.\(provider)")
    }

    func saveFinancialCredentials(_ credentials: FinancialCredentials, for provider: String) throws {
        let data = try JSONEncoder().encode(credentials)
        try keychain.set(data, key: "financial.\(provider)")
    }
}
```

**Encryption**:
```swift
import CryptoKit

final class EncryptionManager {
    static let shared = EncryptionManager()

    private let key: SymmetricKey

    init() {
        // Generate or load encryption key from Keychain
        if let keyData = try? SecureStorage.shared.keychain.getData("encryption.master.key") {
            key = SymmetricKey(data: keyData)
        } else {
            key = SymmetricKey(size: .bits256)
            try? SecureStorage.shared.keychain.set(key.withUnsafeBytes { Data($0) }, key: "encryption.master.key")
        }
    }

    func encrypt(_ data: Data) throws -> Data {
        let sealedBox = try AES.GCM.seal(data, using: key)
        return sealedBox.combined!
    }

    func decrypt(_ data: Data) throws -> Data {
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        return try AES.GCM.open(sealedBox, using: key)
    }
}
```

**GDPR Compliance**:
- Right to access: Export all data
- Right to erasure: Delete all data
- Right to portability: Export in standard formats
- Data minimization: Only collect necessary data
- Privacy by design: Default to most private settings

```swift
@MainActor
final class GDPRComplianceManager {
    func exportAllUserData() async throws -> URL {
        // Export all conversations, projects, settings to JSON
        // Return file URL
    }

    func deleteAllUserData() async throws {
        // Delete all SwiftData records
        // Clear Keychain
        // Remove all files
    }

    func generatePrivacyReport() async -> PrivacyReport {
        // What data is stored
        // Where it's stored
        // Who has access
    }
}

struct PrivacyReport {
    let totalConversations: Int
    let totalMessages: Int
    let totalProjects: Int
    let storageLocation: DataStorageLocation
    let apiKeysStored: [String]
    let financialAccountsConnected: Int
    let lastDataExport: Date?
}
```

---

## 11. UI/UX Specifications

### Design Philosophy

**Principles**:
1. **Native First**: Follow Apple Human Interface Guidelines
2. **Beautiful Simplicity**: Clean, minimal, functional
3. **Speed**: <100ms interactions, instant feedback
4. **Accessibility**: Full VoiceOver, keyboard navigation, dynamic type
5. **Consistency**: Unified design language across all views

### Color Scheme

```swift
extension Color {
    static let theaPrimary = Color("TheaPrimary") // Deep blue
    static let theaAccent = Color("TheaAccent") // Vibrant teal
    static let theaBackground = Color("TheaBackground") // Adaptive (light/dark)
    static let theaSurface = Color("TheaSurface") // Card background
    static let theaText = Color("TheaText") // Primary text
    static let theaSecondary = Color("TheaSecondary") // Secondary text
}
```

### Typography

```swift
extension Font {
    static let theaTitle = Font.system(size: 28, weight: .bold, design: .rounded)
    static let theaHeadline = Font.system(size: 20, weight: .semibold, design: .rounded)
    static let theaBody = Font.system(size: 16, weight: .regular, design: .default)
    static let theaCaption = Font.system(size: 14, weight: .regular, design: .default)
    static let theaCode = Font.system(size: 14, weight: .regular, design: .monospaced)
}
```

### Main Views

#### 1. Home View (Sidebar + Chat)

```swift
struct HomeView: View {
    @StateObject private var chatManager = ChatManager.shared
    @StateObject private var voiceManager = VoiceActivationManager()
    @State private var selectedConversation: Conversation?

    var body: some View {
        NavigationSplitView {
            // Sidebar
            SidebarView(selection: $selectedConversation)
        } detail: {
            // Chat View
            if let conversation = selectedConversation {
                ChatView(conversation: conversation)
            } else {
                WelcomeView()
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                VoiceActivationButton(manager: voiceManager)
            }
        }
    }
}
```

#### 2. Sidebar View

```swift
struct SidebarView: View {
    @Binding var selection: Conversation?
    @Query(sort: \Conversation.updatedAt, order: .reverse) var conversations: [Conversation]
    @State private var searchText = ""

    var body: some View {
        List(selection: $selection) {
            Section("Pinned") {
                ForEach(conversations.filter(\.isPinned)) { conversation in
                    ConversationRow(conversation: conversation)
                }
            }

            Section("Recent") {
                ForEach(filteredConversations) { conversation in
                    ConversationRow(conversation: conversation)
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search conversations")
        .toolbar {
            ToolbarItem {
                Button(action: createNewConversation) {
                    Label("New Chat", systemImage: "plus")
                }
            }
        }
    }

    var filteredConversations: [Conversation] {
        conversations.filter { !$0.isPinned && $0.title.localizedCaseInsensitiveContains(searchText) }
    }
}
```

#### 3. Chat View

```swift
struct ChatView: View {
    let conversation: Conversation
    @StateObject private var chatManager = ChatManager.shared
    @State private var inputText = ""
    @State private var isStreaming = false

    var body: some View {
        VStack(spacing: 0) {
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(conversation.messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }

                        if isStreaming {
                            StreamingIndicator()
                        }
                    }
                    .padding()
                }
                .onChange(of: conversation.messages.count) { _, _ in
                    if let lastMessage = conversation.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            // Input
            ChatInputView(
                text: $inputText,
                isStreaming: $isStreaming,
                onSend: sendMessage
            )
        }
        .navigationTitle(conversation.title)
        .toolbar {
            ToolbarItem {
                Menu {
                    Button("Edit Title", action: editTitle)
                    Button("Export", action: exportConversation)
                    Divider()
                    Button("Delete", role: .destructive, action: deleteConversation)
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                }
            }
        }
    }

    func sendMessage() {
        Task {
            isStreaming = true
            await chatManager.sendMessage(inputText, in: conversation)
            isStreaming = false
            inputText = ""
        }
    }
}
```

#### 4. Settings View

```swift
struct SettingsView: View {
    @StateObject private var settingsManager = SettingsManager.shared

    var body: some View {
        Form {
            Section("AI Providers") {
                NavigationLink("Manage Providers") {
                    ProvidersView()
                }
                NavigationLink("API Keys") {
                    APIKeysView()
                }
            }

            Section("Voice") {
                Toggle("Enable 'Hey Thea'", isOn: $settingsManager.enableVoiceActivation)
                Toggle("Conversation Mode", isOn: $settingsManager.conversationMode)
                Picker("Voice Language", selection: $settingsManager.voiceLanguage) {
                    ForEach(supportedLanguages) { language in
                        Text(language.displayName).tag(language)
                    }
                }
            }

            Section("Privacy") {
                NavigationLink("Privacy Settings") {
                    PrivacySettingsView()
                }
                NavigationLink("Export Data") {
                    DataExportView()
                }
                Button("Delete All Data", role: .destructive) {
                    // Confirmation dialog
                }
            }

            Section("Migration") {
                NavigationLink("Import from Other Apps") {
                    MigrationView()
                }
            }

            Section("Financial") {
                NavigationLink("Connected Accounts") {
                    FinancialAccountsView()
                }
            }

            Section("About") {
                LabeledContent("Version", value: Bundle.main.appVersion)
                Link("Privacy Policy", destination: URL(string: "https://theaapp.ai/privacy")!)
                Link("Terms of Service", destination: URL(string: "https://theaapp.ai/terms")!)
            }
        }
        .navigationTitle("Settings")
    }
}
```

---

## 12. Development Roadmap

### Phase 1: Core Foundation (Weeks 1-4)

**Goals**: Basic chat functionality, local persistence, UI framework

**Deliverables**:
- ✅ Project structure and build system
- ✅ SwiftData models implemented
- ✅ Basic SwiftUI interface (Sidebar + Chat)
- ✅ Message input/output
- ✅ OpenAI provider integration
- ✅ Anthropic provider integration
- ✅ Keychain API key storage
- ✅ Basic settings view
- ✅ Unit tests for core models

**Success Criteria**:
- App builds and runs on macOS
- Can send/receive messages to OpenAI/Anthropic
- Conversations persist across app restarts
- API keys stored securely

### Phase 2: Voice & Migration (Weeks 5-8)

**Goals**: Voice activation, competitor app migration

**Deliverables**:
- ✅ "Hey Thea" wake word detection
- ✅ Voice synthesis for responses
- ✅ Conversation mode
- ✅ Claude.app migration
- ✅ ChatGPT migration (JSON import)
- ✅ Cursor migration
- ✅ Migration UI with progress tracking
- ✅ Voice settings

**Success Criteria**:
- "Hey Thea" reliably activates (<500ms latency)
- 95%+ successful migration from Claude.app
- Voice privacy controls functional

### Phase 3: Advanced Features (Weeks 9-12)

**Goals**: Projects, knowledge management, financial integration

**Deliverables**:
- ✅ Project management system
- ✅ Project merging
- ✅ HD knowledge scanning
- ✅ Semantic search
- ✅ Financial account connection (Revolut, Coinbase)
- ✅ Transaction categorization
- ✅ Budget recommendations
- ✅ Plugin system foundation

**Success Criteria**:
- Can create and manage projects
- Knowledge scanner indexes 10K+ files
- Financial accounts sync successfully
- AI provides useful spending insights

### Phase 4: Code Intelligence & Polish (Weeks 13-16)

**Goals**: Claude Code-like features, UI polish, testing

**Deliverables**:
- ✅ Code generation with multi-file context
- ✅ Git integration
- ✅ Terminal command execution
- ✅ UI polish and animations
- ✅ Accessibility improvements
- ✅ Comprehensive test suite
- ✅ Performance optimization
- ✅ Documentation

**Success Criteria**:
- Code generation matches Claude Code quality
- App feels fast and polished
- 90%+ code coverage
- VoiceOver fully functional

### Phase 5: iOS/iPadOS Support (Weeks 17-20)

**Goals**: Mobile versions with adapted UI

**Deliverables**:
- ✅ iOS-optimized UI
- ✅ iPadOS split-view support
- ✅ iCloud sync
- ✅ Handoff between devices
- ✅ iOS voice activation
- ✅ Mobile-specific features (widgets, shortcuts)

**Success Criteria**:
- Feature parity with macOS version
- Native iOS/iPadOS feel
- Seamless sync across devices

### Phase 6: Public Release (Weeks 21-24)

**Goals**: App Store submission, marketing, support

**Deliverables**:
- ✅ App Store listing
- ✅ Website (theaapp.ai)
- ✅ User documentation
- ✅ Privacy policy / Terms of Service
- ✅ Support system
- ✅ Analytics (privacy-respecting, opt-in)
- ✅ Crash reporting
- ✅ Beta testing program

**Success Criteria**:
- App Store approval
- Zero critical bugs
- Positive initial reviews

---

## 13. Competitor Analysis

### Claude.app (Anthropic)

**Strengths**:
- Excellent long-context handling (200K tokens)
- High-quality reasoning
- Artifact feature (interactive components)
- Claude Projects (context management)
- Clean, minimal UI

**Weaknesses**:
- Limited to Claude models only
- No voice activation
- No migration from other apps
- No financial integration
- No code execution
- Limited project management

**How THEA Wins**:
- ✅ Universal AI provider support (Claude + GPT + Gemini + more)
- ✅ "Hey Thea" voice activation
- ✅ Migrate all Claude Projects to THEA
- ✅ Financial integration
- ✅ Code execution and intelligence
- ✅ Advanced project merging

### ChatGPT.app (OpenAI)

**Strengths**:
- GPT-4, GPT-4o, o1, o3 models
- Voice mode (conversational)
- Image generation (DALL-E)
- Code interpreter
- Custom GPTs
- Large user base

**Weaknesses**:
- Limited to OpenAI models
- No deep project management
- Privacy concerns (data used for training by default)
- No migration tools
- No financial features

**How THEA Wins**:
- ✅ Support GPT + all other providers
- ✅ Better voice activation ("Hey Thea" vs manual button)
- ✅ Privacy-first (local by default, never used for training)
- ✅ Migrate all ChatGPT history
- ✅ Financial intelligence
- ✅ Advanced project system

### Cursor.app (Code Editor)

**Strengths**:
- Excellent code editing with AI
- Multi-file context awareness
- Inline code suggestions
- Codebase indexing
- Chat with your codebase
- Git integration

**Weaknesses**:
- Code-focused only (not general purpose)
- No voice activation
- Limited conversation management
- No financial features
- Requires separate AI chat app

**How THEA Wins**:
- ✅ General purpose + code intelligence
- ✅ Voice activation for hands-free coding
- ✅ Better conversation management
- ✅ All features in one app (no need for separate AI chat)
- ✅ Financial + code + general AI in one place

### Perplexity.app (Search-Focused AI)

**Strengths**:
- Excellent web search integration
- Source citations
- Research-focused
- Pro Search feature
- Clean UI

**Weaknesses**:
- Search-focused, not general purpose
- Limited conversation depth
- No code features
- No voice activation
- No project management
- No financial features

**How THEA Wins**:
- ✅ Web search + general AI + code + financial (all-in-one)
- ✅ Voice activation
- ✅ Deep conversation management
- ✅ Projects for research organization
- ✅ Migrate Perplexity history

### Overall Competitive Advantage

**THEA's Unique Position**:
1. **Only app that replaces ALL competitors** - No need for Claude.app, ChatGPT.app, Cursor.app, Perplexity.app
2. **Privacy-first** - Local-first architecture, GDPR compliant by design
3. **Voice-native** - "Hey Thea" wake word, conversation mode
4. **Universal AI** - Support every major provider through plugins
5. **Complete migration** - Import all data from competitors
6. **Financial intelligence** - Unique feature not available elsewhere
7. **Project merging** - Combine work from different AI apps seamlessly

---

## 14. Testing Strategy

### Unit Tests

**Coverage Goal**: 90%+

**Key Areas**:
- Data models (Conversation, Message, Project)
- AI provider adapters
- Migration logic
- Encryption/decryption
- Voice activation logic
- Financial transaction parsing

**Example**:
```swift
final class ConversationTests: XCTestCase {
    func testConversationCreation() {
        let conv = Conversation(id: UUID(), title: "Test")
        XCTAssertNotNil(conv.id)
        XCTAssertEqual(conv.title, "Test")
        XCTAssertTrue(conv.messages.isEmpty)
    }

    func testAddMessage() {
        let conv = Conversation(id: UUID(), title: "Test")
        let message = Message(
            conversationID: conv.id,
            role: "user",
            content: .text("Hello")
        )
        conv.messages.append(message)
        XCTAssertEqual(conv.messages.count, 1)
    }
}
```

### Integration Tests

**Key Scenarios**:
- End-to-end chat flow (send message → receive response)
- Migration complete workflow
- Voice activation → response flow
- Financial account sync → transaction categorization
- Project creation → file attachment → AI query with context

### UI Tests

**Critical Flows**:
- New conversation creation
- Message send/receive
- Voice activation
- Settings changes
- Migration wizard
- Project management

**Example**:
```swift
final class ChatUITests: XCTestCase {
    func testSendMessage() throws {
        let app = XCUIApplication()
        app.launch()

        // Create new conversation
        app.buttons["New Chat"].tap()

        // Type message
        let textField = app.textFields["Message input"]
        textField.tap()
        textField.typeText("Hello, Thea!")

        // Send
        app.buttons["Send"].tap()

        // Verify message appears
        XCTAssertTrue(app.staticTexts["Hello, Thea!"].exists)
    }
}
```

### Performance Tests

**Benchmarks**:
- App launch time: <1s
- Message send latency: <100ms
- Voice activation response: <500ms
- Knowledge search: <200ms for 10K files
- Migration speed: >100 conversations/second

**Example**:
```swift
final class PerformanceTests: XCTestCase {
    func testKnowledgeSearchPerformance() {
        let knowledgeManager = KnowledgeManager()

        measure {
            let results = try! await knowledgeManager.semanticSearch("Swift concurrency", topK: 10)
            XCTAssertGreaterThan(results.count, 0)
        }
    }
}
```

### Privacy Tests

**Scenarios**:
- Voice data not sent to cloud when wake word detection active
- API keys properly stored in Keychain
- Conversation data encrypted at rest
- iCloud sync uses end-to-end encryption
- No telemetry sent without explicit opt-in

---

## 15. File Structure

```
THEA/
├── THEA.xcodeproj
├── THEA/
│   ├── TheaApp.swift                     # App entry point
│   ├── Core/
│   │   ├── Models/
│   │   │   ├── Conversation.swift
│   │   │   ├── Message.swift
│   │   │   ├── Project.swift
│   │   │   ├── AIProvider.swift
│   │   │   └── FinancialAccount.swift
│   │   ├── Managers/
│   │   │   ├── ChatManager.swift
│   │   │   ├── VoiceActivationManager.swift
│   │   │   ├── MigrationManager.swift
│   │   │   ├── KnowledgeManager.swift
│   │   │   ├── FinancialManager.swift
│   │   │   ├── ProviderRegistry.swift
│   │   │   └── SettingsManager.swift
│   │   └── Services/
│   │       ├── SecureStorage.swift
│   │       ├── EncryptionManager.swift
│   │       └── SyncManager.swift
│   ├── AI/
│   │   ├── Providers/
│   │   │   ├── OpenAIProvider.swift
│   │   │   ├── AnthropicProvider.swift
│   │   │   ├── GoogleProvider.swift
│   │   │   └── LocalModelProvider.swift
│   │   └── ProviderProtocol.swift
│   ├── Migration/
│   │   ├── Sources/
│   │   │   ├── ClaudeAppMigration.swift
│   │   │   ├── ChatGPTMigration.swift
│   │   │   ├── CursorMigration.swift
│   │   │   └── PerplexityMigration.swift
│   │   └── MigrationProtocol.swift
│   ├── UI/
│   │   ├── Views/
│   │   │   ├── HomeView.swift
│   │   │   ├── SidebarView.swift
│   │   │   ├── ChatView.swift
│   │   │   ├── SettingsView.swift
│   │   │   ├── MigrationView.swift
│   │   │   ├── ProjectsView.swift
│   │   │   └── FinancialView.swift
│   │   ├── Components/
│   │   │   ├── MessageBubble.swift
│   │   │   ├── ChatInputView.swift
│   │   │   ├── VoiceActivationButton.swift
│   │   │   └── StreamingIndicator.swift
│   │   └── Theme/
│   │       ├── Colors.swift
│   │       ├── Fonts.swift
│   │       └── Styles.swift
│   └── Resources/
│       ├── Assets.xcassets
│       ├── Localizable.strings
│       └── Info.plist
├── TheaTests/
│   ├── ModelTests/
│   ├── ManagerTests/
│   ├── MigrationTests/
│   └── AIProviderTests/
├── TheaUITests/
│   ├── ChatFlowTests.swift
│   └── VoiceActivationTests.swift
└── Package.swift                         # Swift Package Manager dependencies
```

---

## 16. Code Snippets - Key Implementation

### ChatManager (Core Chat Logic)

```swift
import Foundation
import SwiftData

@MainActor
final class ChatManager: ObservableObject {
    static let shared = ChatManager()

    @Published var activeConversation: Conversation?
    @Published var isStreaming: Bool = false

    private let providerRegistry = ProviderRegistry.shared
    private let modelContext: ModelContext

    init(modelContext: ModelContext = ModelContext(ModelContainer.shared)) {
        self.modelContext = modelContext
    }

    func sendMessage(_ text: String, in conversation: Conversation, model: String? = nil) async throws {
        // 1. Create user message
        let userMessage = Message(
            conversationID: conversation.id,
            role: "user",
            content: .text(text)
        )
        conversation.messages.append(userMessage)
        modelContext.insert(userMessage)
        try modelContext.save()

        // 2. Get AI provider
        let provider = try getProvider(for: model ?? conversation.metadata.preferredModel)

        // 3. Prepare messages for API
        let apiMessages = conversation.messages.map { msg in
            AIMessage(
                id: msg.id,
                conversationID: msg.conversationID,
                role: MessageRole(rawValue: msg.role) ?? .user,
                content: decodeMessageContent(msg.content),
                timestamp: msg.timestamp,
                model: msg.model ?? "",
                tokenCount: msg.tokenCount,
                metadata: MessageMetadata()
            )
        }

        // 4. Stream response
        isStreaming = true
        var assistantText = ""

        let responseStream = try await provider.chat(
            messages: apiMessages,
            model: model ?? "gpt-4o",
            stream: true
        )

        // 5. Create assistant message
        let assistantMessage = Message(
            conversationID: conversation.id,
            role: "assistant",
            content: .text("")
        )
        assistantMessage.model = model
        conversation.messages.append(assistantMessage)
        modelContext.insert(assistantMessage)

        for await chunk in responseStream {
            switch chunk.type {
            case .delta(let text):
                assistantText += text
                assistantMessage.content = try! JSONEncoder().encode(MessageContent.text(assistantText))
            case .complete(let finalMessage):
                assistantMessage.content = try! JSONEncoder().encode(finalMessage.content)
                assistantMessage.tokenCount = finalMessage.tokenCount
            case .error(let error):
                throw error
            }
        }

        isStreaming = false
        conversation.updatedAt = Date()
        try modelContext.save()
    }

    private func getProvider(for model: String?) throws -> AIProvider {
        // Determine provider from model name
        // Return appropriate provider instance
        return providerRegistry.installedProviders.first!
    }

    private func decodeMessageContent(_ data: Data) -> MessageContent {
        try! JSONDecoder().decode(MessageContent.self, from: data)
    }
}
```

---

## 17. Success Metrics & KPIs

### User Engagement
- **Daily Active Users (DAU)**: 70%+ of installed base
- **Messages per Day**: Average 20+ messages/user
- **Voice Activation Usage**: 40%+ of users enable "Hey Thea"
- **Retention**: 80% Week 1, 60% Month 1, 40% Month 3

### Migration Success
- **Migration Completion Rate**: 90%+ of users who start migration complete it
- **Data Accuracy**: 95%+ of migrated conversations match source
- **Migration Speed**: <5 minutes for 1000 conversations

### Performance
- **App Launch Time**: <1s on modern Macs
- **Message Latency**: <100ms from send to API call
- **Voice Activation**: <500ms from "Hey Thea" to response
- **Search Performance**: <200ms for knowledge base queries

### Quality
- **Crash Rate**: <0.1% of sessions
- **User Satisfaction**: 4.5+ stars on App Store
- **Support Tickets**: <5% of users need support
- **Privacy Incidents**: Zero data breaches

### Business (If Commercialized)
- **Conversion Rate**: 10%+ free to paid
- **Churn Rate**: <5% monthly
- **NPS Score**: 50+
- **Organic Growth**: 30%+ month-over-month

---

## 18. Conclusion

**THEA** is positioned to be the definitive AI life companion, replacing Claude.app, ChatGPT.app, Cursor.app, and Perplexity.app with a single, unified, privacy-first, voice-activated application.

**Key Advantages**:
1. ✅ **Universal AI Support** - All providers, one app
2. ✅ **Complete Migration** - Seamless import from all competitors
3. ✅ **Voice Native** - "Hey Thea" wake word system
4. ✅ **Privacy First** - Local-first, GDPR compliant
5. ✅ **Financial Intelligence** - Unique value-add
6. ✅ **Code Intelligence** - Claude Code capabilities integrated
7. ✅ **Beautiful Native UI** - True SwiftUI, fast and polished

**Next Steps**:
1. User approval of this specification
2. Begin Phase 1 implementation (Core Foundation)
3. Iterate based on testing and feedback
4. Launch beta program
5. Public release on App Store

---

**Estimated Token Count**: ~38,000 tokens
**Estimated Cost**: $2.85 (at $0.075/1K tokens for input)

**This specification provides a complete blueprint for building THEA from scratch with proper architecture, no technical debt, and all requested features.**


---

## 15. Expanded Feature Integration (155+ App Analysis)

Based on comprehensive analysis of 155+ competitor apps, the following features are planned for post-launch integration.

### 15.1 Health & Wellness Module

#### HealthKit Integration
```swift
// Core Health Data Types
- Sleep Analysis (stages, quality, duration)
- Heart Rate (resting, active, recovery zones)
- Activity (steps, calories, distance)
- Blood Glucose (optional, for diabetic users)
- Blood Pressure (optional)
```

#### Features
- **Sleep Dashboard**: Weekly/monthly sleep trends, stage breakdown, quality scoring
- **Heart Rate Monitoring**: Zone detection, resting heart rate trends, anomaly alerts
- **Activity Tracking**: Daily goals, streak tracking, movement reminders
- **Health Insights**: AI-generated recommendations based on health data

#### Circadian-Aware UI
```swift
enum CircadianPhase: String, Codable, Sendable {
    case earlyMorning  // 5-8am: Cool white (6500K), high contrast
    case morning       // 8-12pm: Neutral white (5500K)
    case afternoon     // 12-5pm: Warm white (5000K)
    case evening       // 5-9pm: Warm (3500K), reduced motion
    case night         // 9pm-5am: Very warm (2700K), low brightness
}
```

### 15.2 Financial Intelligence Module

#### Budget System (YNAB-style)
```swift
struct Budget: Codable, Sendable, Identifiable {
    let id: UUID
    var name: String
    var categories: [BudgetCategory]
    var startDate: Date
    var endDate: Date
    var totalAllocation: Decimal
}

struct BudgetCategory: Codable, Sendable, Identifiable {
    let id: UUID
    var name: String
    var allocation: Decimal
    var spent: Decimal
    var color: String
    var icon: String
}
```

#### Features
- **Zero-Based Budgeting**: Give every dollar a job
- **AI Categorization**: Automatic transaction categorization with learning
- **Subscription Tracking**: Monitor recurring expenses, cancellation alerts
- **Spending Insights**: AI-generated recommendations for saving
- **Budget Alerts**: Notifications when approaching category limits

### 15.3 Focus & Productivity Module

#### Focus Mode Service
```swift
actor FocusModeService: FocusModeManager {
    func startSession(duration: TimeInterval, type: FocusType) async throws -> FocusSession
    func endSession(_ session: FocusSession) async throws -> FocusSessionResult
}

enum FocusType: String, Codable, Sendable {
    case deepWork      // 90 min default, ambient audio
    case creative      // 60 min default, ambient audio
    case reading       // 30 min default, no audio
    case meditation    // 15 min default, meditation audio
}
```

#### Features
- **Focus Sessions**: Configurable duration and type
- **Ambient Audio**: Background sounds for concentration (forest, rain, cafe)
- **Visual Timer**: Tiimo-style countdown with progress ring
- **Task Breakdown**: AI-powered task decomposition (Goblin Tools-style)
- **Pomodoro Timer**: Customizable work/break intervals

### 15.4 ADHD Support Components

#### Visual Timer
- Large, high-contrast countdown display
- Progress ring with gradient colors
- Haptic feedback on milestones
- Customizable color schemes

#### Task Breakdown
- AI-generated subtask lists
- Estimated time per subtask
- Checkable completion states
- Re-estimation on feedback

#### ADHD-Friendly UI Patterns
- Clear visual hierarchy
- Minimal distractions
- Consistent navigation
- High contrast options
- Reduced animation mode

### 15.5 Career & Goals Module

#### Goal Tracking System
```swift
struct Goal: Codable, Sendable, Identifiable {
    let id: UUID
    var title: String
    var description: String
    var targetDate: Date?
    var progress: Double  // 0-1
    var subGoals: [Goal]
    var category: GoalCategory
    var smartCriteria: SMARTCriteria
}

struct SMARTCriteria: Codable, Sendable {
    var specific: String
    var measurable: String
    var achievable: String
    var relevant: String
    var timeBound: Date?
}
```

#### Features
- **SMART Goals**: Structured goal creation with criteria
- **Hierarchical Sub-goals**: Break down large goals
- **Progress Tracking**: Visual progress with streaks
- **Skill Development**: Track learning progress
- **Daily Reflection**: AI-generated journaling prompts

### 15.6 Assessment Engine

#### Assessment Types
```swift
enum AssessmentType: String, Codable, Sendable {
    case emotionalIntelligence  // EQ assessment
    case highlySensitivePerson  // HSP scale
    case personality            // Big Five / MBTI
    case cognitiveStyle         // Learning preferences
    case workStyle              // Work habit analysis
}
```

#### Features
- **Questionnaire Framework**: Flexible assessment system
- **Cognitive Load Monitor**: Detect user fatigue from interaction patterns
- **Personality Insights**: Adapt AI communication style
- **Progress Dashboard**: Track assessment results over time
- **Privacy-First**: All results stored locally only

### 15.7 Nutrition Tracking

#### Features
- **Food Logging**: Quick search and entry
- **Nutrient Analysis**: Macro and micronutrient tracking
- **Meal Planning**: AI-suggested meal plans
- **Integration**: Sync with HealthKit nutrition data

### 15.8 Display Control (macOS)

#### Features
- **DDC/CI Brightness**: Hardware-level brightness control
- **Multi-Monitor Sync**: Unified brightness across displays
- **Circadian Integration**: Auto-adjust based on time
- **Presets**: Quick switch between display profiles

### 15.9 Income Tracking

#### Features
- **Multiple Income Streams**: Track various sources
- **Side Hustle Dashboard**: Gig economy income tracking
- **Passive Income**: Investment income monitoring
- **Trend Analysis**: Income growth over time
- **Integration**: Sync with financial dashboard

---

## 16. Integration Architecture

### 16.1 Module Communication

```
┌─────────────────────────────────────────────────────────────────┐
│                    THEA INTEGRATION LAYER                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐           │
│  │ Health  │  │Financial│  │Wellness │  │Producti-│           │
│  │ Module  │  │ Module  │  │ Module  │  │  vity   │           │
│  └────┬────┘  └────┬────┘  └────┬────┘  └────┬────┘           │
│       │            │            │            │                 │
│       └────────────┴────────────┴────────────┘                 │
│                          │                                     │
│                          ▼                                     │
│              ┌─────────────────────┐                           │
│              │ IntegrationsManager │                           │
│              │   (Coordinator)     │                           │
│              └──────────┬──────────┘                           │
│                         │                                      │
│       ┌─────────────────┼─────────────────┐                   │
│       ▼                 ▼                 ▼                   │
│  ┌─────────┐      ┌──────────┐      ┌─────────┐              │
│  │ Career  │      │Assessment│      │ Unified │              │
│  │ Module  │      │  Module  │      │Dashboard│              │
│  └─────────┘      └──────────┘      └─────────┘              │
│                                                               │
└───────────────────────────────────────────────────────────────┘
```

### 16.2 Data Flow

```swift
// Cross-module data sharing via protocols
protocol ModuleDataProvider: Sendable {
    associatedtype DataType: Sendable
    func fetchLatestData() async throws -> DataType
    func subscribeToUpdates() -> AsyncStream<DataType>
}

// Unified dashboard aggregation
actor UnifiedDashboardManager {
    private var healthProvider: any HealthDataProvider
    private var financialProvider: any FinancialDataProvider
    private var productivityProvider: any ProductivityDataProvider
    
    func aggregateDashboardData() async throws -> UnifiedDashboardData {
        async let health = healthProvider.fetchLatestData()
        async let financial = financialProvider.fetchLatestData()
        async let productivity = productivityProvider.fetchLatestData()
        
        return try await UnifiedDashboardData(
            health: health,
            financial: financial,
            productivity: productivity
        )
    }
}
```

### 16.3 Feature Flags

```swift
// Safe module enable/disable
struct IntegrationFeatureFlags {
    static var healthModule = true
    static var financialModule = true
    static var wellnessModule = true
    static var productivityModule = true
    static var careerModule = true
    static var assessmentModule = true
    static var nutritionModule = false  // Coming soon
    static var displayModule = false    // macOS only
    static var incomeModule = false     // Coming soon
}
```

---

## 17. Quality Standards for Integration

### 17.1 Code Quality Requirements

| Requirement | Standard |
|-------------|----------|
| Build Errors | 0 |
| Build Warnings | 0 |
| Test Coverage | ≥85% |
| Swift Version | 6.0 |
| Concurrency | Strict |
| Documentation | 100% public APIs |

### 17.2 Performance Benchmarks

| Metric | Target |
|--------|--------|
| Module Load Time | <100ms |
| Data Fetch | <500ms |
| UI Render | <16ms (60fps) |
| Memory per Module | <50MB |
| Battery Impact | Minimal |

### 17.3 Accessibility Standards

- VoiceOver full support
- Dynamic Type support
- High contrast mode
- Reduced motion support
- Keyboard navigation
- WCAG 2.1 AA compliance

---

*Specification Version: 3.0*
*Last Updated: January 12, 2026*
*Integration Analysis: 155+ apps across 9 categories*
