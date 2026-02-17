// PredictiveLifeEngine+Core.swift
// Thea V2 - Predictive Life Engine Core
//
// The main PredictiveLifeEngine actor: properties, initialization,
// setup, lifecycle, and context management.
// Split from PredictiveLifeEngine.swift for single-responsibility clarity.

import Combine
import Foundation
import os.log

// MARK: - Predictive Life Engine

/// AI-powered engine for predictive life intelligence.
///
/// Continuously monitors user activity patterns, calendar events,
/// communication signals, and behavioral context to generate
/// anticipatory predictions before the user asks.
///
/// Access the singleton via ``shared``. Call ``start()`` to begin
/// the background prediction loop and ``stop()`` to halt it.
@MainActor
public final class PredictiveLifeEngine: ObservableObject {
    /// The shared singleton instance.
    public static let shared = PredictiveLifeEngine()

    let logger = Logger(subsystem: "ai.thea.app", category: "PredictiveLifeEngine")

    // MARK: - Published State

    /// Currently active predictions, sorted by relevance x confidence.
    @Published public private(set) var activePredictions: [LifePrediction] = []
    /// Overall accuracy of past predictions (0-1).
    @Published public private(set) var predictionAccuracy: Double = 0.7
    /// Timestamp of the most recent prediction cycle.
    @Published public private(set) var lastPredictionRun: Date?
    /// Whether a prediction cycle is currently running.
    @Published public private(set) var isProcessing = false

    // MARK: - Configuration

    /// Current engine configuration.
    public var configuration = PredictiveEngineConfiguration()

    // MARK: - Internal State

    var predictionHistory: [LifePrediction] = []
    var contextWindow: [LifeContextSnapshot] = []

    // MARK: - Tasks

    private var predictionTask: Task<Void, Never>?

    // MARK: - Subscriptions

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private init() {
        logger.info("PredictiveLifeEngine initialized")
        setupSubscriptions()
        loadState()
    }

    // MARK: - Setup

    private func setupSubscriptions() {
        // Subscribe to pattern changes
        HolisticPatternIntelligence.shared.$detectedPatterns
            .receive(on: DispatchQueue.main)
            .sink { [weak self] patterns in
                Task { @MainActor in
                    self?.onPatternsUpdated(patterns)
                }
            }
            .store(in: &cancellables)

        // Subscribe to life events for context
        LifeMonitoringCoordinator.shared.eventStream
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                Task { @MainActor in
                    self?.updateContext(with: event)
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Lifecycle

    /// Starts the background prediction loop.
    ///
    /// The engine runs a prediction cycle at the interval defined in
    /// ``configuration``. Call ``stop()`` to cancel.
    public func start() {
        logger.info("Starting predictive engine")

        predictionTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(configuration.predictionInterval))
                guard !Task.isCancelled else { break }
                await runPredictionCycle()
            }
        }
    }

    /// Stops the background prediction loop and persists state.
    public func stop() {
        logger.info("Stopping predictive engine")
        predictionTask?.cancel()
        saveState()
    }

    // MARK: - Context Management

    /// Adds a life event to the sliding context window.
    ///
    /// - Parameter event: The life event to incorporate.
    func updateContext(with event: LifeEvent) {
        let snapshot = LifeContextSnapshot(
            timestamp: event.timestamp,
            eventType: event.type.rawValue,
            dataSource: event.source.rawValue,
            summary: event.summary,
            significance: event.significance.rawValue
        )

        contextWindow.append(snapshot)

        // Keep context window bounded
        if contextWindow.count > configuration.maxContextWindow {
            contextWindow.removeFirst()
        }

        // Check for immediate predictions needed
        checkImmediatePredictions(for: event)
    }

    /// Dispatches immediate prediction checks based on event type.
    ///
    /// Certain event types (app switches, input activity, calendar,
    /// messages) warrant real-time prediction generation rather than
    /// waiting for the next scheduled cycle.
    ///
    /// - Parameter event: The triggering life event.
    private func checkImmediatePredictions(for event: LifeEvent) {
        switch event.type {
        case .appSwitch:
            predictContextSwitchImpact()

        case .inputActivity:
            predictFatigueOnset()

        case .calendarEventCreated, .eventStart:
            predictSchedulingConflicts()

        case .messageReceived, .emailReceived:
            predictCommunicationNeed(for: event)

        default:
            break
        }
    }
}
