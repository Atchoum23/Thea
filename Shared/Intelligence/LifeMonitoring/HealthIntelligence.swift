// HealthIntelligence.swift
// THEA - Health & Wellness Intelligence
// Created by Claude - February 2026
//
// Integrates health data, medications, and psychological assessments
// Tracks ADHD/IQ/EQ tests, medication efficacy, and overall wellness

import Foundation
#if canImport(HealthKit)
import HealthKit
#endif

// MARK: - Health Data Types

/// Categories of health data
public enum WellnessCategory: String, Sendable, CaseIterable {
    case activity            // Steps, exercise, movement
    case sleep               // Sleep duration, quality
    case vitals              // Heart rate, blood pressure
    case nutrition           // Food, water, caffeine
    case mentalHealth = "mental_health"  // Mood, stress, anxiety
    case medications         // Rx and supplements
    case cognitive           // Focus, memory, attention
    case body                // Weight, body composition
}

/// Mental health assessment types
public enum PsychAssessmentType: String, Sendable, CaseIterable {
    case adhd                // ADHD assessment
    case anxiety             // GAD-7
    case depression          // PHQ-9
    case stress              // PSS
    case iq                  // IQ test results
    case eq                  // Emotional intelligence
    case burnout             // Burnout assessment
    case sleep               // Sleep quality assessment
    case custom              // User-defined assessments

    public var displayName: String {
        switch self {
        case .adhd: return "ADHD Assessment"
        case .anxiety: return "Anxiety (GAD-7)"
        case .depression: return "Depression (PHQ-9)"
        case .stress: return "Stress (PSS)"
        case .iq: return "IQ Assessment"
        case .eq: return "Emotional Intelligence"
        case .burnout: return "Burnout Assessment"
        case .sleep: return "Sleep Quality"
        case .custom: return "Custom Assessment"
        }
    }
}

// MARK: - Medication Tracking

/// A tracked medication or supplement
public struct Medication: Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let genericName: String?
    public let dosage: String
    public let frequency: MedicationFrequency
    public let purpose: String?
    public let category: MedicationCategory
    public let sideEffects: [String]?
    public let interactions: [String]?
    public let prescribedBy: String?
    public let startDate: Date
    public var endDate: Date?
    public var isActive: Bool { endDate == nil || endDate! > Date() }
    public let notes: String?

    public enum MedicationFrequency: String, Sendable {
        case asNeeded = "as_needed"
        case onceDaily = "once_daily"
        case twiceDaily = "twice_daily"
        case thriceDaily = "thrice_daily"
        case weekly
        case biweekly
        case monthly
        case custom

        public var displayName: String {
            switch self {
            case .asNeeded: return "As needed"
            case .onceDaily: return "Once daily"
            case .twiceDaily: return "Twice daily"
            case .thriceDaily: return "Three times daily"
            case .weekly: return "Weekly"
            case .biweekly: return "Every two weeks"
            case .monthly: return "Monthly"
            case .custom: return "Custom schedule"
            }
        }
    }

    public enum MedicationCategory: String, Sendable {
        case adhd
        case antidepressant
        case anxiolytic
        case sleepAid = "sleep_aid"
        case painRelief = "pain_relief"
        case vitamin
        case supplement
        case other
    }

    public init(
        id: UUID = UUID(),
        name: String,
        genericName: String? = nil,
        dosage: String,
        frequency: MedicationFrequency,
        purpose: String? = nil,
        category: MedicationCategory,
        sideEffects: [String]? = nil,
        interactions: [String]? = nil,
        prescribedBy: String? = nil,
        startDate: Date = Date(),
        endDate: Date? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.name = name
        self.genericName = genericName
        self.dosage = dosage
        self.frequency = frequency
        self.purpose = purpose
        self.category = category
        self.sideEffects = sideEffects
        self.interactions = interactions
        self.prescribedBy = prescribedBy
        self.startDate = startDate
        self.endDate = endDate
        self.notes = notes
    }
}

/// A medication intake log
public struct MedicationLog: Identifiable, Sendable {
    public let id: UUID
    public let medicationId: UUID
    public let timestamp: Date
    public let doseTaken: String
    public let scheduledTime: Date?
    public let takenOnTime: Bool
    public let skipped: Bool
    public let skipReason: String?
    public let sideEffectsNoted: [String]?
    public let effectivenessRating: Int? // 1-5
    public let notes: String?

