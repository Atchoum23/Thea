//
//  PredictiveEngine.swift
//  Thea
//
//  Created by Thea
//  Anticipates user needs based on patterns and context
//

import CoreML
import Foundation
import os.log

// MARK: - Predictive Engine

/// Anticipates user needs by analyzing patterns and current context
@MainActor
public final class PredictiveEngine: ObservableObject {
    public static let shared = PredictiveEngine()

    private let logger = Logger(subsystem: "app.thea.context", category: "PredictiveEngine")

    // MARK: - Published State

    @Published public private(set) var predictions: [Prediction] = []
    @Published public private(set) var isProcessing = false

    // MARK: - Configuration

    public var predictionHorizon: TimeInterval = 3600 // 1 hour ahead
    public var maxPredictions = 10
    public var minimumConfidence: Double = 0.5
    public var learningEnabled = true

    // MARK: - Models

    private var appUsageModel: AppUsagePredictionModel?
    private var activityModel: ActivityPredictionModel?
    private var contextModel: ContextPredictionModel?

    // MARK: - Historical Data

    private var activityHistory: [ActivityRecord] = []
    private var transitionMatrix: [String: [String: Int]] = [:] // app -> next app -> count
    private var timeBasedPatterns: [Int: [String: Int]] = [:] // hour -> app -> count

    private let dataQueue = DispatchQueue(label: "app.thea.predictive.data")
    private var predictionTask: Task<Void, Never>?

    private init() {
        loadHistoricalData()
    }

    // MARK: - Lifecycle

