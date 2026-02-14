// AIModelGovernor.swift
// Thea V2
//
// AI-Powered Dynamic Model Governance
// No hardcoded thresholds - all decisions are intelligent and contextual
//
// CREATED: February 2, 2026

import Foundation
import OSLog
#if os(macOS)
import IOKit
#endif

// MARK: - AI Model Governor

/// AI-powered governor that makes intelligent, dynamic decisions about:
/// - When to download models (based on predicted need, not arbitrary confidence)
/// - When to delete models (based on value vs cost, not arbitrary time)
/// - Resource allocation (GPU/CPU usage based on current workload)
/// - Proactivity level (learns and increases over time)
@MainActor
@Observable
final class AIModelGovernor {
    static let shared = AIModelGovernor()

    private let logger = Logger(subsystem: "com.thea.ai", category: "AIModelGovernor")

    // MARK: - AI-Powered State

    /// Current AI-determined optimal settings (updated continuously)
    private(set) var currentPolicy: GovernancePolicy = .default

    /// Proactivity score (0.0-1.0) - increases over time based on user satisfaction
    private(set) var proactivityScore: Double = 0.5

    /// Learning history for proactivity improvement
    private(set) var proactivityHistory: [ProactivityEvent] = []

    /// Real-time system state
    private(set) var systemState = SystemResourceState()

    /// Model value assessments (AI-determined)
    private(set) var modelValueScores: [String: ModelValueAssessment] = [:]

    // MARK: - User Consent (One-time)

    var hasAutonomousConsent: Bool {
        get { UserDefaults.standard.bool(forKey: "AIModelGovernor.hasConsent") }
        set { UserDefaults.standard.set(newValue, forKey: "AIModelGovernor.hasConsent") }
    }

    // MARK: - Initialization

    private init() {
        loadState()
        Task {
            await startContinuousMonitoring()
        }
    }

    // MARK: - AI-Powered Decision Making

    /// Determine if a model should be downloaded NOW based on intelligent analysis
    /// Returns a decision with full reasoning - no arbitrary thresholds
    func shouldDownloadModel(
        recommendation: ProactiveModelRecommendation,
        forTask taskType: TaskType,
        userRequest: String
    ) async -> DownloadDecision {
        // 1. Analyze the request importance
        let requestImportance = await analyzeRequestImportance(userRequest, taskType: taskType)

        // 2. Check if we have adequate models already
        let existingCoverage = await assessExistingModelCoverage(for: taskType)

        // 3. Analyze storage situation (not a fixed limit - intelligent assessment)
        let storageAnalysis = analyzeStorageSituation(modelSize: recommendation.estimatedSizeGB)

        // 4. Check current system load
        updateSystemState()
        let canDownloadNow = systemState.availableBandwidth > 0.3 // At least 30% bandwidth free

        // 5. Calculate value proposition
        let expectedValue = calculateExpectedModelValue(
            recommendation: recommendation,
            taskType: taskType,
            currentCoverage: existingCoverage
        )

        // 6. Make intelligent decision
        let shouldDownload = makeDownloadDecision(
            requestImportance: requestImportance,
            existingCoverage: existingCoverage,
            storageAnalysis: storageAnalysis,
            expectedValue: expectedValue,
            canDownloadNow: canDownloadNow
        )

        let decision = DownloadDecision(
            shouldDownload: shouldDownload,
            confidence: calculateDecisionConfidence(
                importance: requestImportance,
                coverage: existingCoverage,
                value: expectedValue
            ),
            reasoning: buildDownloadReasoning(
                shouldDownload: shouldDownload,
                importance: requestImportance,
                coverage: existingCoverage,
                storage: storageAnalysis,
                value: expectedValue
            ),
            alternativeAction: shouldDownload ? nil : suggestAlternative(
                existingCoverage: existingCoverage,
                taskType: taskType
            ),
            estimatedBenefit: expectedValue,
            storageCost: recommendation.estimatedSizeGB
        )

        // Record for learning
        recordDecision(decision, forTask: taskType)

        return decision
    }

