// OnboardingManager.swift
// Comprehensive onboarding and first-time user experience

import Foundation
import OSLog
import Combine
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
        self.flow = OnboardingFlow.default
        loadState()
        checkOnboardingStatus()
    }

    private func loadState() {
        isOnboardingComplete = UserDefaults.standard.bool(forKey: "onboarding.complete")

        if let completedData = UserDefaults.standard.data(forKey: "onboarding.completedSteps"),
           let completed = try? JSONDecoder().decode(Set<String>.self, from: completedData) {
            completedSteps = completed
        }

        if let skippedData = UserDefaults.standard.data(forKey: "onboarding.skippedSteps"),
           let skipped = try? JSONDecoder().decode(Set<String>.self, from: skippedData) {
            skippedSteps = skipped
        }

        if let discoveredData = UserDefaults.standard.data(forKey: "onboarding.discoveredFeatures"),
           let discovered = try? JSONDecoder().decode(Set<String>.self, from: discoveredData) {
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
              let currentIndex = flow.steps.firstIndex(where: { $0.id == current.id }) else {
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
              currentIndex > 0 else {
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

// MARK: - Onboarding Flow

public struct OnboardingFlow: Identifiable {
    public let id: String
    public let name: String
    public let steps: [OnboardingStep]

    public static let `default` = OnboardingFlow(
        id: "default",
        name: "Welcome to Thea",
        steps: [
            OnboardingStep(
                id: "welcome",
                type: .welcome,
                title: "Welcome to Thea",
                subtitle: "Your AI-powered assistant",
                description: "Thea helps you accomplish tasks, answer questions, and boost your productivity with the power of AI.",
                image: "sparkles",
                primaryAction: "Get Started",
                secondaryAction: nil,
                canSkip: false
            ),
            OnboardingStep(
                id: "ai-provider",
                type: .selection,
                title: "Choose Your AI",
                subtitle: "Select your preferred AI provider",
                description: "Thea works with multiple AI providers. Choose the one you prefer, or use the default.",
                image: "brain",
                primaryAction: "Continue",
                secondaryAction: "Use Default",
                canSkip: true,
                options: [
                    OnboardingOption(id: "anthropic", title: "Anthropic Claude", description: "Advanced reasoning and analysis", icon: "brain.head.profile"),
                    OnboardingOption(id: "openai", title: "OpenAI GPT-4", description: "Versatile and capable", icon: "cpu"),
                    OnboardingOption(id: "local", title: "Local Models", description: "Privacy-focused, runs on device", icon: "desktopcomputer")
                ]
            ),
            OnboardingStep(
                id: "permissions",
                type: .permissions,
                title: "Enable Features",
                subtitle: "Grant permissions for the best experience",
                description: "Thea needs a few permissions to provide you with the full experience.",
                image: "lock.shield",
                primaryAction: "Enable",
                secondaryAction: "Skip for Now",
                canSkip: true,
                permissions: [
                    PermissionRequest(type: .notifications, title: "Notifications", description: "Get notified when AI responses are ready"),
                    PermissionRequest(type: .microphone, title: "Microphone", description: "Use voice commands and dictation"),
                    PermissionRequest(type: .speechRecognition, title: "Speech Recognition", description: "Transcribe your voice to text")
                ]
            ),
            OnboardingStep(
                id: "features",
                type: .feature,
                title: "Powerful Features",
                subtitle: "Discover what Thea can do",
                description: nil,
                image: nil,
                primaryAction: "Continue",
                secondaryAction: nil,
                canSkip: true,
                features: [
                    FeatureHighlight(id: "conversations", title: "Smart Conversations", description: "Chat naturally with context-aware AI", icon: "bubble.left.and.bubble.right"),
                    FeatureHighlight(id: "agents", title: "Custom Agents", description: "Create specialized AI assistants", icon: "person.2"),
                    FeatureHighlight(id: "tools", title: "MCP Tools", description: "Connect to external services", icon: "wrench.and.screwdriver"),
                    FeatureHighlight(id: "memory", title: "Long-term Memory", description: "AI that remembers your preferences", icon: "brain"),
                    FeatureHighlight(id: "artifacts", title: "Code Artifacts", description: "Generate and manage code snippets", icon: "doc.text"),
                    FeatureHighlight(id: "sync", title: "Cross-Device Sync", description: "Access your data everywhere", icon: "icloud")
                ]
            ),
            OnboardingStep(
                id: "shortcuts",
                type: .tutorial,
                title: "Quick Actions",
                subtitle: "Learn the keyboard shortcuts",
                description: "Use these shortcuts to work faster with Thea.",
                image: "keyboard",
                primaryAction: "Got It",
                secondaryAction: "Show Me Later",
                canSkip: true,
                tutorials: [
                    TutorialItem(title: "New Conversation", shortcut: "⌘N", description: "Start a new chat"),
                    TutorialItem(title: "Quick Ask", shortcut: "⌘⇧Space", description: "Open quick ask overlay"),
                    TutorialItem(title: "Voice Mode", shortcut: "⌘⇧V", description: "Toggle voice input"),
                    TutorialItem(title: "Search", shortcut: "⌘F", description: "Search conversations")
                ]
            ),
            OnboardingStep(
                id: "complete",
                type: .completion,
                title: "You're All Set!",
                subtitle: "Start your AI journey",
                description: "Thea is ready to help you. Start a conversation or explore the features.",
                image: "checkmark.circle",
                primaryAction: "Start Using Thea",
                secondaryAction: nil,
                canSkip: false
            )
        ]
    )

    public static let quickStart = OnboardingFlow(
        id: "quick-start",
        name: "Quick Start",
        steps: [
            OnboardingStep(
                id: "quick-welcome",
                type: .welcome,
                title: "Welcome Back",
                subtitle: "Let's get you set up quickly",
                description: "We'll guide you through the essentials.",
                image: "hare",
                primaryAction: "Let's Go",
                secondaryAction: nil,
                canSkip: false
            ),
            OnboardingStep(
                id: "quick-complete",
                type: .completion,
                title: "Ready!",
                subtitle: "You're good to go",
                description: "Start chatting with Thea right away.",
                image: "checkmark.circle",
                primaryAction: "Start",
                secondaryAction: nil,
                canSkip: false
            )
        ]
    )
}

// MARK: - Onboarding Step

public struct OnboardingStep: Identifiable {
    public let id: String
    public let type: StepType
    public let title: String
    public let subtitle: String?
    public let description: String?
    public let image: String?
    public let primaryAction: String
    public let secondaryAction: String?
    public let canSkip: Bool
    public var options: [OnboardingOption]?
    public var permissions: [PermissionRequest]?
    public var features: [FeatureHighlight]?
    public var tutorials: [TutorialItem]?

    public enum StepType {
        case welcome
        case selection
        case permissions
        case feature
        case tutorial
        case completion
        case custom
    }
}

public struct OnboardingOption: Identifiable {
    public let id: String
    public let title: String
    public let description: String
    public let icon: String
}

public struct PermissionRequest: Identifiable {
    public let id = UUID()
    public let type: PermissionType
    public let title: String
    public let description: String

    public enum PermissionType {
        case notifications
        case microphone
        case speechRecognition
        case camera
        case location
        case contacts
        case calendar
        case healthKit
    }
}

public struct FeatureHighlight: Identifiable {
    public let id: String
    public let title: String
    public let description: String
    public let icon: String
}

public struct TutorialItem: Identifiable {
    public let id = UUID()
    public let title: String
    public let shortcut: String
    public let description: String
}

// MARK: - Feature Tips

public struct FeatureTip: Identifiable {
    public let id: String
    public let featureId: String
    public let title: String
    public let message: String
    public let icon: String
    public let action: String?
    public let prerequisites: Set<String>

    public static let allTips: [FeatureTip] = [
        FeatureTip(
            id: "tip-agents",
            featureId: "agents",
            title: "Create Custom Agents",
            message: "Did you know you can create specialized AI agents for specific tasks?",
            icon: "person.badge.plus",
            action: "Create Agent",
            prerequisites: ["conversations"]
        ),
        FeatureTip(
            id: "tip-memory",
            featureId: "memory",
            title: "AI Memory",
            message: "Thea can remember important information across conversations. Try saying 'Remember that...'",
            icon: "brain",
            action: "Learn More",
            prerequisites: ["conversations"]
        ),
        FeatureTip(
            id: "tip-voice",
            featureId: "voice",
            title: "Voice Mode",
            message: "Press ⌘⇧V to talk to Thea using your voice!",
            icon: "mic",
            action: nil,
            prerequisites: []
        ),
        FeatureTip(
            id: "tip-artifacts",
            featureId: "artifacts",
            title: "Code Artifacts",
            message: "Ask Thea to generate code and it will be saved as an artifact you can edit and run.",
            icon: "doc.text",
            action: "Try It",
            prerequisites: ["conversations"]
        )
    ]
}

// MARK: - Contextual Help

public struct ContextualHelp: Identifiable {
    public let id: String
    public let screenId: String
    public let title: String
    public let items: [HelpItem]

    public struct HelpItem: Identifiable {
        public let id = UUID()
        public let question: String
        public let answer: String
    }

    public static let allHelp: [ContextualHelp] = [
        ContextualHelp(
            id: "help-conversations",
            screenId: "conversations",
            title: "Conversations Help",
            items: [
                HelpItem(question: "How do I start a new conversation?", answer: "Click the + button or press ⌘N to start a new conversation."),
                HelpItem(question: "Can I rename a conversation?", answer: "Yes! Right-click on a conversation and select 'Rename'."),
                HelpItem(question: "How do I delete a conversation?", answer: "Swipe left on a conversation or right-click and select 'Delete'.")
            ]
        ),
        ContextualHelp(
            id: "help-agents",
            screenId: "agents",
            title: "Agents Help",
            items: [
                HelpItem(question: "What are agents?", answer: "Agents are specialized AI assistants you can customize for specific tasks."),
                HelpItem(question: "How do I create an agent?", answer: "Click 'Create Agent' and define its name, personality, and capabilities."),
                HelpItem(question: "Can agents use tools?", answer: "Yes! You can enable MCP tools for agents to interact with external services.")
            ]
        )
    ]
}

// MARK: - Notifications

public extension Notification.Name {
    static let onboardingCompleted = Notification.Name("thea.onboarding.completed")
}

// MARK: - SwiftUI Views

public struct OnboardingView: View {
    @ObservedObject var manager = OnboardingManager.shared

    public init() {}

    public var body: some View {
        if let step = manager.currentStep {
            OnboardingStepView(step: step)
        }
    }
}

public struct OnboardingStepView: View {
    let step: OnboardingStep
    @ObservedObject var manager = OnboardingManager.shared

    public var body: some View {
        VStack(spacing: 24) {
            // Progress indicator
            ProgressView(value: manager.progress)
                .padding(.horizontal)

            Spacer()

            // Image
            if let imageName = step.image {
                Image(systemName: imageName)
                    .font(.system(size: 80))
                    .foregroundStyle(.tint)
            }

            // Title
            Text(step.title)
                .font(.largeTitle)
                .fontWeight(.bold)

            // Subtitle
            if let subtitle = step.subtitle {
                Text(subtitle)
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }

            // Description
            if let description = step.description {
                Text(description)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            // Step-specific content
            stepContent

            Spacer()

            // Actions
            VStack(spacing: 12) {
                Button(action: { manager.nextStep() }) {
                    Text(step.primaryAction)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                if let secondary = step.secondaryAction {
                    Button(action: { manager.skipStep() }) {
                        Text(secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .padding()
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step.type {
        case .feature:
            if let features = step.features {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 16) {
                    ForEach(features) { feature in
                        VStack {
                            Image(systemName: feature.icon)
                                .font(.title)
                            Text(feature.title)
                                .font(.headline)
                            Text(feature.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding()
            }

        case .tutorial:
            if let tutorials = step.tutorials {
                VStack(spacing: 12) {
                    ForEach(tutorials) { tutorial in
                        HStack {
                            Text(tutorial.shortcut)
                                .font(.system(.body, design: .monospaced))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.regularMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 6))

                            VStack(alignment: .leading) {
                                Text(tutorial.title)
                                    .font(.headline)
                                Text(tutorial.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                        }
                        .padding()
                    }
                }
                .padding()
            }

        default:
            EmptyView()
        }
    }
}
