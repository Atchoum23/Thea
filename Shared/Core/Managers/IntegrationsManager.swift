import Foundation
import SwiftData

/// Central manager for all integration modules
@MainActor
@Observable
public final class IntegrationsManager {

    // MARK: - Singleton

    public static let shared = IntegrationsManager()

    // MARK: - Module Instances

    public var healthKitService: HealthKitService?
    public var circadianService: CircadianService?
    public var focusModeService: FocusModeService?
    public var taskBreakdownService: TaskBreakdownService?
    public var visualTimerService: VisualTimerService?
    public var focusForestService: FocusForestService?
    public var careerService: CareerService?
    public var automationEngine: AutomationEngine?
    public var browserAutomationService: BrowserAutomationService?
    public var taskScheduler: TaskScheduler?
    public var permissionManager: PermissionManager?

    // MARK: - State

    public var isInitialized = false
    public var enabledModules: Set<IntegrationModuleType> = []
    public var initializationError: String?

    // MARK: - Initialization

    private init() {}

    /// Initialize all enabled integration modules
    public func initializeModules(context: ModelContext, featureFlags: FeatureFlags) async {
        guard !isInitialized else { return }

        // Health Module
        if featureFlags.healthEnabled {
            #if canImport(HealthKit)
            healthKitService = HealthKitService()
            enabledModules.insert(.health)
            #endif
        }

        // Wellness Module
        if featureFlags.wellnessEnabled {
            circadianService = CircadianService()
            focusModeService = FocusModeService()
            enabledModules.insert(.wellness)
        }

        // Cognitive Module
        if featureFlags.cognitiveEnabled {
            taskBreakdownService = TaskBreakdownService()
            visualTimerService = VisualTimerService()
            focusForestService = FocusForestService()
            enabledModules.insert(.cognitive)
        }

        // Career Module
        if featureFlags.careerEnabled {
            careerService = CareerService()
            enabledModules.insert(.career)
        }

        // Automation (ChatGPT Agent Parity)
        if featureFlags.automationEnabled {
            automationEngine = AutomationEngine()
            browserAutomationService = BrowserAutomationService()
            taskScheduler = TaskScheduler()
            permissionManager = PermissionManager()
            enabledModules.insert(.automation)
        }

        isInitialized = true
    }

    /// Enable a specific module
    public func enableModule(_ module: IntegrationModuleType, context: ModelContext) async {
        guard !enabledModules.contains(module) else { return }

        switch module {
        case .health:
            #if canImport(HealthKit)
            healthKitService = HealthKitService()
            enabledModules.insert(.health)
            #endif

        case .wellness:
            circadianService = CircadianService()
            focusModeService = FocusModeService()
            enabledModules.insert(.wellness)

        case .cognitive:
            taskBreakdownService = TaskBreakdownService()
            visualTimerService = VisualTimerService()
            focusForestService = FocusForestService()
            enabledModules.insert(.cognitive)

        case .career:
            careerService = CareerService()
            enabledModules.insert(.career)

        case .automation:
            automationEngine = AutomationEngine()
            browserAutomationService = BrowserAutomationService()
            taskScheduler = TaskScheduler()
            permissionManager = PermissionManager()
            enabledModules.insert(.automation)

        case .financial, .assessment, .nutrition, .display, .income:
            // Placeholder for future modules
            break
        }
    }

    /// Disable a specific module
    public func disableModule(_ module: IntegrationModuleType) async {
        guard enabledModules.contains(module) else { return }

        switch module {
        case .health:
            healthKitService = nil
            enabledModules.remove(.health)

        case .wellness:
            circadianService = nil
            focusModeService = nil
            enabledModules.remove(.wellness)

        case .cognitive:
            taskBreakdownService = nil
            visualTimerService = nil
            focusForestService = nil
            enabledModules.remove(.cognitive)

        case .career:
            careerService = nil
            enabledModules.remove(.career)

        case .automation:
            automationEngine = nil
            browserAutomationService = nil
            taskScheduler = nil
            permissionManager = nil
            enabledModules.remove(.automation)

        case .financial, .assessment, .nutrition, .display, .income:
            // Placeholder for future modules
            break
        }
    }

    /// Check if a module is enabled
    public func isModuleEnabled(_ module: IntegrationModuleType) -> Bool {
        return enabledModules.contains(module)
    }

    /// Get enabled modules count
    public var enabledModulesCount: Int {
        return enabledModules.count
    }
}

// MARK: - Integration Module Types

/// Available integration module types
public enum IntegrationModuleType: String, Sendable, CaseIterable {
    case health
    case wellness
    case cognitive
    case financial
    case career
    case assessment
    case nutrition
    case display
    case income
    case automation

    public var displayName: String {
        switch self {
        case .health: return "Health"
        case .wellness: return "Wellness"
        case .cognitive: return "Cognitive Tools"
        case .financial: return "Financial"
        case .career: return "Career Development"
        case .assessment: return "Assessments"
        case .nutrition: return "Nutrition"
        case .display: return "Display Control"
        case .income: return "Income Tracking"
        case .automation: return "Automation (ChatGPT Agent)"
        }
    }

    public var icon: String {
        switch self {
        case .health: return "heart.fill"
        case .wellness: return "leaf.fill"
        case .cognitive: return "brain.head.profile"
        case .financial: return "dollarsign.circle.fill"
        case .career: return "target"
        case .assessment: return "chart.bar.fill"
        case .nutrition: return "fork.knife"
        case .display: return "display"
        case .income: return "banknote.fill"
        case .automation: return "gearshape.2.fill"
        }
    }

    public var description: String {
        switch self {
        case .health:
            return "HealthKit integration for sleep, heart rate, activity tracking"
        case .wellness:
            return "Circadian rhythm, focus modes, ambient audio"
        case .cognitive:
            return "Task breakdown, Pomodoro timer, Focus Forest gamification"
        case .financial:
            return "Zero-based budgeting, transaction categorization, subscription monitoring"
        case .career:
            return "SMART goals, skill tracking, daily reflections, growth recommendations"
        case .assessment:
            return "EQ assessments, HSP scale, cognitive benchmarking"
        case .nutrition:
            return "84-nutrient tracking, meal planning, barcode scanning"
        case .display:
            return "DDC/CI hardware control for brightness and contrast (macOS)"
        case .income:
            return "Passive income tracking, side hustle management"
        case .automation:
            return "ChatGPT Agent equivalent: GUI automation, browser control, task scheduling"
        }
    }
}