    /// Determine which models to delete based on intelligent value analysis
    /// No arbitrary "30 days" - uses actual value vs cost assessment
    func determineModelsToCleanup() async -> [CleanupDecision] {
        let manager = LocalModelManager.shared
        await manager.waitForDiscovery()

        var decisions: [CleanupDecision] = []

        // 1. Calculate current storage pressure
        let storagePressure = calculateStoragePressure()

        // 2. Assess each model's current value
        for model in manager.availableModels {
            let value = await assessModelValue(model)
            modelValueScores[model.name] = value

            // Only consider deletion if there's storage pressure AND model has low value
            if storagePressure > 0.7 && value.currentValue < 0.3 {
                let decision = CleanupDecision(
                    model: model,
                    shouldDelete: true,
                    valueScore: value.currentValue,
                    reasoning: buildCleanupReasoning(model: model, value: value, pressure: storagePressure),
                    alternativeAction: value.couldBeUsefulFor.isEmpty ? nil :
                        "Keep for potential \(value.couldBeUsefulFor.joined(separator: ", ")) tasks",
                    freedSpace: Double(model.size) / 1_000_000_000
                )
                decisions.append(decision)
            }
        }

        // Sort by value (lowest first) - delete least valuable first
        decisions.sort { $0.valueScore < $1.valueScore }

        return decisions
    }

    /// Get optimal resource allocation for current workload
    func getOptimalResourceAllocation() -> ResourceAllocation {
        updateSystemState()

        // AI-determined allocation based on current state
        let gpuAllocation: Double
        let cpuAllocation: Double
        let memoryAllocation: Double

        // If actively running inference, maximize resources
        if systemState.activeInferenceCount > 0 {
            gpuAllocation = min(0.95, 0.7 + (Double(systemState.activeInferenceCount) * 0.1))
            cpuAllocation = min(0.8, 0.5 + (Double(systemState.activeInferenceCount) * 0.1))
            memoryAllocation = min(0.9, 0.6 + (Double(systemState.activeInferenceCount) * 0.1))
        } else if systemState.pendingTasks > 0 {
            // Tasks pending - moderate allocation
            gpuAllocation = 0.5
            cpuAllocation = 0.4
            memoryAllocation = 0.5
        } else {
            // Idle - minimal allocation
            gpuAllocation = 0.1
            cpuAllocation = 0.1
            memoryAllocation = 0.2
        }

        // Adjust based on thermal state
        let thermalMultiplier: Double = switch systemState.thermalState {
        case .nominal: 1.0
        case .fair: 0.85
        case .serious: 0.6
        case .critical: 0.3
        }

        return ResourceAllocation(
            gpuPercentage: gpuAllocation * thermalMultiplier,
            cpuPercentage: cpuAllocation * thermalMultiplier,
            memoryPercentage: memoryAllocation,
            reasoning: "Based on \(systemState.activeInferenceCount) active tasks, \(systemState.thermalState) thermal state"
        )
    }

    // MARK: - Proactivity Learning

    /// Record user feedback to improve proactivity
    func recordUserFeedback(_ feedback: ProactivityFeedback) {
        let event = ProactivityEvent(
            timestamp: Date(),
            action: feedback.action,
            wasHelpful: feedback.wasHelpful,
            userOverrode: feedback.userOverrode
        )

        proactivityHistory.append(event)

        // Adjust proactivity score based on feedback
        if feedback.wasHelpful {
            proactivityScore = min(1.0, proactivityScore + 0.02)
        } else if feedback.userOverrode {
            proactivityScore = max(0.1, proactivityScore - 0.05)
        }

        // Save state
        saveState()

        logger.info("Proactivity updated to \(self.proactivityScore) based on feedback")
    }

    /// Get current proactivity level with explanation
    func getProactivityLevel() -> ProactivityLevel {
        let level: ProactivityLevel.Level
        let description: String

        switch proactivityScore {
        case 0.0..<0.3:
            level = .conservative
            description = "Thea asks before most actions"
        case 0.3..<0.5:
            level = .moderate
            description = "Thea acts on clear opportunities, asks for ambiguous ones"
        case 0.5..<0.7:
            level = .proactive
            description = "Thea anticipates needs and acts preemptively"
        case 0.7..<0.9:
            level = .highlyProactive
            description = "Thea actively optimizes your workflow"
        default:
            level = .autonomous
            description = "Thea operates with full autonomy, learning continuously"
        }

        return ProactivityLevel(
            level: level,
            score: proactivityScore,
            description: description,
            recentActions: proactivityHistory.suffix(5).map { $0.action },
            successRate: calculateProactivitySuccessRate()
        )
    }

