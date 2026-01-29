import Foundation

// MARK: - App Configuration

// Centralized configuration for all hardcoded values
// All settings are persisted via UserDefaults with sensible defaults

@MainActor
@Observable
final class AppConfiguration {
    static let shared = AppConfiguration()

    private let defaults = UserDefaults.standard

    private init() {}

    // MARK: - App Info

    enum AppInfo {
        static let version = "1.4.0"
        static let buildType = "Beta"
        static let domain = "theathe.app"
        static let bundleIdentifier = "app.thea.Thea"
        // swiftlint:disable:next force_unwrapping
        static let websiteURL = URL(string: "https://theathe.app")!
        // swiftlint:disable:next force_unwrapping
        static let privacyPolicyURL = URL(string: "https://theathe.app/privacy")!
        // swiftlint:disable:next force_unwrapping
        static let termsOfServiceURL = URL(string: "https://theathe.app/terms")!
    }

    // MARK: - Provider Configuration

    var providerConfig: ProviderConfiguration {
        get {
            if let data = defaults.data(forKey: "AppConfiguration.providerConfig"),
               let config = try? JSONDecoder().decode(ProviderConfiguration.self, from: data)
            {
                return config
            }
            return ProviderConfiguration()
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: "AppConfiguration.providerConfig")
            }
        }
    }

    // MARK: - Memory System Configuration

    var memoryConfig: MemoryConfiguration {
        get {
            if let data = defaults.data(forKey: "AppConfiguration.memoryConfig"),
               let config = try? JSONDecoder().decode(MemoryConfiguration.self, from: data)
            {
                return config
            }
            return MemoryConfiguration()
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: "AppConfiguration.memoryConfig")
            }
        }
    }

    // MARK: - Agent Configuration

    var agentConfig: AgentConfiguration {
        get {
            if let data = defaults.data(forKey: "AppConfiguration.agentConfig"),
               let config = try? JSONDecoder().decode(AgentConfiguration.self, from: data)
            {
                return config
            }
            return AgentConfiguration()
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: "AppConfiguration.agentConfig")
            }
        }
    }

    // MARK: - Execution Mode Configuration

    var executionMode: ExecutionModeConfiguration {
        get {
            if let data = defaults.data(forKey: "AppConfiguration.executionMode"),
               let config = try? JSONDecoder().decode(ExecutionModeConfiguration.self, from: data)
            {
                return config
            }
            return ExecutionModeConfiguration()
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: "AppConfiguration.executionMode")
            }
        }
    }

    // MARK: - Local Model Configuration

    var localModelConfig: LocalModelConfiguration {
        get {
            if let data = defaults.data(forKey: "AppConfiguration.localModelConfig"),
               let config = try? JSONDecoder().decode(LocalModelConfiguration.self, from: data)
            {
                return config
            }
            return LocalModelConfiguration()
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: "AppConfiguration.localModelConfig")
            }
        }
    }

    // MARK: - Orchestrator Configuration

    var orchestratorConfig: OrchestratorConfiguration {
        get {
            if let data = defaults.data(forKey: "AppConfiguration.orchestratorConfig"),
               let config = try? JSONDecoder().decode(OrchestratorConfiguration.self, from: data)
            {
                return config
            }
            return OrchestratorConfiguration()
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: "AppConfiguration.orchestratorConfig")
            }
        }
    }

    // MARK: - Theme Configuration

    var themeConfig: ThemeConfiguration {
        get {
            if let data = defaults.data(forKey: "AppConfiguration.themeConfig"),
               let config = try? JSONDecoder().decode(ThemeConfiguration.self, from: data)
            {
                return config
            }
            return ThemeConfiguration()
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: "AppConfiguration.themeConfig")
            }
        }
    }

    // MARK: - Voice Configuration

    var voiceConfig: VoiceConfiguration {
        get {
            if let data = defaults.data(forKey: "AppConfiguration.voiceConfig"),
               let config = try? JSONDecoder().decode(VoiceConfiguration.self, from: data)
            {
                return config
            }
            return VoiceConfiguration()
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: "AppConfiguration.voiceConfig")
            }
        }
    }

    // MARK: - Knowledge Scanner Configuration

    var knowledgeScannerConfig: KnowledgeScannerConfiguration {
        get {
            if let data = defaults.data(forKey: "AppConfiguration.knowledgeScannerConfig"),
               let config = try? JSONDecoder().decode(KnowledgeScannerConfiguration.self, from: data)
            {
                return config
            }
            return KnowledgeScannerConfiguration()
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: "AppConfiguration.knowledgeScannerConfig")
            }
        }
    }

    // MARK: - Code Intelligence Configuration

    var codeIntelligenceConfig: CodeIntelligenceConfiguration {
        get {
            if let data = defaults.data(forKey: "AppConfiguration.codeIntelligenceConfig"),
               let config = try? JSONDecoder().decode(CodeIntelligenceConfiguration.self, from: data)
            {
                return config
            }
            return CodeIntelligenceConfiguration()
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: "AppConfiguration.codeIntelligenceConfig")
            }
        }
    }

    // MARK: - API Validation Configuration

    var apiValidationConfig: APIValidationConfiguration {
        get {
            if let data = defaults.data(forKey: "AppConfiguration.apiValidationConfig"),
               let config = try? JSONDecoder().decode(APIValidationConfiguration.self, from: data)
            {
                return config
            }
            return APIValidationConfiguration()
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: "AppConfiguration.apiValidationConfig")
            }
        }
    }

    // MARK: - External APIs Configuration

    var externalAPIsConfig: ExternalAPIsConfiguration {
        get {
            if let data = defaults.data(forKey: "AppConfiguration.externalAPIsConfig"),
               let config = try? JSONDecoder().decode(ExternalAPIsConfiguration.self, from: data)
            {
                return config
            }
            return ExternalAPIsConfiguration()
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: "AppConfiguration.externalAPIsConfig")
            }
        }
    }

    // MARK: - Meta-AI Features Configuration

    var metaAIConfig: MetaAIConfiguration {
        get {
            if let data = defaults.data(forKey: "AppConfiguration.metaAIConfig"),
               let config = try? JSONDecoder().decode(MetaAIConfiguration.self, from: data)
            {
                return config
            }
            return MetaAIConfiguration()
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: "AppConfiguration.metaAIConfig")
            }
        }
    }

    // MARK: - Prompt Engineering Configuration

    var promptEngineeringConfig: PromptEngineeringConfiguration {
        get {
            if let data = defaults.data(forKey: "AppConfiguration.promptEngineeringConfig"),
               let config = try? JSONDecoder().decode(PromptEngineeringConfiguration.self, from: data)
            {
                return config
            }
            return PromptEngineeringConfiguration()
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: "AppConfiguration.promptEngineeringConfig")
            }
        }
    }

    // MARK: - Life Tracking Configuration

    var lifeTrackingConfig: LifeTrackingConfiguration {
        get {
            if let data = defaults.data(forKey: "AppConfiguration.lifeTrackingConfig"),
               let config = try? JSONDecoder().decode(LifeTrackingConfiguration.self, from: data)
            {
                return config
            }
            return LifeTrackingConfiguration()
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: "AppConfiguration.lifeTrackingConfig")
            }
        }
    }

    // MARK: - QA Tools Configuration

    var qaToolsConfig: QAToolsConfiguration {
        get {
            if let data = defaults.data(forKey: "AppConfiguration.qaToolsConfig"),
               let config = try? JSONDecoder().decode(QAToolsConfiguration.self, from: data)
            {
                return config
            }
            return QAToolsConfiguration()
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: "AppConfiguration.qaToolsConfig")
            }
        }
    }

    // MARK: - Reset to Defaults

    func resetAllToDefaults() {
        providerConfig = ProviderConfiguration()
        memoryConfig = MemoryConfiguration()
        agentConfig = AgentConfiguration()
        localModelConfig = LocalModelConfiguration()
        themeConfig = ThemeConfiguration()
        voiceConfig = VoiceConfiguration()
        knowledgeScannerConfig = KnowledgeScannerConfiguration()
        codeIntelligenceConfig = CodeIntelligenceConfiguration()
        apiValidationConfig = APIValidationConfiguration()
        externalAPIsConfig = ExternalAPIsConfiguration()
        metaAIConfig = MetaAIConfiguration()
        promptEngineeringConfig = PromptEngineeringConfiguration()
        lifeTrackingConfig = LifeTrackingConfiguration()
        qaToolsConfig = QAToolsConfiguration()
    }

    func resetProviderConfig() {
        providerConfig = ProviderConfiguration()
    }

    func resetVoiceConfig() {
        voiceConfig = VoiceConfiguration()
    }

    func resetKnowledgeScannerConfig() {
        knowledgeScannerConfig = KnowledgeScannerConfiguration()
    }

    func resetMetaAIConfig() {
        metaAIConfig = MetaAIConfiguration()
    }

    func resetQAToolsConfig() {
        qaToolsConfig = QAToolsConfiguration()
    }
}