    public init(
        id: UUID = UUID(),
        medicationId: UUID,
        timestamp: Date = Date(),
        doseTaken: String,
        scheduledTime: Date? = nil,
        skipped: Bool = false,
        skipReason: String? = nil,
        sideEffectsNoted: [String]? = nil,
        effectivenessRating: Int? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.medicationId = medicationId
        self.timestamp = timestamp
        self.doseTaken = doseTaken
        self.scheduledTime = scheduledTime
        self.takenOnTime = scheduledTime.map { abs(timestamp.timeIntervalSince($0)) < 1800 } ?? true
        self.skipped = skipped
        self.skipReason = skipReason
        self.sideEffectsNoted = sideEffectsNoted
        self.effectivenessRating = effectivenessRating
        self.notes = notes
    }
}

// MARK: - Psychological Assessments

/// A completed psychological assessment
public struct PsychologicalAssessment: Identifiable, Sendable {
    public let id: UUID
    public let type: PsychAssessmentType
    public let dateTaken: Date
    public let score: Double
    public let maxScore: Double
    public let interpretation: String
    public let severity: SeverityLevel
    public let responses: [AssessmentResponse]
    public let notes: String?
    public let source: String? // Where it was administered

    public enum SeverityLevel: String, Sendable {
        case minimal
        case mild
        case moderate
        case moderateSevere = "moderate_severe"
        case severe

        public var color: String {
            switch self {
            case .minimal: return "green"
            case .mild: return "yellow"
            case .moderate: return "orange"
            case .moderateSevere: return "red"
            case .severe: return "darkred"
            }
        }
    }

    public struct AssessmentResponse: Sendable {
        public let questionNumber: Int
        public let questionText: String
        public let response: String
        public let score: Int
    }

    public init(
        id: UUID = UUID(),
        type: PsychAssessmentType,
        score: Double,
        maxScore: Double,
        interpretation: String,
        severity: SeverityLevel,
        responses: [AssessmentResponse] = [],
        notes: String? = nil,
        source: String? = nil
    ) {
        self.id = id
        self.type = type
        self.dateTaken = Date()
        self.score = score
        self.maxScore = maxScore
        self.interpretation = interpretation
        self.severity = severity
        self.responses = responses
        self.notes = notes
        self.source = source
    }

    public var percentageScore: Double {
        maxScore > 0 ? (score / maxScore) * 100 : 0
    }
}

// MARK: - Health Insight

/// An insight derived from health data
public struct HealthMonitorInsight: Identifiable, Sendable {
    public let id: UUID
    public let category: WellnessCategory
    public let title: String
    public let description: String
    public let significance: Significance
    public let dataPoints: [String: Double]
    public let recommendation: String?
    public let relatedMedications: [UUID]?
    public let timestamp: Date

    public enum Significance: String, Sendable {
        case informational = "info"
        case positive
        case warning
        case concern
        case urgent
    }

    public init(
        id: UUID = UUID(),
        category: WellnessCategory,
        title: String,
        description: String,
        significance: Significance,
        dataPoints: [String: Double] = [:],
        recommendation: String? = nil,
        relatedMedications: [UUID]? = nil
    ) {
        self.id = id
        self.category = category
        self.title = title
        self.description = description
        self.significance = significance
        self.dataPoints = dataPoints
        self.recommendation = recommendation
        self.relatedMedications = relatedMedications
        self.timestamp = Date()
    }
}

// MARK: - Health Intelligence Engine