    public func start() {
        logger.info("Starting PredictiveEngine")

        predictionTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.generatePredictions()
                try? await Task.sleep(nanoseconds: 60_000_000_000) // Every minute
            }
        }
    }

    public func stop() {
        predictionTask?.cancel()
        predictionTask = nil
        saveHistoricalData()
        logger.info("PredictiveEngine stopped")
    }

    // MARK: - Learning

    /// Record an activity for learning
    public func recordActivity(_ activity: ActivityRecord) {
        guard learningEnabled else { return }

        dataQueue.async { [weak self] in
            self?.activityHistory.append(activity)

            // Update transition matrix
            if let previous = self?.activityHistory.dropLast().last {
                let fromApp = previous.appBundleId ?? "unknown"
                let toApp = activity.appBundleId ?? "unknown"

                if self?.transitionMatrix[fromApp] == nil {
                    self?.transitionMatrix[fromApp] = [:]
                }
                self?.transitionMatrix[fromApp]?[toApp, default: 0] += 1
            }

            // Update time-based patterns
            let hour = Calendar.current.component(.hour, from: activity.timestamp)
            let app = activity.appBundleId ?? "unknown"

            if self?.timeBasedPatterns[hour] == nil {
                self?.timeBasedPatterns[hour] = [:]
            }
            self?.timeBasedPatterns[hour]?[app, default: 0] += 1

            // Trim history
            if let count = self?.activityHistory.count, count > 10000 {
                self?.activityHistory = Array(self?.activityHistory.suffix(5000) ?? [])
            }
        }
    }

    // MARK: - Prediction Generation

    public func generatePredictions() async {
        guard !isProcessing else { return }

        isProcessing = true
        defer { isProcessing = false }

        let context = await UnifiedContextEngine.shared.captureSnapshot()
        var newPredictions: [Prediction] = []

        // Generate predictions from different models
        async let appPredictions = predictNextApps(context: context)
        async let activityPredictions = predictNextActivities(context: context)
        async let needsPredictions = predictNeeds(context: context)

        let allPredictions = await [appPredictions, activityPredictions, needsPredictions].flatMap(\.self)

        // Filter and sort
        newPredictions = allPredictions
            .filter { $0.confidence >= minimumConfidence }
            .sorted { $0.confidence > $1.confidence }

        // Deduplicate
        var seen = Set<String>()
        newPredictions = newPredictions.filter { prediction in
            let key = "\(prediction.type)_\(prediction.title)"
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }

        predictions = Array(newPredictions.prefix(maxPredictions))

        logger.debug("Generated \(predictions.count) predictions")
    }

    // MARK: - Prediction Models

    private func predictNextApps(context: ContextSnapshot) async -> [Prediction] {
        var predictions: [Prediction] = []

        let currentHour = Calendar.current.component(.hour, from: Date())
        let currentApp = context.metadata["focusedAppBundleId"] as? String ?? "unknown"

        // Time-based prediction
        if let hourPatterns = timeBasedPatterns[currentHour] {
            let sorted = hourPatterns.sorted { $0.value > $1.value }
            let total = Double(sorted.reduce(0) { $0 + $1.value })

            for (app, count) in sorted.prefix(3) {
                let confidence = Double(count) / total
                if confidence >= 0.1 {
                    predictions.append(Prediction(
                        type: .appLaunch,
                        title: "Open \(appName(for: app))",
                        description: "You often use this app around this time",
                        confidence: confidence,
                        action: .openApp(bundleId: app),
                        validUntil: Date().addingTimeInterval(1800)
                    ))
                }
            }
        }

        // Transition-based prediction
        if let transitions = transitionMatrix[currentApp] {
            let sorted = transitions.sorted { $0.value > $1.value }
            let total = Double(sorted.reduce(0) { $0 + $1.value })

            for (nextApp, count) in sorted.prefix(3) {
                let confidence = Double(count) / total
                if confidence >= 0.15 {
                    predictions.append(Prediction(
                        type: .appLaunch,
                        title: "Switch to \(appName(for: nextApp))",
                        description: "You often switch here from \(appName(for: currentApp))",
                        confidence: confidence * 0.8, // Slightly lower than time-based
                        action: .openApp(bundleId: nextApp),
                        validUntil: Date().addingTimeInterval(600)
                    ))
                }
            }
        }

        return predictions
    }

    private func predictNextActivities(context _: ContextSnapshot) async -> [Prediction] {
        var predictions: [Prediction] = []

        let calendar = Calendar.current
        let now = Date()
        let weekday = calendar.component(.weekday, from: now)
        let hour = calendar.component(.hour, from: now)

        // Daily routine predictions
        if weekday >= 2, weekday <= 6 { // Weekday
            if hour >= 8, hour < 9 {
                predictions.append(Prediction(
                    type: .activity,
                    title: "Morning Routine",
                    description: "Check calendar and emails?",
                    confidence: 0.7,
                    action: .runShortcut(name: "Morning Routine"),
                    validUntil: now.addingTimeInterval(3600)
                ))
            } else if hour >= 12, hour < 13 {
                predictions.append(Prediction(
                    type: .activity,
                    title: "Lunch Break",
                    description: "Time for a break?",
                    confidence: 0.65,
                    action: .setFocus(mode: "Personal"),
                    validUntil: now.addingTimeInterval(3600)
                ))
            } else if hour >= 17, hour < 18 {
                predictions.append(Prediction(
                    type: .activity,
                    title: "End of Work Day",
                    description: "Review today's progress?",
                    confidence: 0.6,
                    action: .runShortcut(name: "Daily Review"),
                    validUntil: now.addingTimeInterval(3600)
                ))
            }
        }

        return predictions
    }

    private func predictNeeds(context: ContextSnapshot) async -> [Prediction] {
        var predictions: [Prediction] = []

        // Battery prediction
        if let batteryLevel = context.metadata["batteryLevel"] as? Int,
           let isCharging = context.metadata["isCharging"] as? Bool,
           !isCharging, batteryLevel < 30
        {
            let urgency = batteryLevel < 15 ? 0.9 : 0.7
            predictions.append(Prediction(
                type: .need,
                title: "Low Battery (\(batteryLevel)%)",
                description: "Consider charging soon",
                confidence: urgency,
                action: nil,
                validUntil: Date().addingTimeInterval(1800)
            ))
        }

        // Storage prediction
        if let freeSpace = context.metadata["freeStorageGB"] as? Double,
           freeSpace < 10
        {
            predictions.append(Prediction(
                type: .need,
                title: "Low Storage",
                description: "Only \(Int(freeSpace))GB free",
                confidence: freeSpace < 5 ? 0.85 : 0.6,
                action: .openApp(bundleId: "com.apple.StorageManagement"),
                validUntil: Date().addingTimeInterval(86400)
            ))
        }

        // Meeting preparation
        if let nextEvent = context.metadata["nextCalendarEvent"] as? String,
           let minutesUntil = context.metadata["minutesUntilNextEvent"] as? Int,
           minutesUntil > 5, minutesUntil <= 30
        {
            predictions.append(Prediction(
                type: .preparation,
                title: "Prepare for \(nextEvent)",
                description: "Meeting starts in \(minutesUntil) minutes",
                confidence: 0.8,
                action: .runShortcut(name: "Meeting Prep"),
                validUntil: Date().addingTimeInterval(TimeInterval(minutesUntil * 60))
            ))
        }

        return predictions
    }

    // MARK: - Helpers

    private func appName(for bundleId: String) -> String {
        #if os(macOS)
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId),
               let bundle = Bundle(url: url),
               let name = bundle.infoDictionary?["CFBundleName"] as? String
            {
                return name
            }
        #endif
        return bundleId.components(separatedBy: ".").last?.capitalized ?? bundleId
    }

    // MARK: - Persistence

    private func loadHistoricalData() {
        let fileManager = FileManager.default
        guard let containerURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: "group.app.thea") else {
            return
        }

        let dataURL = containerURL.appendingPathComponent("predictive_data.json")

        guard let data = try? Data(contentsOf: dataURL),
              let decoded = try? JSONDecoder().decode(PredictiveData.self, from: data)
        else {
            return
        }

        transitionMatrix = decoded.transitionMatrix
        timeBasedPatterns = decoded.timeBasedPatterns

        logger.info("Loaded predictive data")
    }

    private func saveHistoricalData() {
        let fileManager = FileManager.default
        guard let containerURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: "group.app.thea") else {
            return
        }

        let dataURL = containerURL.appendingPathComponent("predictive_data.json")

        let data = PredictiveData(
            transitionMatrix: transitionMatrix,
            timeBasedPatterns: timeBasedPatterns
        )

        if let encoded = try? JSONEncoder().encode(data) {
            try? encoded.write(to: dataURL)
            logger.info("Saved predictive data")
        }
    }

    // MARK: - Query

    public func predictionsFor(type: PredictionType) -> [Prediction] {
        predictions.filter { $0.type == type }
    }

    public func topPrediction() -> Prediction? {
        predictions.first
    }
}

