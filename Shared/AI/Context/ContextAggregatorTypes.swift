// ContextAggregatorTypes.swift
// Types and models for the ContextAggregator

import Foundation
import os.log

// MARK: - Aggregated Context

public struct AggregatedContext: Sendable {
    public var timestamp: Date
    public var device: ContextDeviceState
    public var user: ContextUserState
    public var aiResources: ContextAIResources
    public var temporal: ContextTemporal
    public var patterns: ContextPatterns
    public var query: ContextQuery

    public init(
        timestamp: Date = Date(),
        device: ContextDeviceState = ContextDeviceState(),
        user: ContextUserState = ContextUserState(),
        aiResources: ContextAIResources = ContextAIResources(),
        temporal: ContextTemporal = ContextTemporal(),
        patterns: ContextPatterns = ContextPatterns(),
        query: ContextQuery = ContextQuery()
    ) {
        self.timestamp = timestamp
        self.device = device
        self.user = user
        self.aiResources = aiResources
        self.temporal = temporal
        self.patterns = patterns
        self.query = query
    }
}

// MARK: - Context Components

public struct ContextDeviceState: Sendable {
    public var platform: String
    public var batteryLevel: Int?
    public var isPluggedIn: Bool?
    public var totalMemoryGB: Double
    public var availableMemoryGB: Double
    public var availableStorageGB: Double
    public var thermalState: ContextThermalState
    public var networkStatus: ContextNetworkStatus
    public var hasAppleSilicon: Bool
    public var hasNeuralEngine: Bool

    public init(
        platform: String = "Unknown",
        batteryLevel: Int? = nil,
        isPluggedIn: Bool? = nil,
        totalMemoryGB: Double = 0,
        availableMemoryGB: Double = 0,
        availableStorageGB: Double = 0,
        thermalState: ContextThermalState = .nominal,
        networkStatus: ContextNetworkStatus = .connected,
        hasAppleSilicon: Bool = false,
        hasNeuralEngine: Bool = false
    ) {
        self.platform = platform
        self.batteryLevel = batteryLevel
        self.isPluggedIn = isPluggedIn
        self.totalMemoryGB = totalMemoryGB
        self.availableMemoryGB = availableMemoryGB
        self.availableStorageGB = availableStorageGB
        self.thermalState = thermalState
        self.networkStatus = networkStatus
        self.hasAppleSilicon = hasAppleSilicon
        self.hasNeuralEngine = hasNeuralEngine
    }
}

public struct ContextUserState: Sendable {
    public var userName: String
    public var preferredLanguage: String
    public var interactionCount: Int
    public var currentActivity: String?
    public var approximateLocation: String?
    public var preferredResponseStyle: String
    public var workingHoursStart: Int
    public var workingHoursEnd: Int

    public init(
        userName: String = "User",
        preferredLanguage: String = "en",
        interactionCount: Int = 0,
        currentActivity: String? = nil,
        approximateLocation: String? = nil,
        preferredResponseStyle: String = "balanced",
        workingHoursStart: Int = 9,
        workingHoursEnd: Int = 17
    ) {
        self.userName = userName
        self.preferredLanguage = preferredLanguage
        self.interactionCount = interactionCount
        self.currentActivity = currentActivity
        self.approximateLocation = approximateLocation
        self.preferredResponseStyle = preferredResponseStyle
        self.workingHoursStart = workingHoursStart
        self.workingHoursEnd = workingHoursEnd
    }
}

public struct ContextAIResources: Sendable {
    public var localModelCount: Int
    public var localModelNames: [String]
    public var cloudProvidersConfigured: [String]
    public var preferredProvider: String
    public var preferredModel: String
    public var orchestratorEnabled: Bool
    public var totalModelsAvailable: Int

    public init(
        localModelCount: Int = 0,
        localModelNames: [String] = [],
        cloudProvidersConfigured: [String] = [],
        preferredProvider: String = "",
        preferredModel: String = "",
        orchestratorEnabled: Bool = false,
        totalModelsAvailable: Int = 0
    ) {
        self.localModelCount = localModelCount
        self.localModelNames = localModelNames
        self.cloudProvidersConfigured = cloudProvidersConfigured
        self.preferredProvider = preferredProvider
        self.preferredModel = preferredModel
        self.orchestratorEnabled = orchestratorEnabled
        self.totalModelsAvailable = totalModelsAvailable
    }
}

public struct ContextTemporal: Sendable {
    public var timestamp: Date
    public var hourOfDay: Int
    public var dayOfWeek: Int
    public var isWeekend: Bool
    public var timeZone: String
    public var isWorkingHours: Bool