// MARK: - Provider Configuration

struct ProviderConfiguration: Codable, Sendable, Equatable {
    // API Endpoints
    var anthropicBaseURL: String = "https://api.anthropic.com/v1"
    var anthropicAPIVersion: String = "2023-06-01"
    var openAIBaseURL: String = "https://api.openai.com/v1"
    var googleBaseURL: String = "https://generativelanguage.googleapis.com/v1beta"
    var groqBaseURL: String = "https://api.groq.com/openai/v1"
    var perplexityBaseURL: String = "https://api.perplexity.ai"
    var openRouterBaseURL: String = "https://openrouter.ai/api/v1"

    // Generation Defaults
    var defaultMaxTokens: Int = 8192
    var defaultTemperature: Double = 1.0
    var defaultTopP: Double = 1.0
    var streamResponses: Bool = true

    // Model Defaults
    var defaultModel: String = "gpt-4o"
    var defaultSummarizationModel: String = "gpt-4o-mini"
    var defaultReasoningModel: String = "gpt-4o"
    var defaultEmbeddingModel: String = "text-embedding-3-small"
    var embeddingDimensions: Int = 1536

    // Request Settings
    var requestTimeoutSeconds: Double = 60.0
    var maxRetries: Int = 3
    var retryDelaySeconds: Double = 1.0
}