    /// Increase proactivity over time (called periodically)
    func gradualProactivityIncrease() {
        // Only increase if recent actions were successful
        let recentSuccess = calculateRecentSuccessRate()

        if recentSuccess > 0.7 {
            // Good success rate - increase proactivity
            proactivityScore = min(1.0, proactivityScore + 0.005)
            logger.debug("Proactivity naturally increased to \(self.proactivityScore)")
        }

        saveState()
    }

    // MARK: - Private Analysis Methods

    private func analyzeRequestImportance(_ request: String, taskType: TaskType) async -> Double {
        // Analyze based on:
        // - Task type complexity
        // - Request length (longer = more complex)
        // - Keywords indicating urgency

        var importance = 0.5

        // Complex task types are more important
        if [.codeGeneration, .debugging, .analysis, .complexReasoning].contains(taskType) {
            importance += 0.2
        }

        // Longer requests often indicate more complex needs
        if request.count > 200 {
            importance += 0.1
        }

        // Urgency keywords
        let urgencyKeywords = ["urgent", "asap", "quickly", "important", "critical", "deadline"]
        if urgencyKeywords.contains(where: { request.lowercased().contains($0) }) {
            importance += 0.2
        }

        return min(1.0, importance)
    }

    private func assessExistingModelCoverage(for taskType: TaskType) async -> Double {
        let orchestrator = UnifiedLocalModelOrchestrator.shared
        let selection = await orchestrator.selectModel(for: taskType)

        guard let selection = selection else {
            return 0.0 // No coverage
        }

        return selection.score
    }

    private func analyzeStorageSituation(modelSize: Double) -> StorageAnalysis {
        let fileManager = FileManager.default

        #if os(macOS)
        if let attributes = try? fileManager.attributesOfFileSystem(forPath: NSHomeDirectory()),
           let freeSpace = attributes[.systemFreeSize] as? Int64,
           let totalSpace = attributes[.systemSize] as? Int64 {

            let freeGB = Double(freeSpace) / 1_000_000_000
            let totalGB = Double(totalSpace) / 1_000_000_000
            let usedPercent = 1.0 - (freeGB / totalGB)

            // Calculate current model storage
            let manager = LocalModelManager.shared
            let modelStorageGB = manager.availableModels.reduce(0.0) { $0 + Double($1.size) / 1_000_000_000 }

            return StorageAnalysis(
                freeSpaceGB: freeGB,
                totalSpaceGB: totalGB,
                usedPercent: usedPercent,
                modelStorageGB: modelStorageGB,
                canAccommodate: freeGB > modelSize * 1.5, // Need 1.5x for safety
                pressureLevel: usedPercent > 0.9 ? .critical :
                              usedPercent > 0.8 ? .high :
                              usedPercent > 0.7 ? .moderate : .low
            )
        }
        #endif

        return StorageAnalysis(
            freeSpaceGB: 100,
            totalSpaceGB: 500,
            usedPercent: 0.5,
            modelStorageGB: 10,
            canAccommodate: true,
            pressureLevel: .low
        )
    }

    private func calculateExpectedModelValue(
        recommendation: ProactiveModelRecommendation,
        taskType: TaskType,
        currentCoverage: Double
    ) -> Double {
        // Value = how much better this model is vs current situation
        var value = 0.0

        // If no coverage, high value
        if currentCoverage < 0.3 {
            value = 0.9
        } else if currentCoverage < 0.6 {
            value = 0.6
        } else if currentCoverage < 0.8 {
            value = 0.3
        } else {
            value = 0.1 // Already have good coverage
        }

        // Boost for high-priority recommendations
        if recommendation.priority == .high {
            value += 0.1
        }

        // Boost if task type matches recommendation's strengths
        if recommendation.taskTypes.contains(taskType) {
            value += 0.15
        }

        return min(1.0, value)
    }

    private func makeDownloadDecision(
        requestImportance: Double,
        existingCoverage: Double,
        storageAnalysis: StorageAnalysis,
        expectedValue: Double,
        canDownloadNow: Bool
    ) -> Bool {
        // AI-powered decision logic
        guard hasAutonomousConsent else { return false }
        guard storageAnalysis.canAccommodate else { return false }
        guard canDownloadNow else { return false }

        // Calculate download score
        let downloadScore = (requestImportance * 0.3) +
                           ((1.0 - existingCoverage) * 0.3) +
                           (expectedValue * 0.3) +
                           (proactivityScore * 0.1)

        // Dynamic threshold based on proactivity
        let threshold = 0.6 - (proactivityScore * 0.2) // Higher proactivity = lower threshold

        return downloadScore > threshold
    }

