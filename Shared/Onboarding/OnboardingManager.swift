// OnboardingManager.swift
// Comprehensive onboarding and first-time user experience

import Combine
import Foundation
import OSLog
import SwiftUI

// MARK: - Onboarding Manager

/// Manages onboarding flow and progressive feature discovery
@MainActor
public final class OnboardingManager: ObservableObject {
    public static let shared = OnboardingManager()

    private let logger = Logger(subsystem: "com.thea.app", category: "Onboarding")

    // MARK: - Published State

    @Published public private(set) var isOnboardingComplete = false
    @Published public private(set) var currentStep: OnboardingStep?
    @Published public private(set) var completedSteps: Set<String> = []
    @Published public private(set) var skippedSteps: Set<String> = []
    @Published public var showOnboarding = false

    // MARK: - Flow Configuration

    @Published public private(set) var flow: OnboardingFlow
    @Published public private(set) var progress: Double = 0

    // MARK: - Feature Discovery

    @Published public private(set) var discoveredFeatures: Set<String> = []
    @Published public private(set) var pendingTips: [FeatureTip] = []

    // MARK: - Initialization

    private init() {
        flow = OnboardingFlow.default
        loadState()
        checkOnboardingStatus()
    }

    private func loadState() {
        isOnboardingComplete = UserDefaults.standard.bool(forKey: "onboarding.complete")

        if let completedData = UserDefaults.standard.data(forKey: "onboarding.completedSteps"),
           let completed = try? JSONDecoder().decode(Set<String>.self, from: completedData)
        {
            completedSteps = completed
        }

        if let skippedData = UserDefaults.standard.data(forKey: "onboarding.skippedSteps"),
           let skipped = try? JSONDecoder().decode(Set<String>.self, from: skippedData)
        {
            skippedSteps = skipped
        }

        if let discoveredData = UserDefaults.standard.data(forKey: "onboarding.discoveredFeatures"),
           let discovered = try? JSONDecoder().decode(Set<String>.self, from: discoveredData)
        {
            discoveredFeatures = discovered
        }

        updateProgress()
    }

    private func saveState() {
        UserDefaults.standard.set(isOnboardingComplete, forKey: "onboarding.complete")

        if let data = try? JSONEncoder().encode(completedSteps) {
            UserDefaults.standard.set(data, forKey: "onboarding.completedSteps")
        }

        if let data = try? JSONEncoder().encode(skippedSteps) {
            UserDefaults.standard.set(data, forKey: "onboarding.skippedSteps")
        }

        if let data = try? JSONEncoder().encode(discoveredFeatures) {
            UserDefaults.standard.set(data, forKey: "onboarding.discoveredFeatures")
        }
    }

    private func checkOnboardingStatus() {
        if !isOnboardingComplete {
            showOnboarding = true
            currentStep = flow.steps.first
        }
    }

    // MARK: - Flow Control

    /// Start onboarding
    public func startOnboarding(flow: OnboardingFlow? = nil) {
        if let customFlow = flow {
            self.flow = customFlow
        }

        showOnboarding = true
        currentStep = self.flow.steps.first
        updateProgress()

        AnalyticsManager.shared.track("onboarding_started", properties: [
            "flow_id": self.flow.id,
            "step_count": self.flow.steps.count
        ])

        logger.info("Onboarding started")
    }

    /// Move to next step
    public func nextStep() {
        guard let current = currentStep,
              let currentIndex = flow.steps.firstIndex(where: { $0.id == current.id })
        else {
            return
        }

        // Mark current as completed
        completeStep(current.id)

        // Move to next
        let nextIndex = currentIndex + 1
        if nextIndex < flow.steps.count {
            currentStep = flow.steps[nextIndex]
        } else {
            completeOnboarding()
        }

        updateProgress()
    }