// MARK: - Memory Configuration

struct MemoryConfiguration: Codable, Sendable, Equatable {
    // Capacity
    var shortTermCapacity: Int = 20
    var longTermMaxItems: Int = 10000
    var episodicMaxItems: Int = 5000
    var semanticMaxItems: Int = 5000
    var proceduralMaxItems: Int = 1000

    // Consolidation
    var consolidationThresholdSeconds: TimeInterval = 300 // 5 minutes
    var consolidationMinImportance: Float = 0.3

    // Decay
    var generalDecayRate: Float = 0.95
    var semanticDecayRate: Float = 0.98
    var minImportanceThreshold: Float = 0.1

    // Retrieval
    var defaultSimilarityThreshold: Float = 0.7
    var compressionSimilarityThreshold: Float = 0.5
    var defaultRetrievalLimit: Int = 10
    var episodicRetrievalLimit: Int = 5
    var semanticRetrievalLimit: Int = 5
    var proceduralRetrievalLimit: Int = 3

    // Boosts
    var importanceBoostFactor: Float = 0.2
    var recencyBoostMax: Float = 0.2
    var accessBoostFactor: Float = 0.01
    var accessImportanceBoost: Float = 1.05

    // Important Keywords
    var importantKeywords: [String] = [
        "critical", "important", "remember", "never", "always", "key",
        "urgent", "priority", "essential", "vital", "crucial"
    ]
}

// MARK: - Agent Configuration

struct AgentConfiguration: Codable, Sendable, Equatable {
    // Task Execution
    var maxRetryCount: Int = 3
    var baseTaskDurationSeconds: TimeInterval = 30
    var dependencyWaitIntervalMs: UInt64 = 100_000_000 // 100ms in nanoseconds
    var consolidationIntervalSeconds: TimeInterval = 60

    // Verification
    var defaultConfidence: Double = 0.5
    var minAcceptableConfidence: Double = 0.7