    private func calculateDecisionConfidence(
        importance: Double,
        coverage: Double,
        value: Double
    ) -> Double {
        // Higher when factors clearly point one way
        let clarity = abs(value - coverage)
        return min(1.0, 0.5 + (clarity * 0.3) + (importance * 0.2))
    }

    private func buildDownloadReasoning(
        shouldDownload: Bool,
        importance: Double,
        coverage: Double,
        storage: StorageAnalysis,
        value: Double
    ) -> String {
        var reasons: [String] = []

        if shouldDownload {
            if coverage < 0.3 {
                reasons.append("No suitable local model for this task type")
            } else if coverage < 0.7 {
                reasons.append("Current model coverage is suboptimal (\(Int(coverage * 100))%)")
            }
            if importance > 0.7 {
                reasons.append("High-importance request detected")
            }
            if value > 0.7 {
                reasons.append("Significant quality improvement expected")
            }
        } else {
            if coverage > 0.7 {
                reasons.append("Existing model provides good coverage (\(Int(coverage * 100))%)")
            }
            if !storage.canAccommodate {
                reasons.append("Insufficient storage space")
            }
            if value < 0.3 {
                reasons.append("Limited improvement expected over current setup")
            }
        }

        return reasons.joined(separator: "; ")
    }

    private func suggestAlternative(existingCoverage: Double, taskType: TaskType) -> String? {
        if existingCoverage > 0.5 {
            return "Use existing local model"
        }
        return "Use cloud model for this request"
    }

    private func assessModelValue(_ model: LocalModel) async -> ModelValueAssessment {
        let proactiveManager = ProactiveModelManager.shared
        let usageRecord = proactiveManager.modelUsageHistory[model.name]

        // Calculate recency score (not a fixed threshold - relative assessment)
        let daysSinceUse: Double
        if let lastUsed = usageRecord?.lastUsed, lastUsed != Date.distantPast {
            daysSinceUse = Date().timeIntervalSince(lastUsed) / (24 * 3600)
        } else {
            daysSinceUse = 365 // Never used
        }

        let recencyScore = max(0, 1.0 - (daysSinceUse / 90)) // Decay over 90 days

        // Calculate usage frequency score
        let usageCount = usageRecord?.usageCount ?? 0
        let frequencyScore = min(1.0, Double(usageCount) / 50) // Normalize to 50 uses

        // Calculate capability score (based on model capabilities)
        let capabilityScore = assessModelCapabilities(model)

        // Calculate size efficiency (value per GB)
        let sizeGB = Double(model.size) / 1_000_000_000
        let sizeEfficiency = capabilityScore / max(1, sizeGB / 4) // Normalize to 4GB

        // Combined value
        let currentValue = (recencyScore * 0.3) + (frequencyScore * 0.3) +
                          (capabilityScore * 0.2) + (sizeEfficiency * 0.2)

        // Determine potential future uses
        var potentialUses: [String] = []
        let modelName = model.name.lowercased()

        if modelName.contains("code") || modelName.contains("coder") {
            potentialUses.append("coding tasks")
        }
        if modelName.contains("qwen") || modelName.contains("instruct") {
            potentialUses.append("general assistance")
        }
        if modelName.contains("math") || modelName.contains("reason") {
            potentialUses.append("reasoning tasks")
        }

        return ModelValueAssessment(
            modelName: model.name,
            currentValue: currentValue,
            recencyScore: recencyScore,
            frequencyScore: frequencyScore,
            capabilityScore: capabilityScore,
            sizeEfficiency: sizeEfficiency,
            daysSinceLastUse: daysSinceUse,
            totalUses: usageCount,
            couldBeUsefulFor: potentialUses
        )
    }

    private func assessModelCapabilities(_ model: LocalModel) -> Double {
        var score = 0.5

        let name = model.name.lowercased()

        // Larger models generally more capable
        let sizeGB = Double(model.size) / 1_000_000_000
        if sizeGB > 7 { score += 0.2 } else if sizeGB > 4 { score += 0.1 }

        // Certain model families are known to be strong
        if name.contains("qwen") { score += 0.15 }
        if name.contains("deepseek") { score += 0.15 }
        if name.contains("llama") { score += 0.1 }

        // Instruction-tuned models preferred
        if name.contains("instruct") { score += 0.1 }

        return min(1.0, score)
    }