    /// Go to previous step
    public func previousStep() {
        guard let current = currentStep,
              let currentIndex = flow.steps.firstIndex(where: { $0.id == current.id }),
              currentIndex > 0
        else {
            return
        }

        currentStep = flow.steps[currentIndex - 1]
        updateProgress()
    }

    /// Skip current step
    public func skipStep() {
        guard let current = currentStep else { return }

        skippedSteps.insert(current.id)
        saveState()

        AnalyticsManager.shared.track("onboarding_step_skipped", properties: [
            "step_id": current.id
        ])

        nextStep()
    }

    /// Skip entire onboarding
    public func skipOnboarding() {
        AnalyticsManager.shared.track("onboarding_skipped", properties: [
            "completed_steps": completedSteps.count,
            "total_steps": flow.steps.count
        ])

        completeOnboarding()
    }

    /// Go to specific step
    public func goToStep(_ stepId: String) {
        if let step = flow.steps.first(where: { $0.id == stepId }) {
            currentStep = step
            updateProgress()
        }
    }

    // MARK: - Step Completion

    /// Mark a step as completed
    public func completeStep(_ stepId: String) {
        completedSteps.insert(stepId)
        saveState()

        AnalyticsManager.shared.track("onboarding_step_completed", properties: [
            "step_id": stepId
        ])

        logger.debug("Completed step: \(stepId)")
    }

    /// Complete onboarding
    public func completeOnboarding() {
        isOnboardingComplete = true
        showOnboarding = false
        currentStep = nil
        saveState()

        AnalyticsManager.shared.track("onboarding_completed", properties: [
            "completed_steps": completedSteps.count,
            "skipped_steps": skippedSteps.count
        ])

        NotificationCenter.default.post(name: .onboardingCompleted, object: nil)

        logger.info("Onboarding completed")
    }

    /// Reset onboarding
    public func resetOnboarding() {
        isOnboardingComplete = false
        completedSteps.removeAll()
        skippedSteps.removeAll()
        progress = 0
        saveState()

        logger.info("Onboarding reset")
    }

    // MARK: - Progress

    private func updateProgress() {
        let totalSteps = flow.steps.count
        let completed = completedSteps.count
        progress = totalSteps > 0 ? Double(completed) / Double(totalSteps) : 0
    }

    // MARK: - Feature Discovery

    /// Discover a feature (for progressive disclosure)
    public func discoverFeature(_ featureId: String) {
        guard !discoveredFeatures.contains(featureId) else { return }

        discoveredFeatures.insert(featureId)
        saveState()

        // Check for pending tips
        if let tip = FeatureTip.allTips.first(where: { $0.featureId == featureId }) {
            if !tip.prerequisites.isSubset(of: discoveredFeatures) {
                pendingTips.append(tip)
            }
        }

        AnalyticsManager.shared.trackFeatureUsage(featureId)

        logger.debug("Discovered feature: \(featureId)")
    }

    /// Check if a feature has been discovered
    public func hasDiscoveredFeature(_ featureId: String) -> Bool {
        discoveredFeatures.contains(featureId)
    }

    /// Get next feature tip
    public func getNextTip() -> FeatureTip? {
        pendingTips.first { tip in
            tip.prerequisites.isSubset(of: discoveredFeatures) &&
                !discoveredFeatures.contains(tip.featureId)
        }
    }

    /// Dismiss a tip
    public func dismissTip(_ tip: FeatureTip) {
        pendingTips.removeAll { $0.id == tip.id }
        discoverFeature(tip.featureId) // Mark as discovered to not show again
    }

    // MARK: - Contextual Help

    /// Get contextual help for current screen
    public func getContextualHelp(for screen: String) -> ContextualHelp? {
        ContextualHelp.allHelp.first { $0.screenId == screen }
    }

    /// Track help viewed
    public func helpViewed(for screen: String) {
        AnalyticsManager.shared.track("help_viewed", properties: [
            "screen": screen
        ])
    }
}

// Types, flows, views, and helpers are in OnboardingManagerTypes.swift