    // Sub-Agents
    var maxConcurrentAgents: Int = 5
    var agentTimeoutSeconds: TimeInterval = 300

    // Reasoning
    var chainOfThoughtSteps: Int = 4
    var maxDecompositionSteps: Int = 10
    var reasoningTemperature: Double = 0.7
}

// MARK: - Local Model Configuration

struct LocalModelConfiguration: Codable, Sendable, Equatable {
    // Ollama
    var ollamaBaseURL: String = "http://localhost:11434"
    var ollamaExecutablePath: String = "/usr/local/bin/ollama"
    var ollamaAPIEndpoint: String = "/api/generate"

    // MLX
    var mlxExecutablePath: String = "/usr/local/bin/mlx_lm"
    var mlxModelsDirectory: String = "mlx-models"

    // GGUF
    var ggufModelsDirectory: String = "gguf-models"
    var lmStudioCachePath: String = ".cache/lm-studio/models"

    // SharedLLMs (default local model location)
    var sharedLLMsDirectory: String = "Library/Application Support/SharedLLMs"

    // Defaults
    var defaultContextTokens: Int = 4096
    var defaultMaxOutputTokens: Int = 2048
    var defaultQuantization: String = "Q4_K_M"
    var defaultParameters: String = "7B"

    // System
    var whichExecutablePath: String = "/usr/bin/which"
}

// MARK: - Theme Configuration

struct ThemeConfiguration: Codable, Sendable, Equatable {
    // Colors (stored as hex strings)
    var primaryColor: String = "0066FF"
    var accentColor: String = "00D4AA"
    var purpleColor: String = "8B5CF6"
    var goldColor: String = "FFB84D"

    // Font Sizes
    var displaySize: CGFloat = 34
    var title1Size: CGFloat = 28
    var title2Size: CGFloat = 22
    var title3Size: CGFloat = 20
    var headlineSize: CGFloat = 17
    var bodySize: CGFloat = 17
    var calloutSize: CGFloat = 16
    var subheadSize: CGFloat = 15
    var footnoteSize: CGFloat = 13
    var caption1Size: CGFloat = 12
    var caption2Size: CGFloat = 11
    var codeSize: CGFloat = 14
    var codeInlineSize: CGFloat = 16

    // Font Weights (as raw values for encoding)
    var displayWeight: String = "bold"
    var title1Weight: String = "bold"
    var title2Weight: String = "semibold"
    var title3Weight: String = "semibold"
    var headlineWeight: String = "semibold"
    var bodyWeight: String = "regular"

    // Font Design
    var useRoundedDesign: Bool = true
}

// MARK: - Voice Configuration

struct VoiceConfiguration: Codable, Sendable, Equatable {
    // Wake Words
    var wakeWords: [String] = ["hey thea", "hey tia", "ok thea"]
    var wakeWordEnabled: Bool = true

    // Speech Recognition
    var recognitionLanguage: String = "en-US"
    var requiresOnDeviceRecognition: Bool = true
    var audioBufferSize: Int = 1024

    // Speech Synthesis
    var speechLanguage: String = "en-US"
    var speechRate: Float = 0.5
    var pitchMultiplier: Float = 1.0
    var volume: Float = 1.0

    // Conversation Mode
    var silenceThresholdSeconds: TimeInterval = 2.0
    var conversationTimeoutSeconds: TimeInterval = 30.0

    // Model
    var voiceAssistantModel: String = "gpt-4o-mini"

    // Feedback
    var activationSoundEnabled: Bool = true
    var activationSoundID: UInt32 = 1054 // System tock sound
}

// MARK: - Knowledge Scanner Configuration

struct KnowledgeScannerConfiguration: Codable, Sendable, Equatable {
    // Supported File Extensions (by category)
    var codeExtensions: [String] = [
        "swift", "py", "js", "ts", "jsx", "tsx", "go", "rs", "java", "cpp", "c", "h",
        "kt", "scala", "rb", "php", "cs", "m", "mm"
    ]
    var documentExtensions: [String] = ["md", "txt", "pdf", "docx", "doc", "rtf"]
    var dataExtensions: [String] = ["json", "yaml", "yml", "xml", "csv", "toml"]
    var configExtensions: [String] = ["conf", "config", "ini", "env"]
    var otherExtensions: [String] = ["note", "fountain", "log"]

