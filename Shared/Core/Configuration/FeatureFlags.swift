import Foundation

/// Feature flags for enabling/disabling integration modules
@MainActor
@Observable
public final class FeatureFlags {

    // MARK: - Integration Modules

    public var healthEnabled: Bool
    public var wellnessEnabled: Bool
    public var cognitiveEnabled: Bool
    public var financialEnabled: Bool
    public var careerEnabled: Bool
    public var assessmentEnabled: Bool
    public var nutritionEnabled: Bool
    public var displayEnabled: Bool // macOS only
    public var incomeEnabled: Bool
    public var automationEnabled: Bool // ChatGPT Agent features

    // MARK: - Advanced Features

    public var multiAgentEnabled: Bool
    public var agentsMDParserEnabled: Bool
    public var mcpCompatibilityEnabled: Bool
    public var voiceActivationEnabled: Bool

    // MARK: - Experimental Features

    public var browserAutomationEnabled: Bool
    public var taskSchedulingEnabled: Bool
    public var macOSGUIAutomationEnabled: Bool

    // MARK: - Privacy & Security

    public var analyticsEnabled: Bool
    public var crashReportingEnabled: Bool
    public var automationPermissionsRequired: Bool

    // MARK: - Initialization

    public init(
        // Integration Modules
        healthEnabled: Bool = true,
        wellnessEnabled: Bool = true,
        cognitiveEnabled: Bool = true,
        financialEnabled: Bool = true,
        careerEnabled: Bool = false,
        assessmentEnabled: Bool = false,
        nutritionEnabled: Bool = false,
        displayEnabled: Bool = true,
        incomeEnabled: Bool = false,
        automationEnabled: Bool = false,

        // Advanced Features
        multiAgentEnabled: Bool = false,
        agentsMDParserEnabled: Bool = false,
        mcpCompatibilityEnabled: Bool = false,
        voiceActivationEnabled: Bool = false,

        // Experimental Features
        browserAutomationEnabled: Bool = false,
        taskSchedulingEnabled: Bool = false,
        macOSGUIAutomationEnabled: Bool = false,

        // Privacy & Security
        analyticsEnabled: Bool = true,
        crashReportingEnabled: Bool = true,
        automationPermissionsRequired: Bool = true
    ) {
        self.healthEnabled = healthEnabled
        self.wellnessEnabled = wellnessEnabled
        self.cognitiveEnabled = cognitiveEnabled
        self.financialEnabled = financialEnabled
        self.careerEnabled = careerEnabled
        self.assessmentEnabled = assessmentEnabled
        self.nutritionEnabled = nutritionEnabled
        self.displayEnabled = displayEnabled
        self.incomeEnabled = incomeEnabled
        self.automationEnabled = automationEnabled

        self.multiAgentEnabled = multiAgentEnabled
        self.agentsMDParserEnabled = agentsMDParserEnabled
        self.mcpCompatibilityEnabled = mcpCompatibilityEnabled
        self.voiceActivationEnabled = voiceActivationEnabled

        self.browserAutomationEnabled = browserAutomationEnabled
        self.taskSchedulingEnabled = taskSchedulingEnabled
        self.macOSGUIAutomationEnabled = macOSGUIAutomationEnabled

        self.analyticsEnabled = analyticsEnabled
        self.crashReportingEnabled = crashReportingEnabled
        self.automationPermissionsRequired = automationPermissionsRequired
    }

    // MARK: - Presets

    /// Default production configuration
    @MainActor
    public static let `default` = FeatureFlags()

    /// All features enabled (for testing/development)
    @MainActor
    public static let allEnabled = FeatureFlags(
        healthEnabled: true,
        wellnessEnabled: true,
        cognitiveEnabled: true,
        financialEnabled: true,
        careerEnabled: true,
        assessmentEnabled: true,
        nutritionEnabled: true,
        displayEnabled: true,
        incomeEnabled: true,
        automationEnabled: true,
        multiAgentEnabled: true,
        agentsMDParserEnabled: true,
        mcpCompatibilityEnabled: true,
        voiceActivationEnabled: true,
        browserAutomationEnabled: true,
        taskSchedulingEnabled: true,
        macOSGUIAutomationEnabled: true,
        analyticsEnabled: false, // Disable for privacy in testing
        crashReportingEnabled: true,
        automationPermissionsRequired: true
    )

    /// Minimal configuration (core features only)
    @MainActor
    public static let minimal = FeatureFlags(
        healthEnabled: false,
        wellnessEnabled: false,
        cognitiveEnabled: false,
        financialEnabled: false,
        careerEnabled: false,
        assessmentEnabled: false,
        nutritionEnabled: false,
        displayEnabled: false,
        incomeEnabled: false,
        automationEnabled: false,
        multiAgentEnabled: false,
        agentsMDParserEnabled: false,
        mcpCompatibilityEnabled: false,
        voiceActivationEnabled: false,
        browserAutomationEnabled: false,
        taskSchedulingEnabled: false,
        macOSGUIAutomationEnabled: false,
        analyticsEnabled: false,
        crashReportingEnabled: false,
        automationPermissionsRequired: true
    )

    /// ChatGPT Agent Parity configuration
    @MainActor
    public static let chatGPTAgentParity = FeatureFlags(
        healthEnabled: true,
        wellnessEnabled: true,
        cognitiveEnabled: true,
        financialEnabled: false,
        careerEnabled: false,
        assessmentEnabled: false,
        nutritionEnabled: false,
        displayEnabled: true,
        incomeEnabled: false,
        automationEnabled: true,
        multiAgentEnabled: false,
        agentsMDParserEnabled: true,
        mcpCompatibilityEnabled: true,
        voiceActivationEnabled: false,
        browserAutomationEnabled: true,
        taskSchedulingEnabled: true,
        macOSGUIAutomationEnabled: true,
        analyticsEnabled: true,
        crashReportingEnabled: true,
        automationPermissionsRequired: true
    )


    // MARK: - Helper Methods

    /// Get count of enabled integration modules
    public var enabledModulesCount: Int {
        var count = 0
        if healthEnabled { count += 1 }
        if wellnessEnabled { count += 1 }
        if cognitiveEnabled { count += 1 }
        if financialEnabled { count += 1 }
        if careerEnabled { count += 1 }
        if assessmentEnabled { count += 1 }
        if nutritionEnabled { count += 1 }
        if displayEnabled { count += 1 }
        if incomeEnabled { count += 1 }
        if automationEnabled { count += 1 }
        return count
    }

    /// Check if any integration module is enabled
    public var hasEnabledModules: Bool {
        return enabledModulesCount > 0
    }

    /// Get list of enabled module names
    public var enabledModuleNames: [String] {
        var names: [String] = []
        if healthEnabled { names.append("Health") }
        if wellnessEnabled { names.append("Wellness") }
        if cognitiveEnabled { names.append("Cognitive") }
        if financialEnabled { names.append("Financial") }
        if careerEnabled { names.append("Career") }
        if assessmentEnabled { names.append("Assessment") }
        if nutritionEnabled { names.append("Nutrition") }
        if displayEnabled { names.append("Display") }
        if incomeEnabled { names.append("Income") }
        if automationEnabled { names.append("Automation") }
        return names
    }
}