    public init(
        timestamp: Date = Date(),
        hourOfDay: Int = Calendar.current.component(.hour, from: Date()),
        dayOfWeek: Int = Calendar.current.component(.weekday, from: Date()),
        isWeekend: Bool = Calendar.current.isDateInWeekend(Date()),
        timeZone: String = TimeZone.current.identifier,
        isWorkingHours: Bool = true
    ) {
        self.timestamp = timestamp
        self.hourOfDay = hourOfDay
        self.dayOfWeek = dayOfWeek
        self.isWeekend = isWeekend
        self.timeZone = timeZone
        self.isWorkingHours = isWorkingHours
    }
}

public struct ContextPatterns: Sendable {
    public var detectedPatterns: [MemoryDetectedPattern]
    public var preferredModelByTask: [String: Double]
    public var topPreferredModel: String?

    public init(
        detectedPatterns: [MemoryDetectedPattern] = [],
        preferredModelByTask: [String: Double] = [:],
        topPreferredModel: String? = nil
    ) {
        self.detectedPatterns = detectedPatterns
        self.preferredModelByTask = preferredModelByTask
        self.topPreferredModel = topPreferredModel
    }
}

public struct ContextQuery: Sendable {
    public var currentQuery: String?
    public var inferredIntent: String?
    public var recentQueries: [String]

    public init(
        currentQuery: String? = nil,
        inferredIntent: String? = nil,
        recentQueries: [String] = []
    ) {
        self.currentQuery = currentQuery
        self.inferredIntent = inferredIntent
        self.recentQueries = recentQueries
    }
}

// MARK: - Routing Weights

public struct ContextRoutingWeights: Sendable {
    public var quality: Double
    public var cost: Double
    public var speed: Double

    public var description: String {
        "Q:\(Int(quality*100))% C:\(Int(cost*100))% S:\(Int(speed*100))%"
    }
}

// MARK: - Enums

public enum ContextThermalState: String, Sendable, Codable {
    case nominal
    case fair
    case serious
    case critical
}

public enum ContextNetworkStatus: String, Sendable, Codable {
    case connected
    case constrained
    case disconnected
}

// MARK: - Aggregated Context Change

/// Represents a detected change in aggregated context
public struct AggregatedContextChange: Identifiable, Sendable {
    public let id = UUID()
    public let category: ContextChangeCategory
    public let field: String
    public let oldValue: String
    public let newValue: String
    public let significance: Double // 0-1, how important this change is
    public let recommendation: String?
    public let timestamp: Date

    public init(
        category: ContextChangeCategory,
        field: String,
        oldValue: String,
        newValue: String,
        significance: Double,
        recommendation: String? = nil,
        timestamp: Date = Date()
    ) {
        self.category = category
        self.field = field
        self.oldValue = oldValue
        self.newValue = newValue
        self.significance = significance
        self.recommendation = recommendation
        self.timestamp = timestamp
    }
}

public enum ContextChangeCategory: String, Sendable {
    case device
    case user
    case temporal
    case aiResources
    case query
}

// MARK: - Context Outcome Correlation

/// Correlation between context and task outcome for learning
struct ContextOutcomeCorrelation: Codable, Sendable {
    let contextHash: String
    let timestamp: Date
    let query: String
    let taskType: TaskType
    let modelUsed: String
    let success: Bool
    let userSatisfaction: Double?
    let latency: TimeInterval
    let batteryLevel: Int?
    let networkStatus: ContextNetworkStatus
    let isWorkingHours: Bool
    let hourOfDay: Int
}

// MARK: - Context Trends

/// Trends learned from context-outcome correlations
public struct ContextTrends: Sendable {
    public var hourlySuccessRates: [Int: Double] = [:]
    public var bestPerformanceHours: [Int] = []
    public var taskTypeDistribution: [TaskType: Int] = [:]
    public var averageLatency: TimeInterval = 0
    public var totalInteractions: Int = 0

    public var description: String {
        let bestHours = bestPerformanceHours.map { "\($0):00" }.joined(separator: ", ")
        return "ContextTrends(interactions: \(totalInteractions), avgLatency: \(String(format: "%.1f", averageLatency))s, bestHours: \(bestHours))"
    }
}

// MARK: - Context Prediction

/// A prediction about context needs
public struct AggregatedContextPrediction: Identifiable, Sendable {
    public let id = UUID()
    public let prediction: String
    public let confidence: Double
    public let suggestedAction: String?
}
