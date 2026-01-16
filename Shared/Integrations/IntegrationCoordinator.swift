import Foundation
import SwiftData
import SwiftUI

/// Central coordinator for all integration modules
@MainActor
@Observable
public final class IntegrationCoordinator {
    public static let shared = IntegrationCoordinator()

    // MARK: - Module State

    public var isInitialized = false
    public var activeModules: Set<IntegrationModule> = []
    public var moduleStatus: [IntegrationModule: ModuleStatus] = [:]

    // MARK: - Feature Flags

    public var featureFlags = FeatureFlags()

    // MARK: - Module Coordinators

    public var healthSync: HealthDataSyncCoordinator?
    public var nutritionImport: NutritionImportCoordinator?
    public var assessmentExport: AssessmentExportCoordinator?
    public var careerGoals: CareerGoalCoordinator?
    public var incomeAnalytics: IncomeAnalyticsCoordinator?

    #if os(macOS)
    // Display module uses actor-based DisplayProfileManager directly
    // public var displayProfiles: DisplayProfileCoordinator?
    #endif

    private init() {}

    // MARK: - Initialization

    public func initialize(context: ModelContext) async {
        guard !isInitialized else { return }

        // Initialize all enabled modules
        await initializeEnabledModules(context: context)

        isInitialized = true
    }

    private func initializeEnabledModules(context: ModelContext) async {
        // Initialize Health module
        if featureFlags.healthEnabled {
            await initializeHealthModule()
        }

        // Initialize Wellness module
        if featureFlags.wellnessEnabled {
            await initializeWellnessModule()
        }

        // Initialize Cognitive module
        if featureFlags.cognitiveEnabled {
            await initializeCognitiveModule()
        }

        // Initialize Financial module (already exists in Core)
        if featureFlags.financialEnabled {
            await initializeFinancialModule()
        }

        // Initialize Career module
        if featureFlags.careerEnabled {
            await initializeCareerModule()
        }

        // Initialize Assessment module
        if featureFlags.assessmentEnabled {
            await initializeAssessmentModule()
        }

        // Initialize Nutrition module
        if featureFlags.nutritionEnabled {
            await initializeNutritionModule()
        }

        // Initialize Display module (macOS only)
        #if os(macOS)
        if featureFlags.displayEnabled {
            await initializeDisplayModule()
        }
        #endif

        // Initialize Income module
        if featureFlags.incomeEnabled {
            await initializeIncomeModule()
        }
    }

    // MARK: - Module Initialization

    private func initializeHealthModule() async {
        moduleStatus[.health] = .initializing

        healthSync = HealthDataSyncCoordinator()

        // Check HealthKit availability
        #if canImport(HealthKit)
        moduleStatus[.health] = .active
        activeModules.insert(.health)
        #else
        moduleStatus[.health] = .unavailable
        #endif
    }

    private func initializeWellnessModule() async {
        moduleStatus[.wellness] = .initializing

        // Wellness module uses no external dependencies
        moduleStatus[.wellness] = .active
        activeModules.insert(.wellness)
    }

    private func initializeCognitiveModule() async {
        moduleStatus[.cognitive] = .initializing

        // Cognitive module ready
        moduleStatus[.cognitive] = .active
        activeModules.insert(.cognitive)
    }

    private func initializeFinancialModule() async {
        moduleStatus[.financial] = .initializing

        // Financial module already exists in Core
        moduleStatus[.financial] = .active
        activeModules.insert(.financial)
    }

    private func initializeCareerModule() async {
        moduleStatus[.career] = .initializing

        careerGoals = CareerGoalCoordinator()
        await careerGoals?.loadGoals()

        moduleStatus[.career] = .active
        activeModules.insert(.career)
    }

    private func initializeAssessmentModule() async {
        moduleStatus[.assessment] = .initializing

        assessmentExport = AssessmentExportCoordinator()

        moduleStatus[.assessment] = .active
        activeModules.insert(.assessment)
    }

    private func initializeNutritionModule() async {
        moduleStatus[.nutrition] = .initializing

        nutritionImport = NutritionImportCoordinator()

        moduleStatus[.nutrition] = .active
        activeModules.insert(.nutrition)
    }

    #if os(macOS)
    private func initializeDisplayModule() async {
        moduleStatus[.display] = .initializing

        // DisplayProfileCoordinator not yet implemented
        // displayProfiles = DisplayProfileCoordinator()
        // await displayProfiles?.loadProfiles()

        moduleStatus[.display] = .active
        activeModules.insert(.display)
    }
    #endif

    private func initializeIncomeModule() async {
        moduleStatus[.income] = .initializing

        incomeAnalytics = IncomeAnalyticsCoordinator()

        moduleStatus[.income] = .active
        activeModules.insert(.income)
    }

    // MARK: - Module Control

    public func enableModule(_ module: IntegrationModule) async {
        guard !activeModules.contains(module) else { return }

        switch module {
        case .health:
            featureFlags.healthEnabled = true
            await initializeHealthModule()
        case .wellness:
            featureFlags.wellnessEnabled = true
            await initializeWellnessModule()
        case .cognitive:
            featureFlags.cognitiveEnabled = true
            await initializeCognitiveModule()
        case .financial:
            featureFlags.financialEnabled = true
            await initializeFinancialModule()
        case .career:
            featureFlags.careerEnabled = true
            await initializeCareerModule()
        case .assessment:
            featureFlags.assessmentEnabled = true
            await initializeAssessmentModule()
        case .nutrition:
            featureFlags.nutritionEnabled = true
            await initializeNutritionModule()
        case .display:
            #if os(macOS)
            featureFlags.displayEnabled = true
            await initializeDisplayModule()
            #endif
        case .income:
            featureFlags.incomeEnabled = true
            await initializeIncomeModule()
        }
    }