    // All supported extensions (computed from above)
    var allSupportedExtensions: [String] {
        codeExtensions + documentExtensions + dataExtensions + configExtensions + otherExtensions
    }

    // File Limits
    var maxFileSizeBytes: Int64 = 10_000_000 // 10MB
    var indexingBatchSize: Int = 100

    // Embedding
    var embeddingDimension: Int = 384

    // Search Defaults
    var defaultSearchTopK: Int = 10
    var fullTextSearchTopK: Int = 10

    // Relevance Scoring
    var filenameMatchBonus: Float = 0.5
    var contentMatchBonus: Float = 0.1
    var maxContentMatchBonus: Int = 10
    var recentFileBonus: Float = 0.3
    var moderateRecentFileBonus: Float = 0.1
    var recentFileDaysThreshold: Double = 7
    var moderateRecentFileDaysThreshold: Double = 30

    // File Watching
    var enableFileWatching: Bool = true
}

// MARK: - Code Intelligence Configuration

struct CodeIntelligenceConfiguration: Codable, Sendable, Equatable {
    // Models
    var codeCompletionModel: String = "gpt-4o-mini"
    var codeExplanationModel: String = "gpt-4o"
    var codeReviewModel: String = "gpt-4o"

    // Executable Paths
    var gitExecutablePath: String = "/usr/bin/git"
    var swiftExecutablePath: String = "/usr/bin/swift"
    var pythonExecutablePath: String = "/usr/bin/python3"
    var nodeExecutablePath: String = "/usr/bin/env"

    // Code Extensions (for project scanning)
    var codeFileExtensions: [String] = [
        "swift", "py", "js", "ts", "tsx", "jsx", "go", "rs",
        "java", "kt", "cpp", "c", "h", "m", "mm"
    ]
}

// MARK: - API Validation Configuration

struct APIValidationConfiguration: Codable, Sendable, Equatable {
    // Test models used for validating API keys
    var anthropicTestModel: String = "claude-3-5-sonnet-20241022"
    var openAITestModel: String = "gpt-4o-mini"
    var googleTestModel: String = "gemini-1.5-flash"
    var groqTestModel: String = "llama-3.1-8b-instant"
    var perplexityTestModel: String = "llama-3.1-sonar-small-128k-online"
    var openRouterTestModel: String = "openai/gpt-4o-mini"
}

// MARK: - External APIs Configuration

struct ExternalAPIsConfiguration: Codable, Sendable, Equatable {
    // GitHub
    var githubAPIBaseURL: String = "https://api.github.com"

    // Weather
    var openWeatherMapBaseURL: String = "https://api.openweathermap.org"

    // Add more external API endpoints as needed
}

// MARK: - Meta-AI Features Configuration

struct MetaAIConfiguration: Codable, Sendable, Equatable {
    // Core Systems
    var enableSubAgents: Bool = true
    var enableReflection: Bool = true
    var enableKnowledgeGraph: Bool = true
    var enableMemorySystem: Bool = true
    var enableReasoning: Bool = true

    // Capabilities
    var enableDynamicTools: Bool = true
    var enableCodeSandbox: Bool = false
    var enableBrowserAutomation: Bool = false

    // Advanced Features
    var enableAgentSwarms: Bool = false
    var maxConcurrentSwarmAgents: Int = 5

    // Workflow
    var maxWorkflowSteps: Int = 50
    var workflowTimeoutSeconds: TimeInterval = 600

    // Plugin System
    var enablePlugins: Bool = true
    var trustedPluginSources: [String] = []

