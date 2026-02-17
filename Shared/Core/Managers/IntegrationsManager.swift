import Foundation
@preconcurrency import SwiftData

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
    public var nutritionImportCoordinator: NutritionImportCoordinator?
    public var assessmentExportCoordinator: AssessmentExportCoordinator?
    public var incomeAnalyticsCoordinator: IncomeAnalyticsCoordinator?
    #if os(macOS)
        public var automationEngine: AutomationEngine?
        public var browserAutomationService: BrowserAutomationService?
        public var displayViewModel: DisplayViewModel?
    #endif
    public var taskScheduler: TaskScheduler?
    public var permissionManager: PermissionManager?

    // MARK: - State

    public var isInitialized = false
    public var enabledModules: Set<IntegrationModuleType> = []
    public var initializationError: String?

    // MARK: - Initialization

    private init() {}

    /// Initialize all enabled integration modules
    public func initializeModules(context _: ModelContext, featureFlags: FeatureFlags) async {
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

        // Financial Module
        if featureFlags.financialEnabled {
            enabledModules.insert(.financial)
        }

        // Assessment Module
        if featureFlags.assessmentEnabled {
            assessmentExportCoordinator = AssessmentExportCoordinator()
            enabledModules.insert(.assessment)
        }

        // Nutrition Module
        if featureFlags.nutritionEnabled {
            nutritionImportCoordinator = NutritionImportCoordinator()
            enabledModules.insert(.nutrition)
        }

        // Display Module (macOS only)
        if featureFlags.displayEnabled {
            #if os(macOS)
                displayViewModel = DisplayViewModel()
                enabledModules.insert(.display)
            #endif
        }

        // Income Module
        if featureFlags.incomeEnabled {
            incomeAnalyticsCoordinator = IncomeAnalyticsCoordinator()
            enabledModules.insert(.income)
        }

        // Automation (ChatGPT Agent Parity)
        if featureFlags.automationEnabled {
            #if os(macOS)
                automationEngine = AutomationEngine()
                browserAutomationService = BrowserAutomationService()
            #endif
            taskScheduler = TaskScheduler.shared
            permissionManager = PermissionManager()
            enabledModules.insert(.automation)
        }

        isInitialized = true
    }

    /// Enable a specific module
    public func enableModule(_ module: IntegrationModuleType, context _: ModelContext) async {
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
            #if os(macOS)
                automationEngine = AutomationEngine()
                browserAutomationService = BrowserAutomationService()
            #endif
            taskScheduler = TaskScheduler.shared
            permissionManager = PermissionManager()
            enabledModules.insert(.automation)

        case .financial:
            enabledModules.insert(.financial)

        case .assessment:
            assessmentExportCoordinator = AssessmentExportCoordinator()
            enabledModules.insert(.assessment)

        case .nutrition:
            nutritionImportCoordinator = NutritionImportCoordinator()
            enabledModules.insert(.nutrition)

        case .display:
            #if os(macOS)
                displayViewModel = DisplayViewModel()
                enabledModules.insert(.display)
            #endif

        case .income:
            incomeAnalyticsCoordinator = IncomeAnalyticsCoordinator()
            enabledModules.insert(.income)
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
            #if os(macOS)
                automationEngine = nil
                browserAutomationService = nil
            #endif
            taskScheduler = nil
            permissionManager = nil
            enabledModules.remove(.automation)

        case .financial:
            enabledModules.remove(.financial)

        case .assessment:
            assessmentExportCoordinator = nil
            enabledModules.remove(.assessment)

        case .nutrition:
            nutritionImportCoordinator = nil
            enabledModules.remove(.nutrition)

        case .display:
            #if os(macOS)
                displayViewModel = nil
            #endif
            enabledModules.remove(.display)

        case .income:
            incomeAnalyticsCoordinator = nil
            enabledModules.remove(.income)
        }
    }

    /// Check if a module is enabled
    public func isModuleEnabled(_ module: IntegrationModuleType) -> Bool {
        enabledModules.contains(module)
    }

    /// Get enabled modules count
    public var enabledModulesCount: Int {
        enabledModules.count
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
        case .health: "Health"
        case .wellness: "Wellness"
        case .cognitive: "Cognitive Tools"
        case .financial: "Financial"
        case .career: "Career Development"
        case .assessment: "Assessments"
        case .nutrition: "Nutrition"
        case .display: "Display Control"
        case .income: "Income Tracking"
        case .automation: "Automation (ChatGPT Agent)"
        }
    }

    public var icon: String {
        switch self {
        case .health: "heart.fill"
        case .wellness: "leaf.fill"
        case .cognitive: "brain.head.profile"
        case .financial: "dollarsign.circle.fill"
        case .career: "target"
        case .assessment: "chart.bar.fill"
        case .nutrition: "fork.knife"
        case .display: "display"
        case .income: "banknote.fill"
        case .automation: "gearshape.2.fill"
        }
    }

    public var description: String {
        switch self {
        case .health:
            "HealthKit integration for sleep, heart rate, activity tracking"
        case .wellness:
            "Circadian rhythm, focus modes, ambient audio"
        case .cognitive:
            "Task breakdown, Pomodoro timer, Focus Forest gamification"
        case .financial:
            "Zero-based budgeting, transaction categorization, subscription monitoring"
        case .career:
            "SMART goals, skill tracking, daily reflections, growth recommendations"
        case .assessment:
            "EQ assessments, HSP scale, cognitive benchmarking"
        case .nutrition:
            "84-nutrient tracking, meal planning, barcode scanning"
        case .display:
            "DDC/CI hardware control for brightness and contrast (macOS)"
        case .income:
            "Passive income tracking, side hustle management"
        case .automation:
            "ChatGPT Agent equivalent: GUI automation, browser control, task scheduling"
        }
    }
}