// MARK: - Prediction Model

public struct Prediction: Identifiable, Sendable {
    public let id: String
    public let type: PredictionType
    public let title: String
    public let description: String
    public let confidence: Double
    public let action: PredictionAction?
    public let createdAt: Date
    public let validUntil: Date?

    public init(
        id: String = UUID().uuidString,
        type: PredictionType,
        title: String,
        description: String,
        confidence: Double,
        action: PredictionAction?,
        validUntil: Date? = nil
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.description = description
        self.confidence = min(1.0, max(0.0, confidence))
        self.action = action
        createdAt = Date()
        self.validUntil = validUntil
    }

    public var isValid: Bool {
        guard let validUntil else { return true }
        return Date() < validUntil
    }
}

public enum PredictionType: String, Codable, Sendable, CaseIterable {
    case appLaunch
    case activity
    case need
    case preparation
    case communication
    case location
    case content
}

public enum PredictionAction: Sendable {
    case openApp(bundleId: String)
    case runShortcut(name: String)
    case setFocus(mode: String)
    case navigate(url: URL)
    case showContent(id: String)
}

// MARK: - Activity Record

public struct ActivityRecord: Codable, Sendable {
    public let timestamp: Date
    public let appBundleId: String?
    public let activityType: String
    public let duration: TimeInterval?
    public let metadata: [String: String]

    public init(
        timestamp: Date = Date(),
        appBundleId: String? = nil,
        activityType: String,
        duration: TimeInterval? = nil,
        metadata: [String: String] = [:]
    ) {
        self.timestamp = timestamp
        self.appBundleId = appBundleId
        self.activityType = activityType
        self.duration = duration
        self.metadata = metadata
    }
}

// MARK: - Persistence Models

private struct PredictiveData: Codable {
    let transitionMatrix: [String: [String: Int]]
    let timeBasedPatterns: [Int: [String: Int]]
}

// MARK: - ML Model Protocols (Placeholder for CoreML)

protocol AppUsagePredictionModel {
    func predict(currentApp: String, hour: Int, weekday: Int) -> [(bundleId: String, probability: Double)]
}

protocol ActivityPredictionModel {
    func predict(context: ContextSnapshot) -> [(activity: String, probability: Double)]
}

protocol ContextPredictionModel {
    func predict(context: ContextSnapshot) -> [(need: String, probability: Double)]
}