    // AI Models for Meta-AI Components
    // These are default cloud models; the orchestrator will use local models
    // when localModelPreference is set to prefer/always in OrchestratorConfiguration
    var orchestratorModel: String = "gpt-4o"
    var reflectionModel: String = "gpt-4o"
    var knowledgeGraphModel: String = "gpt-4o"
    var reasoningModel: String = "gpt-4o"
    var plannerModel: String = "gpt-4o"
    var validatorModel: String = "gpt-4o"
    var optimizerModel: String = "gpt-4o"
    var coderModel: String = "gpt-4o"
    var executorModel: String = "gpt-4o"
    var integratorModel: String = "gpt-4o"
}

// MARK: - Prompt Engineering Configuration

struct PromptEngineeringConfiguration: Codable, Sendable, Equatable {
    var enableAutoOptimization: Bool = true
    var enableFewShotLearning: Bool = true
    var enableABTesting: Bool = true
    var maxFewShotExamples: Int = 3
    var templateRefreshInterval: TimeInterval = 86400 // 24 hours
    var minTemplateSuccessRate: Float = 0.7
    var enableUserPreferenceLearning: Bool = true
    var enableTemplateVersioning: Bool = true
    var autoRecordOutcomes: Bool = true
    var confidenceThreshold: Float = 0.8
}

// MARK: - Life Tracking Configuration

struct LifeTrackingConfiguration: Codable, Sendable, Equatable {
    // Tracking Toggles
    var healthTrackingEnabled: Bool = false
    var screenTimeTrackingEnabled: Bool = false
    var inputTrackingEnabled: Bool = false
    var browserTrackingEnabled: Bool = false
    var locationTrackingEnabled: Bool = false

    // Data Retention
    var dataRetentionDays: Int = 90
    var autoDeleteOldData: Bool = true

    // Privacy
    var anonymousInsightsSharing: Bool = false
    var encryptTrackingData: Bool = true

    // Notifications
    var dailyInsightsEnabled: Bool = true
    var weeklyReportEnabled: Bool = true
    var achievementNotificationsEnabled: Bool = true

    // Update Intervals
    var healthSyncInterval: TimeInterval = 3600
    var screenTimeCheckInterval: TimeInterval = 60
    var inputActivityCheckInterval: TimeInterval = 300
    var locationUpdateInterval: TimeInterval = 600
}

// MARK: - Execution Mode Configuration

public struct ExecutionModeConfiguration: Codable, Sendable, Equatable {
    public var mode: ExecutionMode = .normal
    public var requireApprovalForFileEdits: Bool = true
    public var requireApprovalForTerminalCommands: Bool = true
    public var requireApprovalForBrowserActions: Bool = false
    public var requireApprovalForSystemAutomation: Bool = true
    public var autoApproveReadOperations: Bool = true
    public var showPlanBeforeExecution: Bool = true
    public var allowAutonomousContinuation: Bool = false
    public var maxAutonomousSteps: Int = 50
    public var executionTimeoutMinutes: Int = 60
}

public enum ExecutionMode: String, Codable, Sendable, CaseIterable {
    case safe // Ask for approval on every operation
    case normal // Ask for approval on destructive operations only
    case aggressive // Pre-approved, minimal interruptions

    public var displayName: String {
        switch self {
        case .safe: "Safe Mode (Manual Approval)"
        case .normal: "Normal Mode (Smart Approval)"
        case .aggressive: "Aggressive Mode (Autonomous)"
        }
    }

    public var description: String {
        switch self {
        case .safe:
            "Every operation requires manual approval. Best for learning or sensitive work."
        case .normal:
            "Approve plans upfront, allow safe operations automatically. Recommended for most users."
        case .aggressive:
            "Pre-approve all operations. AI continues until mission complete. Use with caution."
        }
    }
}

// MARK: - QA Tools Configuration

struct QAToolsConfiguration: Codable, Sendable, Equatable {
    // SwiftLint Configuration
    var swiftLintEnabled: Bool = true
    var swiftLintExecutablePath: String = "/opt/homebrew/bin/swiftlint"
    var swiftLintConfigPath: String = ".swiftlint.yml"
    var swiftLintAutoFix: Bool = false
    var swiftLintRunOnBuild: Bool = true

    // CodeCov Configuration
    var codeCovEnabled: Bool = false
    var codeCovToken: String = ""
    var codeCovConfigPath: String = "codecov.yml"
    var codeCovUploadOnCI: Bool = true