    public func disableModule(_ module: IntegrationModule) async {
        guard activeModules.contains(module) else { return }

        activeModules.remove(module)
        moduleStatus[module] = .disabled

        switch module {
        case .health:
            featureFlags.healthEnabled = false
            healthSync = nil
        case .wellness:
            featureFlags.wellnessEnabled = false
        case .cognitive:
            featureFlags.cognitiveEnabled = false
        case .financial:
            featureFlags.financialEnabled = false
        case .career:
            featureFlags.careerEnabled = false
            careerGoals = nil
        case .assessment:
            featureFlags.assessmentEnabled = false
            assessmentExport = nil
        case .nutrition:
            featureFlags.nutritionEnabled = false
            nutritionImport = nil
        case .display:
            #if os(macOS)
            featureFlags.displayEnabled = false
            // displayProfiles = nil
            #endif
        case .income:
            featureFlags.incomeEnabled = false
            incomeAnalytics = nil
        }
    }

    // MARK: - Status Queries

    public func isModuleActive(_ module: IntegrationModule) -> Bool {
        activeModules.contains(module)
    }

    public func getModuleStatus(_ module: IntegrationModule) -> ModuleStatus {
        moduleStatus[module] ?? .disabled
    }

    public func getActiveModuleCount() -> Int {
        activeModules.count
    }

    public func getAllModules() -> [IntegrationModule] {
        IntegrationModule.allCases
    }

    // MARK: - Health Check

    public func performHealthCheck() async -> HealthCheckReport {
        var reports: [IntegrationModule: String] = [:]

        for module in activeModules {
            switch module {
            case .health:
                reports[.health] = healthSync != nil ? "Operational" : "Coordinator missing"
            case .wellness:
                reports[.wellness] = "Operational"
            case .cognitive:
                reports[.cognitive] = "Operational"
            case .financial:
                reports[.financial] = "Operational"
            case .career:
                reports[.career] = careerGoals != nil ? "Operational" : "Coordinator missing"
            case .assessment:
                reports[.assessment] = assessmentExport != nil ? "Operational" : "Coordinator missing"
            case .nutrition:
                reports[.nutrition] = nutritionImport != nil ? "Operational" : "Coordinator missing"
            case .display:
                #if os(macOS)
                reports[.display] = "Not implemented"
                #else
                reports[.display] = "Platform unsupported"
                #endif
            case .income:
                reports[.income] = incomeAnalytics != nil ? "Operational" : "Coordinator missing"
            }
        }

        return HealthCheckReport(
            timestamp: Date(),
            activeModules: activeModules.count,
            totalModules: IntegrationModule.allCases.count,
            moduleReports: reports
        )
    }
}

// MARK: - Supporting Types

public enum IntegrationModule: String, CaseIterable, Sendable, Identifiable {
    case health = "Health"
    case wellness = "Wellness"
    case cognitive = "Cognitive"
    case financial = "Financial"
    case career = "Career"
    case assessment = "Assessment"
    case nutrition = "Nutrition"
    case display = "Display"
    case income = "Income"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .health: return "heart.fill"
        case .wellness: return "leaf.fill"
        case .cognitive: return "brain.head.profile"
        case .financial: return "dollarsign.circle.fill"
        case .career: return "briefcase.fill"
        case .assessment: return "chart.bar.doc.horizontal.fill"
        case .nutrition: return "fork.knife"
        case .display: return "display"
        case .income: return "banknote.fill"
        }
    }

    public var color: Color {
        switch self {
        case .health: return .red
        case .wellness: return .green
        case .cognitive: return .purple
        case .financial: return .blue
        case .career: return .orange
        case .assessment: return .indigo
        case .nutrition: return .yellow
        case .display: return .cyan
        case .income: return .mint
        }
    }
}

public enum ModuleStatus: Sendable {
    case disabled
    case initializing
    case active
    case error(String)
    case unavailable

    public var displayName: String {
        switch self {
        case .disabled: return "Disabled"
        case .initializing: return "Initializing..."
        case .active: return "Active"
        case .error(let message): return "Error: \(message)"
        case .unavailable: return "Unavailable"
        }
    }

    public var color: Color {
        switch self {
        case .disabled: return .gray
        case .initializing: return .yellow
        case .active: return .green
        case .error: return .red
        case .unavailable: return .orange
        }
    }
}

// FeatureFlags defined in Core/Configuration/FeatureFlags.swift

public struct HealthCheckReport: Sendable {
    public let timestamp: Date
    public let activeModules: Int
    public let totalModules: Int
    public let moduleReports: [IntegrationModule: String]

    public var overallHealth: String {
        let ratio = Double(activeModules) / Double(totalModules)
        if ratio >= 0.8 { return "Excellent" }
        if ratio >= 0.5 { return "Good" }
        if ratio >= 0.3 { return "Fair" }
        return "Poor"
    }
}
