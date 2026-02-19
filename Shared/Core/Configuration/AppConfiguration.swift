import Foundation
import OSLog

// MARK: - App Configuration

// Centralized configuration for all hardcoded values.
// All settings are persisted via UserDefaults with sensible defaults.

@MainActor
@Observable
final class AppConfiguration {
    static let shared = AppConfiguration()

    private let defaults = UserDefaults.standard
    private let logger = Logger(subsystem: "app.thea.Thea", category: "AppConfiguration")

    // Stored property for theme so @Observable tracks changes and views re-render
    var themeConfigStored: ThemeConfiguration

    private init() {
        // Load themeConfig from UserDefaults at launch
        if let data = UserDefaults.standard.data(forKey: "AppConfiguration.themeConfig") {
            do {
                themeConfigStored = try JSONDecoder().decode(ThemeConfiguration.self, from: data)
            } catch {
                logger.error("Failed to decode ThemeConfiguration: \(error.localizedDescription)")
                themeConfigStored = ThemeConfiguration()
            }
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
        // periphery:ignore - Reserved: domain static property reserved for future feature activation
        static let privacyPolicyURL = URL(string: "https://theathe.app/privacy")!
        // swiftlint:disable:next force_unwrapping
        static let termsOfServiceURL = URL(string: "https://theathe.app/terms")!
    }

    // MARK: - Provider Configuration

    var providerConfig: ProviderConfiguration {
        get {
            guard let data = defaults.data(forKey: "AppConfiguration.providerConfig") else {
                return ProviderConfiguration()
            }
            do {
                return try JSONDecoder().decode(ProviderConfiguration.self, from: data)
            } catch {
                logger.error("Failed to decode ProviderConfiguration: \(error.localizedDescription)")
                return ProviderConfiguration()
            }
        }
        set {
            do {
                let data = try JSONEncoder().encode(newValue)
                defaults.set(data, forKey: "AppConfiguration.providerConfig")
            } catch {
                logger.error("Failed to encode ProviderConfiguration: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Memory System Configuration

    var memoryConfig: AppMemoryConfiguration {
        get {
            guard let data = defaults.data(forKey: "AppConfiguration.memoryConfig") else {
                return AppMemoryConfiguration()
            }
            do {
                return try JSONDecoder().decode(AppMemoryConfiguration.self, from: data)
            } catch {
                logger.error("Failed to decode AppMemoryConfiguration: \(error.localizedDescription)")
                return AppMemoryConfiguration()
            }
        }
        set {
            do {
                let data = try JSONEncoder().encode(newValue)
                defaults.set(data, forKey: "AppConfiguration.memoryConfig")
            } catch {
                logger.error("Failed to encode AppMemoryConfiguration: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Agent Configuration

    var agentConfig: AgentConfiguration {
        get {
            guard let data = defaults.data(forKey: "AppConfiguration.agentConfig") else {
                return AgentConfiguration()
            }
            do {
                return try JSONDecoder().decode(AgentConfiguration.self, from: data)
            } catch {
                logger.error("Failed to decode AgentConfiguration: \(error.localizedDescription)")
                return AgentConfiguration()
            }
        }
        set {
            do {
                let data = try JSONEncoder().encode(newValue)
                defaults.set(data, forKey: "AppConfiguration.agentConfig")
            } catch {
                logger.error("Failed to encode AgentConfiguration: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Execution Mode Configuration

    var executionMode: ExecutionModeConfiguration {
        get {
            guard let data = defaults.data(forKey: "AppConfiguration.executionMode") else {
                return ExecutionModeConfiguration()
            }
            do {
                return try JSONDecoder().decode(ExecutionModeConfiguration.self, from: data)
            } catch {
                logger.error("Failed to decode ExecutionModeConfiguration: \(error.localizedDescription)")
                return ExecutionModeConfiguration()
            }
        }
        set {
            do {
                let data = try JSONEncoder().encode(newValue)
                defaults.set(data, forKey: "AppConfiguration.executionMode")
            } catch {
                logger.error("Failed to encode ExecutionModeConfiguration: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Local Model Configuration

    var localModelConfig: LocalModelConfiguration {
        get {
            guard let data = defaults.data(forKey: "AppConfiguration.localModelConfig") else {
                return LocalModelConfiguration()
            }
            do {
                return try JSONDecoder().decode(LocalModelConfiguration.self, from: data)
            } catch {
                logger.error("Failed to decode LocalModelConfiguration: \(error.localizedDescription)")
                return LocalModelConfiguration()
            }
        }
        set {
            do {
                let data = try JSONEncoder().encode(newValue)
                defaults.set(data, forKey: "AppConfiguration.localModelConfig")
            } catch {
                logger.error("Failed to encode LocalModelConfiguration: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Orchestrator Configuration

    var orchestratorConfig: OrchestratorConfiguration {
        get {
            guard let data = defaults.data(forKey: "AppConfiguration.orchestratorConfig") else {
                return OrchestratorConfiguration()
            }
            do {
                return try JSONDecoder().decode(OrchestratorConfiguration.self, from: data)
            } catch {
                logger.error("Failed to decode OrchestratorConfiguration: \(error.localizedDescription)")
                return OrchestratorConfiguration()
            }
        }
        set {
            do {
                let data = try JSONEncoder().encode(newValue)
                defaults.set(data, forKey: "AppConfiguration.orchestratorConfig")
            } catch {
                logger.error("Failed to encode OrchestratorConfiguration: \(error.localizedDescription)")
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
            do {
                let data = try JSONEncoder().encode(newValue)
                defaults.set(data, forKey: "AppConfiguration.themeConfig")
            } catch {
                logger.error("Failed to encode ThemeConfiguration: \(error.localizedDescription)")
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
            guard let data = defaults.data(forKey: "AppConfiguration.voiceConfig") else {
                return VoiceConfiguration()
            }
            do {
                return try JSONDecoder().decode(VoiceConfiguration.self, from: data)
            } catch {
                logger.error("Failed to decode VoiceConfiguration: \(error.localizedDescription)")
                return VoiceConfiguration()
            }
        }
        set {
            do {
                let data = try JSONEncoder().encode(newValue)
                defaults.set(data, forKey: "AppConfiguration.voiceConfig")
            } catch {
                logger.error("Failed to encode VoiceConfiguration: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Knowledge Scanner Configuration

    var knowledgeScannerConfig: KnowledgeScannerConfiguration {
        get {
            guard let data = defaults.data(forKey: "AppConfiguration.knowledgeScannerConfig") else {
                return KnowledgeScannerConfiguration()
            }
            do {
                return try JSONDecoder().decode(KnowledgeScannerConfiguration.self, from: data)
            } catch {
                logger.error("Failed to decode KnowledgeScannerConfiguration: \(error.localizedDescription)")
                return KnowledgeScannerConfiguration()
            }
        }
        set {
            do {
                let data = try JSONEncoder().encode(newValue)
                defaults.set(data, forKey: "AppConfiguration.knowledgeScannerConfig")
            } catch {
                logger.error("Failed to encode KnowledgeScannerConfiguration: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Code Intelligence Configuration

    var codeIntelligenceConfig: CodeIntelligenceConfiguration {
        get {
            guard let data = defaults.data(forKey: "AppConfiguration.codeIntelligenceConfig") else {
                return CodeIntelligenceConfiguration()
            }
            do {
                return try JSONDecoder().decode(CodeIntelligenceConfiguration.self, from: data)
            } catch {
                logger.error("Failed to decode CodeIntelligenceConfiguration: \(error.localizedDescription)")
                return CodeIntelligenceConfiguration()
            }
        }
        set {
            do {
                let data = try JSONEncoder().encode(newValue)
                defaults.set(data, forKey: "AppConfiguration.codeIntelligenceConfig")
            } catch {
                logger.error("Failed to encode CodeIntelligenceConfiguration: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - API Validation Configuration

    var apiValidationConfig: APIValidationConfiguration {
        get {
            guard let data = defaults.data(forKey: "AppConfiguration.apiValidationConfig") else {
                return APIValidationConfiguration()
            }
            do {
                return try JSONDecoder().decode(APIValidationConfiguration.self, from: data)
            } catch {
                logger.error("Failed to decode APIValidationConfiguration: \(error.localizedDescription)")
                return APIValidationConfiguration()
            }
        }
        set {
            do {
                let data = try JSONEncoder().encode(newValue)
                defaults.set(data, forKey: "AppConfiguration.apiValidationConfig")
            } catch {
                logger.error("Failed to encode APIValidationConfiguration: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - External APIs Configuration

    var externalAPIsConfig: ExternalAPIsConfiguration {
        get {
            guard let data = defaults.data(forKey: "AppConfiguration.externalAPIsConfig") else {
                return ExternalAPIsConfiguration()
            }
            do {
                return try JSONDecoder().decode(ExternalAPIsConfiguration.self, from: data)
            } catch {
                logger.error("Failed to decode ExternalAPIsConfiguration: \(error.localizedDescription)")
                return ExternalAPIsConfiguration()
            }
        }
        set {
            do {
                let data = try JSONEncoder().encode(newValue)
                defaults.set(data, forKey: "AppConfiguration.externalAPIsConfig")
            } catch {
                logger.error("Failed to encode ExternalAPIsConfiguration: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Meta-AI Features Configuration

    var metaAIConfig: MetaAIConfiguration {
        get {
            guard let data = defaults.data(forKey: "AppConfiguration.metaAIConfig") else {
                return MetaAIConfiguration()
            }
            do {
                return try JSONDecoder().decode(MetaAIConfiguration.self, from: data)
            } catch {
                logger.error("Failed to decode MetaAIConfiguration: \(error.localizedDescription)")
                return MetaAIConfiguration()
            }
        }
        set {
            do {
                let data = try JSONEncoder().encode(newValue)
                defaults.set(data, forKey: "AppConfiguration.metaAIConfig")
            } catch {
                logger.error("Failed to encode MetaAIConfiguration: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Prompt Engineering Configuration

    var promptEngineeringConfig: PromptEngineeringConfiguration {
        get {
            guard let data = defaults.data(forKey: "AppConfiguration.promptEngineeringConfig") else {
                return PromptEngineeringConfiguration()
            }
            do {
                return try JSONDecoder().decode(PromptEngineeringConfiguration.self, from: data)
            } catch {
                logger.error("Failed to decode PromptEngineeringConfiguration: \(error.localizedDescription)")
                return PromptEngineeringConfiguration()
            }
        }
        set {
            do {
                let data = try JSONEncoder().encode(newValue)
                defaults.set(data, forKey: "AppConfiguration.promptEngineeringConfig")
            } catch {
                logger.error("Failed to encode PromptEngineeringConfiguration: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Life Tracking Configuration

    var lifeTrackingConfig: LifeTrackingConfiguration {
        get {
            guard let data = defaults.data(forKey: "AppConfiguration.lifeTrackingConfig") else {
                return LifeTrackingConfiguration()
            }
            do {
                return try JSONDecoder().decode(LifeTrackingConfiguration.self, from: data)
            } catch {
                logger.error("Failed to decode LifeTrackingConfiguration: \(error.localizedDescription)")
                return LifeTrackingConfiguration()
            }
        }
        set {
            do {
                let data = try JSONEncoder().encode(newValue)
                defaults.set(data, forKey: "AppConfiguration.lifeTrackingConfig")
            } catch {
                logger.error("Failed to encode LifeTrackingConfiguration: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - QA Tools Configuration

    var qaToolsConfig: QAToolsConfiguration {
        get {
            guard let data = defaults.data(forKey: "AppConfiguration.qaToolsConfig") else {
                return QAToolsConfiguration()
            }
            do {
                return try JSONDecoder().decode(QAToolsConfiguration.self, from: data)
            } catch {
                logger.error("Failed to decode QAToolsConfiguration: \(error.localizedDescription)")
                return QAToolsConfiguration()
            }
        }
        set {
            do {
                let data = try JSONEncoder().encode(newValue)
                defaults.set(data, forKey: "AppConfiguration.qaToolsConfig")
            } catch {
                logger.error("Failed to encode QAToolsConfiguration: \(error.localizedDescription)")
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

    // periphery:ignore - Reserved: resetProviderConfig() instance method reserved for future feature activation
    func resetVoiceConfig() {
        voiceConfig = VoiceConfiguration()
    }

// periphery:ignore - Reserved: resetVoiceConfig() instance method reserved for future feature activation

    func resetKnowledgeScannerConfig() {
        knowledgeScannerConfig = KnowledgeScannerConfiguration()
    // periphery:ignore - Reserved: resetKnowledgeScannerConfig() instance method reserved for future feature activation
    }

    func resetMetaAIConfig() {
        // periphery:ignore - Reserved: resetMetaAIConfig() instance method reserved for future feature activation
        metaAIConfig = MetaAIConfiguration()
    }

    // periphery:ignore - Reserved: resetQAToolsConfig() instance method reserved for future feature activation
    func resetQAToolsConfig() {
        qaToolsConfig = QAToolsConfiguration()
    }
}