    // SonarCloud Configuration
    var sonarCloudEnabled: Bool = false
    var sonarCloudToken: String = ""
    var sonarCloudOrganization: String = ""
    var sonarCloudProjectKey: String = ""
    var sonarCloudConfigPath: String = "sonar-project.properties"
    var sonarCloudBaseURL: String = "https://sonarcloud.io"

    // DeepSource Configuration
    var deepSourceEnabled: Bool = false
    var deepSourceDSN: String = ""
    var deepSourceConfigPath: String = ".deepsource.toml"

    // Project Configuration
    var projectRootPath: String = ""
    var xcodeScheme: String = "Thea-macOS"
    var xcodeDestination: String = "platform=macOS"

    // Coverage Settings
    var enableCodeCoverage: Bool = true
    var coverageOutputPath: String = "build/coverage"
    var testResultBundlePath: String = "build/test-results.xcresult"

    // Automation Settings
    var runQAOnBuild: Bool = false
    var runQAOnCommit: Bool = false
    var failBuildOnQAErrors: Bool = true
    var showQANotifications: Bool = true

    // History Settings
    var keepHistoryDays: Int = 30
    var maxHistoryEntries: Int = 100
}

// MARK: - QA Tool Result

struct QAToolResult: Codable, Sendable, Identifiable {
    let id: UUID
    let tool: QATool
    let timestamp: Date
    let success: Bool
    let issuesFound: Int
    let warningsFound: Int
    let errorsFound: Int
    let duration: TimeInterval
    let output: String
    let details: [QAIssue]

    init(
        id: UUID = UUID(),
        tool: QATool,
        timestamp: Date = Date(),
        success: Bool,
        issuesFound: Int = 0,
        warningsFound: Int = 0,
        errorsFound: Int = 0,
        duration: TimeInterval = 0,
        output: String = "",
        details: [QAIssue] = []
    ) {
        self.id = id
        self.tool = tool
        self.timestamp = timestamp
        self.success = success
        self.issuesFound = issuesFound
        self.warningsFound = warningsFound
        self.errorsFound = errorsFound
        self.duration = duration
        self.output = output
        self.details = details
    }
}

// MARK: - QA Tool

enum QATool: String, Codable, Sendable, CaseIterable {
    case swiftLint = "SwiftLint"
    case codeCov = "CodeCov"
    case sonarCloud = "SonarCloud"
    case deepSource = "DeepSource"

    var displayName: String { rawValue }

    var icon: String {
        switch self {
        case .swiftLint: "swift"
        case .codeCov: "chart.pie"
        case .sonarCloud: "cloud"
        case .deepSource: "magnifyingglass.circle"
        }
    }

    var description: String {
        switch self {
        case .swiftLint:
            "Static code analysis for Swift style and conventions"
        case .codeCov:
            "Code coverage reporting and tracking"
        case .sonarCloud:
            "Continuous code quality and security analysis"
        case .deepSource:
            "Automated code review and issue detection"
        }
    }
}

// MARK: - QA Issue

struct QAIssue: Codable, Sendable, Identifiable {
    let id: UUID
    let severity: QAIssueSeverity
    let message: String
    let file: String?
    let line: Int?
    let column: Int?
    let rule: String?

    init(
        id: UUID = UUID(),
        severity: QAIssueSeverity,
        message: String,
        file: String? = nil,
        line: Int? = nil,
        column: Int? = nil,
        rule: String? = nil
    ) {
        self.id = id
        self.severity = severity
        self.message = message
        self.file = file
        self.line = line
        self.column = column
        self.rule = rule
    }
}

// MARK: - QA Issue Severity

enum QAIssueSeverity: String, Codable, Sendable {
    case error
    case warning
    case info
    case hint

    var color: String {
        switch self {
        case .error: "red"
        case .warning: "orange"
        case .info: "blue"
        case .hint: "gray"
        }
    }

    var icon: String {
        switch self {
        case .error: "xmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .info: "info.circle.fill"
        case .hint: "lightbulb.fill"
        }
    }
}