/// Main engine for health and wellness intelligence
public actor HealthIntelligence {
    // MARK: - Singleton

    public static let shared = HealthIntelligence()

    // MARK: - Properties

    private var medications: [UUID: Medication] = [:]
    private var medicationLogs: [MedicationLog] = []
    private var assessments: [PsychologicalAssessment] = []
    private var insights: [HealthMonitorInsight] = []
    private var isRunning = false

    #if canImport(HealthKit)
    private let healthStore = HKHealthStore()
    private var authorizedTypes: Set<HKObjectType> = []
    #endif

    // Callbacks
    private var onInsightGenerated: ((HealthMonitorInsight) -> Void)?
    private var onMedicationReminder: ((Medication, Date) -> Void)?
    private var onHealthAlert: ((HealthMonitorInsight) -> Void)?
    private var onAssessmentDue: ((PsychAssessmentType) -> Void)?

    // MARK: - Configuration

    public struct Configuration: Sendable {
        public var syncWithHealthKit: Bool = true
        public var trackMedications: Bool = true
        public var trackAssessments: Bool = true
        public var generateInsights: Bool = true
        public var medicationReminderLeadTime: TimeInterval = 900 // 15 min before
        public var assessmentReminderFrequency: TimeInterval = 604800 // Weekly

        public init() {}
    }

    private var configuration: Configuration

    // MARK: - Initialization

    private init() {
        self.configuration = Configuration()
    }

    // MARK: - Configuration

    public func configure(_ config: Configuration) {
        self.configuration = config
    }

    public func configure(
        onInsightGenerated: @escaping @Sendable (HealthMonitorInsight) -> Void,
        onMedicationReminder: @escaping @Sendable (Medication, Date) -> Void,
        onHealthAlert: @escaping @Sendable (HealthMonitorInsight) -> Void,
        onAssessmentDue: @escaping @Sendable (PsychAssessmentType) -> Void
    ) {
        self.onInsightGenerated = onInsightGenerated
        self.onMedicationReminder = onMedicationReminder
        self.onHealthAlert = onHealthAlert
        self.onAssessmentDue = onAssessmentDue
    }

    // MARK: - Lifecycle

    public func start() async {
        guard !isRunning else { return }
        isRunning = true

        // Request HealthKit authorization
        if configuration.syncWithHealthKit {
            await requestHealthKitAuthorization()
        }

        // Start monitoring
        await startMonitoring()
    }

    public func stop() {
        isRunning = false
    }

    // MARK: - Medication Management

    /// Add a medication to track
    public func addMedication(_ medication: Medication) {
        medications[medication.id] = medication
    }

    /// Update a medication
    public func updateMedication(_ medication: Medication) {
        medications[medication.id] = medication
    }

    /// Remove a medication
    public func removeMedication(_ id: UUID) {
        medications.removeValue(forKey: id)
    }

    /// Get all active medications
    public func getActiveMedications() -> [Medication] {
        medications.values.filter { $0.isActive }
    }

    /// Get medications by category
    public func getMedications(category: Medication.MedicationCategory) -> [Medication] {
        medications.values.filter { $0.category == category && $0.isActive }
    }

    /// Log a medication intake
    public func logMedicationIntake(_ log: MedicationLog) {
        medicationLogs.append(log)

        // Generate insight if noteworthy
        if log.skipped {
            let insight = HealthMonitorInsight(
                category: .medications,
                title: "Medication Skipped",
                description: "You skipped your \(medications[log.medicationId]?.name ?? "medication") dose.",
                significance: .warning,
                recommendation: log.skipReason
            )
            insights.append(insight)
            onInsightGenerated?(insight)
        }

        // Track effectiveness over time
        Task {
            await analyzeMedicationEffectiveness(log.medicationId)
        }
    }

    /// Get medication adherence rate
    public func getMedicationAdherence(_ medicationId: UUID, days: Int = 30) -> Double {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        let logs = medicationLogs.filter {
            $0.medicationId == medicationId && $0.timestamp >= cutoff
        }

        guard !logs.isEmpty else { return 0 }

        let taken = logs.filter { !$0.skipped }.count
        return Double(taken) / Double(logs.count)
    }

    /// Get medication logs for a specific medication
    public func getMedicationLogs(_ medicationId: UUID, limit: Int = 100) -> [MedicationLog] {
        medicationLogs
            .filter { $0.medicationId == medicationId }
            .suffix(limit)
    }

    // MARK: - Assessment Management

    /// Record a new assessment
    public func recordAssessment(_ assessment: PsychologicalAssessment) {
        assessments.append(assessment)

        // Generate insight
        let insight = generateAssessmentInsight(assessment)
        insights.append(insight)
        onInsightGenerated?(insight)

        // Check for alerts
        if assessment.severity == .severe || assessment.severity == .moderateSevere {
            onHealthAlert?(insight)
        }
    }

    /// Get assessments by type
    public func getAssessments(type: PsychAssessmentType, limit: Int = 10) -> [PsychologicalAssessment] {
        assessments
            .filter { $0.type == type }
            .sorted { $0.dateTaken > $1.dateTaken }
            .prefix(limit)
            .map { $0 }
    }

    /// Get assessment trend
    public func getAssessmentTrend(type: PsychAssessmentType) -> AssessmentTrend {
        let typeAssessments = assessments
            .filter { $0.type == type }
            .sorted { $0.dateTaken < $1.dateTaken }

        guard typeAssessments.count >= 2 else {
            return AssessmentTrend(direction: .stable, changePercentage: 0, dataPoints: [])
        }

        let recent = typeAssessments.suffix(5)
        let scores = recent.map { $0.percentageScore }

        let trend: AssessmentTrend.Direction
        let change: Double

        if scores.count >= 2 {
            let first = scores[0]
            let last = scores[scores.count - 1]
            change = ((last - first) / first) * 100

            if change > 10 {
                trend = type == .iq || type == .eq ? .improving : .worsening
            } else if change < -10 {
                trend = type == .iq || type == .eq ? .worsening : .improving
            } else {
                trend = .stable
            }
        } else {
            trend = .stable
            change = 0
        }

        return AssessmentTrend(
            direction: trend,
            changePercentage: change,
            dataPoints: recent.map { ($0.dateTaken, $0.percentageScore) }
        )
    }

    /// Schedule next assessment
    public func scheduleNextAssessment(_ type: PsychAssessmentType) -> Date {
        let lastAssessment = assessments
            .filter { $0.type == type }
            .sorted { $0.dateTaken > $1.dateTaken }
            .first

        let interval = configuration.assessmentReminderFrequency
        let baseDate = lastAssessment?.dateTaken ?? Date()

        return baseDate.addingTimeInterval(interval)
    }

    // MARK: - Health Insights

    /// Get all insights
    public func getInsights(category: WellnessCategory? = nil, limit: Int = 50) -> [HealthMonitorInsight] {
        var filtered = insights
        if let cat = category {
            filtered = filtered.filter { $0.category == cat }
        }
        return Array(filtered.suffix(limit))
    }

    /// Generate daily health summary
    public func getDailySummary() async -> HealthMonitoringSummary {
        let today = Calendar.current.startOfDay(for: Date())

        // Get today's medication logs
        let todayLogs = medicationLogs.filter {
            Calendar.current.isDate($0.timestamp, inSameDayAs: today)
        }

        let medicationsTaken = todayLogs.filter { !$0.skipped }.count
        let medicationsSkipped = todayLogs.filter { $0.skipped }.count

        // Get recent assessments
        let recentAssessments = assessments.filter {
            $0.dateTaken >= today.addingTimeInterval(-604800) // Last week
        }

        // Get health data from HealthKit
        let healthData = await fetchTodayHealthData()

        return HealthMonitoringSummary(
            date: today,
            medicationsTaken: medicationsTaken,
            medicationsSkipped: medicationsSkipped,
            adherenceRate: getMedicationAdherence(UUID(), days: 7), // Overall
            recentAssessments: recentAssessments.count,
            healthMetrics: healthData,
            insights: getInsights(limit: 10)
        )
    }

    // MARK: - Private Methods

    private func requestHealthKitAuthorization() async {
        #if canImport(HealthKit)
        guard HKHealthStore.isHealthDataAvailable() else { return }

        let readTypes: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
            HKObjectType.quantityType(forIdentifier: .bodyMass)!,
            HKObjectType.quantityType(forIdentifier: .restingHeartRate)!,
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
        ]

        do {
            try await healthStore.requestAuthorization(toShare: [], read: readTypes)
            authorizedTypes = readTypes
        } catch {
            // Handle error
        }
        #endif
    }

    private func checkIsRunning() -> Bool {
        isRunning
    }

    private func startMonitoring() async {
        // Start medication reminder monitoring
        Task { [weak self] in
            while await (self?.checkIsRunning() ?? false) {
                await self?.checkMedicationReminders()
                try? await Task.sleep(nanoseconds: 60_000_000_000) // Check every minute
            }
        }

        // Start assessment reminder monitoring
        Task { [weak self] in
            while await (self?.checkIsRunning() ?? false) {
                await self?.checkAssessmentReminders()
                try? await Task.sleep(nanoseconds: 3600_000_000_000) // Check every hour
            }
        }

        // Start health data sync
        Task { [weak self] in
            while await (self?.checkIsRunning() ?? false) {
                await self?.syncHealthData()
                try? await Task.sleep(nanoseconds: 1800_000_000_000) // Sync every 30 min
            }
        }
    }

    private func checkMedicationReminders() async {
        let now = Date()

        for medication in medications.values where medication.isActive {
            // Calculate next dose time based on frequency
            let nextDose = calculateNextDoseTime(for: medication)
            let reminderTime = nextDose.addingTimeInterval(-configuration.medicationReminderLeadTime)

            if now >= reminderTime && now < nextDose {
                onMedicationReminder?(medication, nextDose)
            }
        }
    }

    private func calculateNextDoseTime(for medication: Medication) -> Date {
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)

        switch medication.frequency {
        case .onceDaily:
            // Assume 8 AM
            let morning = calendar.date(byAdding: .hour, value: 8, to: today)!
            return morning > now ? morning : calendar.date(byAdding: .day, value: 1, to: morning)!

        case .twiceDaily:
            // 8 AM and 8 PM
            let morning = calendar.date(byAdding: .hour, value: 8, to: today)!
            let evening = calendar.date(byAdding: .hour, value: 20, to: today)!
            if morning > now { return morning }
            if evening > now { return evening }
            return calendar.date(byAdding: .day, value: 1, to: morning)!

        case .thriceDaily:
            // 8 AM, 2 PM, 8 PM
            let times = [8, 14, 20].map { calendar.date(byAdding: .hour, value: $0, to: today)! }
            for time in times {
                if time > now { return time }
            }
            return calendar.date(byAdding: .day, value: 1, to: times[0])!

        default:
            return now.addingTimeInterval(3600) // 1 hour from now
        }
    }

    private func checkAssessmentReminders() async {
        for type in PsychAssessmentType.allCases where type != .custom {
            let nextDue = scheduleNextAssessment(type)
            let now = Date()

            if nextDue <= now {
                onAssessmentDue?(type)
            }
        }
    }

    private func syncHealthData() async {
        // Sync from HealthKit
        #if canImport(HealthKit)
        // Implementation would fetch latest health data
        #endif
    }

    private func fetchTodayHealthData() async -> [String: Double] {
        let data: [String: Double] = [:]

        #if canImport(HealthKit)
        // Would fetch from HealthKit
        // For now, return empty
        #endif

        return data
    }

    private func analyzeMedicationEffectiveness(_ medicationId: UUID) async {
        let logs = getMedicationLogs(medicationId, limit: 30)
        let ratings = logs.compactMap { $0.effectivenessRating }

        guard !ratings.isEmpty else { return }

        let avgRating = Double(ratings.reduce(0, +)) / Double(ratings.count)

        if avgRating < 2.5 {
            let insight = HealthMonitorInsight(
                category: .medications,
                title: "Low Medication Effectiveness",
                description: "Your \(medications[medicationId]?.name ?? "medication") has been rated low in effectiveness recently.",
                significance: .warning,
                dataPoints: ["average_rating": avgRating],
                recommendation: "Consider discussing alternatives with your healthcare provider.",
                relatedMedications: [medicationId]
            )
            insights.append(insight)
            onInsightGenerated?(insight)
        }
    }

    private func generateAssessmentInsight(_ assessment: PsychologicalAssessment) -> HealthMonitorInsight {
        let significance: HealthMonitorInsight.Significance
        switch assessment.severity {
        case .minimal: significance = .positive
        case .mild: significance = .informational
        case .moderate: significance = .warning
        case .moderateSevere, .severe: significance = .concern
        }

        return HealthMonitorInsight(
            category: .mentalHealth,
            title: "\(assessment.type.displayName) Results",
            description: "\(assessment.interpretation). Score: \(Int(assessment.score))/\(Int(assessment.maxScore))",
            significance: significance,
            dataPoints: ["score": assessment.score, "max_score": assessment.maxScore],
            recommendation: generateRecommendation(for: assessment)
        )
    }

    private func generateRecommendation(for assessment: PsychologicalAssessment) -> String? {
        switch assessment.severity {
        case .minimal:
            return "Continue with your current wellness practices."
        case .mild:
            return "Consider stress-reduction techniques and regular exercise."
        case .moderate:
            return "You may benefit from speaking with a mental health professional."
        case .moderateSevere:
            return "Please consider scheduling an appointment with a healthcare provider."
        case .severe:
            return "It's important to seek professional support. Consider reaching out to a mental health provider soon."
        }
    }
}

// MARK: - Supporting Types

public struct AssessmentTrend: Sendable {
    public let direction: Direction
    public let changePercentage: Double
    public let dataPoints: [(Date, Double)]

    public enum Direction: String, Sendable {
        case improving
        case stable
        case worsening
    }
}

public struct HealthMonitoringSummary: Sendable {
    public let date: Date
    public let medicationsTaken: Int
    public let medicationsSkipped: Int
    public let adherenceRate: Double
    public let recentAssessments: Int
    public let healthMetrics: [String: Double]
    public let insights: [HealthMonitorInsight]
}