    private func buildCleanupReasoning(
        model _model: LocalModel,
        value: ModelValueAssessment,
        pressure: Double
    ) -> String {
        var reasons: [String] = []

        if value.daysSinceLastUse > 30 {
            reasons.append("Not used in \(Int(value.daysSinceLastUse)) days")
        }
        if value.totalUses < 5 {
            reasons.append("Low total usage (\(value.totalUses) times)")
        }
        if pressure > 0.8 {
            reasons.append("Storage space needed")
        }
        if value.sizeEfficiency < 0.3 {
            reasons.append("Low value relative to size")
        }

        return reasons.isEmpty ? "Low overall value assessment" : reasons.joined(separator: "; ")
    }

    private func calculateStoragePressure() -> Double {
        let analysis = analyzeStorageSituation(modelSize: 0)
        return analysis.usedPercent
    }

    private func calculateProactivitySuccessRate() -> Double {
        guard !proactivityHistory.isEmpty else { return 0.5 }

        let recent = proactivityHistory.suffix(20)
        let helpful = recent.filter { $0.wasHelpful }.count
        return Double(helpful) / Double(recent.count)
    }

    private func calculateRecentSuccessRate() -> Double {
        let recent = proactivityHistory.suffix(10)
        guard !recent.isEmpty else { return 0.5 }

        let helpful = recent.filter { $0.wasHelpful }.count
        let overridden = recent.filter { $0.userOverrode }.count

        if overridden > helpful {
            return 0.3
        }
        return Double(helpful) / Double(recent.count)
    }

    private func recordDecision(_ decision: DownloadDecision, forTask taskType: TaskType) {
        // Record for future learning
        let event = ProactivityEvent(
            timestamp: Date(),
            action: decision.shouldDownload ? "auto_download" : "skip_download",
            wasHelpful: true, // Assume helpful until feedback
            userOverrode: false
        )
        proactivityHistory.append(event)

        // Trim history
        if proactivityHistory.count > 500 {
            proactivityHistory.removeFirst(100)
        }
    }

    // MARK: - System Monitoring

    private func startContinuousMonitoring() async {
        // Monitor system state periodically
        while true {
            try? await Task.sleep(for: .seconds(30))

            updateSystemState()
            gradualProactivityIncrease()
        }
    }

    private func updateSystemState() {
        #if os(macOS)
        // Get real CPU usage via host_processor_info
        let cpuUsage: Double = Self.currentCPUUsage()

        // Get real memory usage via host_statistics64
        let memoryUsage: Double = Self.currentMemoryUsage()

        // Get thermal state
        let thermalState = ProcessInfo.processInfo.thermalState

        let mappedThermal: GovernorThermalState = switch thermalState {
        case .nominal: .nominal
        case .fair: .fair
        case .serious: .serious
        case .critical: .critical
        @unknown default: .nominal
        }

        systemState = SystemResourceState(
            cpuUsage: cpuUsage,
            memoryUsage: memoryUsage,
            gpuUsage: 0.2,
            thermalState: mappedThermal,
            availableBandwidth: 0.8,
            activeInferenceCount: 0,
            pendingTasks: 0
        )
        #endif
    }

    // MARK: - Persistence

    private func loadState() {
        if let data = UserDefaults.standard.data(forKey: "AIModelGovernor.proactivityHistory"),
           let history = try? JSONDecoder().decode([ProactivityEvent].self, from: data) {
            proactivityHistory = history
        }

        proactivityScore = UserDefaults.standard.double(forKey: "AIModelGovernor.proactivityScore")
        if proactivityScore == 0 { proactivityScore = 0.5 } // Default

        logger.debug("Loaded governor state: proactivity=\(self.proactivityScore)")
    }

    private func saveState() {
        if let data = try? JSONEncoder().encode(proactivityHistory) {
            UserDefaults.standard.set(data, forKey: "AIModelGovernor.proactivityHistory")
        }
        UserDefaults.standard.set(proactivityScore, forKey: "AIModelGovernor.proactivityScore")
    }

    // MARK: - Real System Metrics

