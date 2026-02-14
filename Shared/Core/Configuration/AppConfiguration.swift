import Foundation

// MARK: - App Configuration

// Centralized configuration for all hardcoded values.
// All settings are persisted via UserDefaults with sensible defaults.
//
// NOTE: try? usage throughout this file is intentional and correct:
// - Getters: try? decode returns nil → falls through to default instance
// - Setters: try? encode only fails if the type has non-Codable properties (impossible for these types)
// Converting these to ErrorLogger would add ~100 lines with no diagnostic value.

@MainActor
@Observable
final class AppConfiguration {
    static let shared = AppConfiguration()

    private let defaults = UserDefaults.standard

    // Stored property for theme so @Observable tracks changes and views re-render
    var themeConfigStored: ThemeConfiguration

    private init() {
        // Load themeConfig from UserDefaults at launch
        if let data = UserDefaults.standard.data(forKey: "AppConfiguration.themeConfig"),
           let config = try? JSONDecoder().decode(ThemeConfiguration.self, from: data)
        {
            themeConfigStored = config
        } else {
            themeConfigStored = ThemeConfiguration()
        }

        // Apply the saved font-size preference so scaled sizes survive restarts.
        // SettingsManager stores the choice under "fontSize" (small/medium/large).
        let savedFontSize = UserDefaults.standard.string(forKey: "fontSize") ?? "medium"
        if savedFontSize != "medium" {
            // Defer to after init completes so `shared` is available.
            // At this point themeConfigStored is set, so we can mutate it directly.
            let scale: CGFloat = savedFontSize == "small" ? 0.85 : 1.25
            themeConfigStored.displaySize = round(34 * scale)
            themeConfigStored.title1Size = round(28 * scale)
            themeConfigStored.title2Size = round(22 * scale)
            themeConfigStored.title3Size = round(20 * scale)
            themeConfigStored.headlineSize = round(17 * scale)
            themeConfigStored.bodySize = round(17 * scale)
            themeConfigStored.calloutSize = round(16 * scale)
            themeConfigStored.subheadSize = round(15 * scale)
            themeConfigStored.footnoteSize = round(13 * scale)
            themeConfigStored.caption1Size = round(12 * scale)
            themeConfigStored.caption2Size = round(11 * scale)
            themeConfigStored.codeSize = round(14 * scale)
            themeConfigStored.codeInlineSize = round(16 * scale)
        }
    }

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

    var memoryConfig: AppMemoryConfiguration {
        get {
            if let data = defaults.data(forKey: "AppConfiguration.memoryConfig"),
               let config = try? JSONDecoder().decode(AppMemoryConfiguration.self, from: data)
            {
                return config
            }
            return AppMemoryConfiguration()
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

    /// Theme config backed by stored property for proper @Observable tracking.
    /// Changes immediately re-render views that read font sizes, colors, etc.
    var themeConfig: ThemeConfiguration {
        get { themeConfigStored }
        set {
            themeConfigStored = newValue
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: "AppConfiguration.themeConfig")
            }
        }
    }

    // MARK: - Font Size Application

    /// Apply the user's font-size preference ("small", "medium", "large") to the
    /// theme configuration.  Call this at startup and whenever the picker changes.
    static func applyFontSize(_ size: String) {
        var config = shared.themeConfig
        let scale: CGFloat = switch size {
        case "small": 0.85
        case "large": 1.25
        default: 1.0
        }

        config.displaySize = round(34 * scale)
        config.title1Size = round(28 * scale)
        config.title2Size = round(22 * scale)
        config.title3Size = round(20 * scale)
        config.headlineSize = round(17 * scale)
        config.bodySize = round(17 * scale)
        config.calloutSize = round(16 * scale)
        config.subheadSize = round(15 * scale)
        config.footnoteSize = round(13 * scale)
        config.caption1Size = round(12 * scale)
        config.caption2Size = round(11 * scale)
        config.codeSize = round(14 * scale)
        config.codeInlineSize = round(16 * scale)

        shared.themeConfig = config
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
        memoryConfig = AppMemoryConfiguration()
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
