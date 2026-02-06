# THEA L2 MODULE SPECIFICATION

**Version**: 1.0.0
**Created**: February 1, 2026
**Purpose**: Module-level architecture specification for all Thea components

---

## TABLE OF CONTENTS

1. [Module Overview](#1-module-overview)
2. [AI Modules](#2-ai-modules)
3. [Core Modules](#3-core-modules)
4. [UI Modules](#4-ui-modules)
5. [Integration Modules](#5-integration-modules)
6. [Platform Modules](#6-platform-modules)
7. [Module Dependencies](#7-module-dependencies)

---

## 1. MODULE OVERVIEW

### 1.1 Module Categories

| Category | Modules | Lines of Code | Primary Responsibility |
|----------|---------|---------------|------------------------|
| AI | 16 | ~46,000 | AI orchestration, learning, verification |
| Core | 12 | ~15,000 | Services, data models, configuration |
| UI | 8 | ~35,000 | Views, components, themes |
| Integration | 15 | ~27,000 | External system connections |
| Platform | 5 | ~5,000 | Platform-specific implementations |
| **Total** | **56** | **~128,000** | |

### 1.2 Module Naming Conventions

- **Managers**: Stateful coordinators (e.g., `SettingsManager`, `WindowManager`)
- **Services**: Stateless operations (e.g., `ProjectService`, `MemoryService`)
- **Engines**: Processing logic (e.g., `DeepAgentEngine`, `ReActExecutor`)
- **Providers**: External integrations (e.g., `AnthropicProvider`, `OpenAIProvider`)
- **Views**: SwiftUI components (e.g., `ChatView`, `SettingsView`)
- **ViewModels**: View state managers (e.g., `ChatViewModel`, `HomeViewModel`)

---

## 2. AI MODULES

### 2.1 Verification Module (`/Shared/AI/Verification/`)

**Purpose**: AI-powered response validation and confidence calculation

| File | Responsibility | Key Types |
|------|----------------|-----------|
| `ConfidenceSystem.swift` | Central coordinator | `ConfidenceSystem`, `ConfidenceResult` |
| `MultiModelConsensus.swift` | Cross-model validation | `MultiModelConsensus`, `ConsensusResult` |
| `WebSearchVerifier.swift` | Fact-checking via web | `WebSearchVerifier`, `VerifiedClaim` |
| `CodeExecutionVerifier.swift` | Code execution testing | `CodeExecutionVerifier`, `CodeExecResult` |
| `StaticAnalysisVerifier.swift` | Static code analysis | `StaticAnalysisVerifier`, `StaticAnalysisResult` |
| `UserFeedbackLearner.swift` | Feedback learning | `UserFeedbackLearner`, `FeedbackRecord` |

**Dependencies**: ProviderRegistry, EventBus, SettingsManager

**Public API**:
```swift
// Main entry point
ConfidenceSystem.shared.validateResponse(
    _ response: String,
    query: String,
    taskType: TaskType,
    context: ValidationContext
) async -> ConfidenceResult

// Record feedback
ConfidenceSystem.shared.recordFeedback(
    responseId: UUID,
    wasCorrect: Bool,
    userCorrection: String?,
    taskType: TaskType
) async
```

### 2.2 Memory Module (`/Shared/AI/Memory/`)

**Purpose**: Multi-tier memory system with AI-powered retrieval

| File | Responsibility | Key Types |
|------|----------------|-----------|
| `ConversationMemory.swift` | Conversation history | `ConversationMemory`, `LearnedFact` |
| `ActiveMemoryRetrieval.swift` | Context retrieval | `ActiveMemoryRetrieval`, `RetrievalSource` |
| `MemoryAugmentedChat.swift` | Chat integration | `MemoryAugmentedChat`, `AugmentedMessage` |

**Dependencies**: MemorySystem, KnowledgeGraph, EventBus

**Public API**:
```swift
// Retrieve context
ActiveMemoryRetrieval.shared.retrieveContext(
    for query: String,
    conversationId: UUID?,
    projectId: UUID?,
    taskType: TaskType?
) async -> ActiveRetrievalResult

// Augment prompt
MemoryAugmentedChat.shared.processMessage(
    _ userMessage: String,
    conversationId: UUID,
    projectId: UUID?,
    existingMessages: [AIMessage]
) async -> AugmentedMessage
```

### 2.3 MetaAI Module (`/Shared/AI/MetaAI/`)

**Purpose**: Advanced AI orchestration and self-improvement

| File | Responsibility | Key Types |
|------|----------------|-----------|
| `MemorySystem.swift` | Multi-tier storage | `MemorySystem`, `Memory`, `EpisodicMemory` |
| `KnowledgeGraph.swift` | Semantic relationships | `KnowledgeGraph`, `KnowledgeNode` |
| `ErrorKnowledgeBase.swift` | Error patterns | `ErrorKnowledgeBase`, `ErrorPattern` |
| `WorkflowBuilder.swift` | Workflow creation | `WorkflowBuilder`, `Workflow` |
| `PluginSystem.swift` | Plugin management | `PluginSystem`, `Plugin` |
| `ToolFramework.swift` | Tool execution | `ToolFramework`, `Tool` |

**Sub-module**: SelfExecution
| File | Responsibility |
|------|----------------|
| `TaskAnalyzer.swift` | Task decomposition |
| `ExecutionOrchestrator.swift` | Multi-step execution |
| `VerificationEngine.swift` | Output verification |

### 2.4 Providers Module (`/Shared/AI/Providers/`)

**Purpose**: AI provider implementations and registry

| File | Responsibility | Provider |
|------|----------------|----------|
| `ProviderRegistry.swift` | Provider management | All |
| `AnthropicProvider.swift` | Claude integration | Anthropic |
| `OpenAIProvider.swift` | GPT integration | OpenAI |
| `GoogleProvider.swift` | Gemini integration | Google |
| `GroqProvider.swift` | Groq integration | Groq |
| `PerplexityProvider.swift` | Search + AI | Perplexity |
| `OpenRouterProvider.swift` | Multi-model | OpenRouter |
| `OllamaProvider.swift` | Local models | Ollama |

**Common Interface**:
```swift
protocol AIProvider {
    var id: String { get }
    var name: String { get }
    var isConfigured: Bool { get }
    var supportedModels: [AIModel] { get }

    func chat(
        messages: [AIMessage],
        model: String,
        stream: Bool
    ) async throws -> AsyncThrowingStream<StreamChunk, Error>
}
```

### 2.5 ModelSelection Module (`/Shared/AI/ModelSelection/`)

**Purpose**: Intelligent model routing

| File | Responsibility | Key Types |
|------|----------------|-----------|
| `TaskClassifier.swift` | Task categorization | `TaskClassifier`, `TaskClassification` |
| `ModelRouter.swift` | Model selection | `ModelRouter`, `RoutingDecision` |
| `QueryDecomposer.swift` | Query breakdown | `QueryDecomposer`, `SubQuery` |

### 2.6 Learning Module (`/Shared/AI/Learning/`)

**Purpose**: Continuous improvement from patterns

| File | Responsibility |
|------|----------------|
| `SwiftKnowledgeLearner.swift` | Swift best practices |
| `AIIntelligence.swift` | Dynamic AI enhancement |
| `SwiftCodeAnalyzer.swift` | Code quality analysis |

### 2.7 PromptEngineering Module (`/Shared/AI/PromptEngineering/`)

**Purpose**: Automatic prompt optimization

| File | Responsibility |
|------|----------------|
| `PromptOptimizer.swift` | Prompt enhancement |
| `PromptTemplates.swift` | Template library |
| `PromptEngineeringModels.swift` | Data models |

---

## 3. CORE MODULES

### 3.1 Services Module (`/Shared/Core/Services/`)

**Purpose**: Core business logic services

| Service | Responsibility | Protocol |
|---------|----------------|----------|
| `ProjectService.swift` | Project CRUD | `ProjectServiceProtocol` |
| `MemoryService.swift` | Memory operations | - |
| `CodeService.swift` | Code operations | - |
| `ConversationService.swift` | Chat operations | `ConversationServiceProtocol` |

### 3.2 Managers Module (`/Shared/Core/Managers/`)

**Purpose**: Stateful coordinators

| Manager | Responsibility | State |
|---------|----------------|-------|
| `SettingsManager.swift` | App settings | `@Published` properties |
| `WindowManager.swift` | Window control | Window references |
| `KnowledgeManager.swift` | Knowledge access | Graph state |
| `ErrorKnowledgeBaseManager.swift` | Error patterns | Error history |

### 3.3 EventBus Module (`/Shared/Core/EventBus/`)

**Purpose**: Event-sourcing foundation

| Type | Purpose | Example |
|------|---------|---------|
| `TheaEvent` | Base protocol | All events |
| `MessageEvent` | Chat messages | User/AI messages |
| `ActionEvent` | AI actions | Code execution, web search |
| `ErrorEvent` | Errors | Recoverable/fatal errors |
| `LearningEvent` | Learning | Pattern detection |

**Event Flow**:
```
User Action → EventBus.publish() → Category Subscribers + Global Subscribers → Persistence
```

### 3.4 Configuration Module (`/Shared/Core/Configuration/`)

**Purpose**: Centralized configuration

| File | Responsibility |
|------|----------------|
| `AppConfiguration.swift` | All app config |
| `ProviderConfiguration.swift` | API endpoints |
| `MemoryConfiguration.swift` | Memory settings |
| `AgentConfiguration.swift` | Agent behavior |

### 3.5 Models Module (`/Shared/Core/Models/`)

**Purpose**: Shared data models

| Model | Purpose | Persistence |
|-------|---------|-------------|
| `AIMessage.swift` | Chat message | SwiftData |
| `Conversation.swift` | Chat thread | SwiftData |
| `Project.swift` | Project metadata | SwiftData |
| `AIModel.swift` | Model info | Memory |

---

## 4. UI MODULES

### 4.1 Views Module (`/Shared/UI/Views/`)

**Purpose**: Main application views

| View Category | Files | Purpose |
|---------------|-------|---------|
| Chat | `ChatView`, `MessageBubble` | Main chat interface |
| Settings | 25+ files | Configuration UI |
| MetaAI | `KnowledgeGraphViewer`, `WorkflowBuilderView` | AI tools |
| Terminal | `TerminalView`, `CommandHistoryView` | Terminal access |
| Cowork | `CoworkView`, `CoworkProgressView` | Task execution |

### 4.2 Components Module (`/Shared/UI/Components/`)

**Purpose**: Reusable UI components

| Component | Purpose | Used In |
|-----------|---------|---------|
| `ConfidenceIndicatorViews.swift` | Confidence display | MessageBubble |
| `MemoryContextView.swift` | Memory sources | ChatView |
| `ChatInputView.swift` | Message input | ChatView |
| `ModelSelectorView.swift` | Model picker | Settings, Chat |
| `CommandPalette.swift` | Quick actions | Global |

### 4.3 ViewModels Module (`/Shared/UI/ViewModels/`)

**Purpose**: View state management

| ViewModel | View | State |
|-----------|------|-------|
| `ChatViewModel` | ChatView | Messages, streaming |
| `HomeViewModel` | HomeView | Projects, recent |
| `SettingsViewModel` | SettingsView | All settings |
| `ConversationListViewModel` | Sidebar | Conversations |

### 4.4 Theme Module (`/Shared/UI/Theme/`)

**Purpose**: Visual theming

| File | Purpose |
|------|---------|
| `Colors.swift` | Color palette |
| `Fonts.swift` | Typography |
| `FontManager.swift` | Font loading |
| `PlatformColors.swift` | Platform-specific |

---

## 5. INTEGRATION MODULES

### 5.1 Health Integration (`/Shared/Integrations/Health/`)

**Purpose**: HealthKit data access

| Component | Responsibility |
|-----------|----------------|
| `HealthKitManager.swift` | Data fetching |
| `HealthDashboardView.swift` | Visualization |
| `HealthInsightsService.swift` | AI insights |

### 5.2 Life Tracking Integrations

| Module | Purpose | Data |
|--------|---------|------|
| `Wellness/` | Wellness tracking | Mood, stress, energy |
| `Nutrition/` | Diet tracking | Meals, nutrients |
| `Cognitive/` | Mental tracking | Focus, creativity |
| `Career/` | Career tracking | Goals, achievements |
| `Income/` | Finance tracking | Income, expenses |

### 5.3 System Integrations

| Module | Purpose | APIs Used |
|--------|---------|-----------|
| `Spotlight/` | Search indexing | CoreSpotlight |
| `Continuity/` | Device handoff | NSUserActivity |
| `HomeKit/` | Smart home | HomeKit |
| `ControlCenter/` | System widgets | WidgetKit |

---

## 6. PLATFORM MODULES

### 6.1 Platform-Specific (`/Shared/Platforms/`)

| Platform | Files | Purpose |
|----------|-------|---------|
| `macOS/` | MenuBar, TouchBar | macOS features |
| `iOS/` | Widgets, Shortcuts | iOS features |
| `watchOS/` | Complications | Watch features |
| `tvOS/` | TopShelf | TV features |
| `visionOS/` | Spatial | Vision features |

---

## 7. MODULE DEPENDENCIES

### 7.1 Dependency Graph

```
┌──────────────────────────────────────────────────────────────────┐
│                          UI Layer                                 │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐               │
│  │   Views     │  │ Components  │  │ ViewModels  │               │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘               │
└─────────┼────────────────┼────────────────┼──────────────────────┘
          │                │                │
          ▼                ▼                ▼
┌──────────────────────────────────────────────────────────────────┐
│                        AI Layer                                   │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐               │
│  │ Verification│  │   Memory    │  │  Providers  │               │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘               │
│         │                │                │                       │
│  ┌──────┴──────┐  ┌──────┴──────┐  ┌──────┴──────┐               │
│  │   MetaAI    │  │  Learning   │  │  Selection  │               │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘               │
└─────────┼────────────────┼────────────────┼──────────────────────┘
          │                │                │
          ▼                ▼                ▼
┌──────────────────────────────────────────────────────────────────┐
│                        Core Layer                                 │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐               │
│  │  Services   │  │  Managers   │  │  EventBus   │               │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘               │
│         │                │                │                       │
│         └────────────────┼────────────────┘                       │
│                          ▼                                        │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐               │
│  │   Models    │  │   Config    │  │   Helpers   │               │
│  └─────────────┘  └─────────────┘  └─────────────┘               │
└──────────────────────────────────────────────────────────────────┘
          │                │                │
          ▼                ▼                ▼
┌──────────────────────────────────────────────────────────────────┐
│                    Integration Layer                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐               │
│  │   Health    │  │  Spotlight  │  │  HomeKit    │               │
│  └─────────────┘  └─────────────┘  └─────────────┘               │
└──────────────────────────────────────────────────────────────────┘
```

### 7.2 Module Communication Rules

1. **UI → AI**: ViewModels call AI services, never directly
2. **AI → Core**: All AI modules use Core services and EventBus
3. **Core → Integration**: Services coordinate integration access
4. **No Circular**: Dependencies flow downward only

### 7.3 Shared State

| State | Owner | Consumers |
|-------|-------|-----------|
| Settings | `SettingsManager.shared` | All modules |
| Providers | `ProviderRegistry.shared` | AI modules |
| Events | `EventBus.shared` | All modules |
| Memory | `MemorySystem.shared` | AI, UI modules |
| Confidence | `ConfidenceSystem.shared` | AI, UI modules |

---

## APPENDIX: Module File Counts

| Module Path | File Count | LOC Estimate |
|-------------|------------|--------------|
| `/Shared/AI/Verification/` | 6 | ~1,800 |
| `/Shared/AI/Memory/` | 3 | ~1,200 |
| `/Shared/AI/MetaAI/` | 12 | ~4,500 |
| `/Shared/AI/Providers/` | 8 | ~3,200 |
| `/Shared/AI/ModelSelection/` | 3 | ~1,500 |
| `/Shared/Core/` | 25 | ~8,000 |
| `/Shared/UI/Views/` | 60+ | ~20,000 |
| `/Shared/UI/Components/` | 15 | ~5,000 |
| `/Shared/Integrations/` | 78 | ~27,000 |

---

*This L2 specification defines module boundaries, responsibilities, and interfaces. See THEA_L3_FILE_SPEC.md for detailed file-level documentation.*