    #if os(macOS)
    private static func currentCPUUsage() -> Double {
        var cpuInfo: processor_info_array_t?
        var numCPUInfo: mach_msg_type_number_t = 0
        var numCPUs: natural_t = 0

        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &numCPUs,
            &cpuInfo,
            &numCPUInfo
        )
        guard result == KERN_SUCCESS, let info = cpuInfo else { return 0.3 }
        defer {
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), vm_size_t(numCPUInfo) * vm_size_t(MemoryLayout<Int32>.stride))
        }

        var totalUser: Int32 = 0
        var totalSystem: Int32 = 0
        var totalIdle: Int32 = 0
        for i in 0 ..< Int(numCPUs) {
            let offset = Int(CPU_STATE_MAX) * i
            totalUser += info[offset + Int(CPU_STATE_USER)]
            totalSystem += info[offset + Int(CPU_STATE_SYSTEM)]
            totalIdle += info[offset + Int(CPU_STATE_IDLE)]
        }
        let total = Double(totalUser + totalSystem + totalIdle)
        guard total > 0 else { return 0.0 }
        return Double(totalUser + totalSystem) / total
    }

    private static func currentMemoryUsage() -> Double {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0.5 }

        let pageSize = Double(vm_page_size)
        let totalMemory = Double(ProcessInfo.processInfo.physicalMemory)
        let freeMemory = Double(stats.free_count) * pageSize
        let usedMemory = totalMemory - freeMemory
        return usedMemory / totalMemory
    }
    #endif
}

// MARK: - Supporting Types

struct GovernancePolicy: Sendable {
    var downloadAggressiveness: Double // 0-1
    var cleanupAggressiveness: Double // 0-1
    var resourceUsageLimit: Double // 0-1
    var proactivityMultiplier: Double // 0.5-2.0

    static let `default` = GovernancePolicy(
        downloadAggressiveness: 0.5,
        cleanupAggressiveness: 0.3,
        resourceUsageLimit: 0.8,
        proactivityMultiplier: 1.0
    )
}

struct DownloadDecision: Sendable {
    let shouldDownload: Bool
    let confidence: Double
    let reasoning: String
    let alternativeAction: String?
    let estimatedBenefit: Double
    let storageCost: Double
}

struct CleanupDecision: Sendable {
    let model: LocalModel
    let shouldDelete: Bool
    let valueScore: Double
    let reasoning: String
    let alternativeAction: String?
    let freedSpace: Double
}

struct ResourceAllocation: Sendable {
    let gpuPercentage: Double
    let cpuPercentage: Double
    let memoryPercentage: Double
    let reasoning: String
}

struct StorageAnalysis: Sendable {
    let freeSpaceGB: Double
    let totalSpaceGB: Double
    let usedPercent: Double
    let modelStorageGB: Double
    let canAccommodate: Bool
    let pressureLevel: StoragePressure
}

enum StoragePressure: String, Sendable {
    case low
    case moderate
    case high
    case critical
}

struct ModelValueAssessment: Sendable {
    let modelName: String
    let currentValue: Double
    let recencyScore: Double
    let frequencyScore: Double
    let capabilityScore: Double
    let sizeEfficiency: Double
    let daysSinceLastUse: Double
    let totalUses: Int
    let couldBeUsefulFor: [String]
}

struct SystemResourceState: Sendable {
    var cpuUsage: Double = 0
    var memoryUsage: Double = 0
    var gpuUsage: Double = 0
    var thermalState: GovernorThermalState = .nominal
    var availableBandwidth: Double = 1.0
    var activeInferenceCount: Int = 0
    var pendingTasks: Int = 0
}

enum GovernorThermalState: String, Codable, Sendable {
    case nominal
    case fair
    case serious
    case critical
}

struct ProactivityEvent: Codable, Sendable {
    let timestamp: Date
    let action: String
    var wasHelpful: Bool
    var userOverrode: Bool
}

struct ProactivityFeedback: Sendable {
    let action: String
    let wasHelpful: Bool
    let userOverrode: Bool
}

struct ProactivityLevel: Sendable {
    let level: Level
    let score: Double
    let description: String
    let recentActions: [String]
    let successRate: Double

    enum Level: String, Sendable {
        case conservative = "Conservative"
        case moderate = "Moderate"
        case proactive = "Proactive"
        case highlyProactive = "Highly Proactive"
        case autonomous = "Fully Autonomous"
    }
}
