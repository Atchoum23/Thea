// OnboardingTypesTests.swift
// Tests for Onboarding types (OnboardingManagerTypes.swift).
// All test doubles are local mirrors — no real types imported.
// Language and help tests are in LocalizationAndHelpTypesTests.swift.

import Foundation
import XCTest

final class OnboardingTypesTests: XCTestCase {

    // MARK: - Test Doubles: Onboarding Types

    enum StepType: String, CaseIterable, Sendable {
        case welcome
        case selection
        case permissions
        case feature
        case tutorial
        case completion
        case custom
    }

    struct OnboardingOption: Identifiable, Sendable {
        let id: String
        let title: String
        let description: String
        let icon: String
    }

    enum PermissionType: String, CaseIterable, Sendable {
        case notifications
        case microphone
        case speechRecognition
        case camera
        case location
        case contacts
        case calendar
        case healthKit
    }

    struct PermissionRequest: Sendable {
        let id: UUID
        let type: PermissionType
        let title: String
        let description: String

        init(type: PermissionType, title: String, description: String) {
            self.id = UUID()
            self.type = type
            self.title = title
            self.description = description
        }
    }

    struct FeatureHighlight: Identifiable, Sendable {
        let id: String
        let title: String
        let description: String
        let icon: String
    }

    struct TutorialItem: Sendable {
        let id: UUID
        let title: String
        let shortcut: String
        let description: String

        init(title: String, shortcut: String, description: String) {
            self.id = UUID()
            self.title = title
            self.shortcut = shortcut
            self.description = description
        }
    }

    struct OnboardingStep: Identifiable, Sendable {
        let id: String
        let type: StepType
        let title: String
        let subtitle: String?
        let description: String?
        let image: String?
        let primaryAction: String
        let secondaryAction: String?
        let canSkip: Bool
        var options: [OnboardingOption]?
        var permissions: [PermissionRequest]?
        var features: [FeatureHighlight]?
        var tutorials: [TutorialItem]?
    }

    struct OnboardingFlow: Identifiable, Sendable {
        let id: String
        let name: String
        let steps: [OnboardingStep]
    }

    // MARK: - Test Double: Onboarding Progress Tracker

    final class OnboardingProgressTracker {
        private(set) var currentStepIndex: Int = 0
        private(set) var isCompleted: Bool = false
        private(set) var skippedSteps: Set<String> = []
        let flow: OnboardingFlow

        var currentStep: OnboardingStep? {
            guard currentStepIndex < flow.steps.count else { return nil }
            return flow.steps[currentStepIndex]
        }

        var progress: Double {
            guard !flow.steps.isEmpty else { return 0 }
            return Double(currentStepIndex) / Double(flow.steps.count)
        }

        var completionProgress: Double {
            guard !flow.steps.isEmpty else { return 0 }
            if isCompleted { return 1.0 }
            return Double(currentStepIndex) / Double(flow.steps.count)
        }

        init(flow: OnboardingFlow) {
            self.flow = flow
        }

        func nextStep() {
            guard currentStepIndex < flow.steps.count - 1 else {
                isCompleted = true
                return
            }
            currentStepIndex += 1
            if currentStepIndex >= flow.steps.count - 1,
               flow.steps[currentStepIndex].type == .completion {
                isCompleted = true
            }
        }

        func skipStep() {
            guard currentStepIndex < flow.steps.count else { return }
            let step = flow.steps[currentStepIndex]
            guard step.canSkip else { return }
            skippedSteps.insert(step.id)
            nextStep()
        }

        func reset() {
            currentStepIndex = 0
            isCompleted = false
            skippedSteps = []
        }
    }

    // MARK: - Shared Fixtures

    static let defaultFlow = OnboardingFlow(
        id: "default",
        name: "Welcome to Thea",
        steps: [
            OnboardingStep(id: "welcome", type: .welcome, title: "Welcome to Thea",
                           subtitle: "Your AI-powered assistant",
                           description: "Thea helps you accomplish tasks.",
                           image: "sparkles", primaryAction: "Get Started",
                           secondaryAction: nil, canSkip: false),
            OnboardingStep(id: "ai-provider", type: .selection, title: "Choose Your AI",
                           subtitle: "Select your preferred AI provider",
                           description: "Thea works with multiple AI providers.",
                           image: "brain", primaryAction: "Continue",
                           secondaryAction: "Use Default", canSkip: true,
                           options: [
                               OnboardingOption(id: "anthropic", title: "Anthropic Claude",
                                                description: "Advanced reasoning", icon: "brain.head.profile"),
                               OnboardingOption(id: "openai", title: "OpenAI GPT-4",
                                                description: "Versatile and capable", icon: "cpu"),
                               OnboardingOption(id: "local", title: "Local Models",
                                                description: "Privacy-focused", icon: "desktopcomputer")
                           ]),
            OnboardingStep(id: "permissions", type: .permissions, title: "Enable Features",
                           subtitle: "Grant permissions",
                           description: "Thea needs a few permissions.",
                           image: "lock.shield", primaryAction: "Enable",
                           secondaryAction: "Skip for Now", canSkip: true,
                           permissions: [
                               PermissionRequest(type: .notifications, title: "Notifications",
                                                 description: "Get notified when AI responses are ready"),
                               PermissionRequest(type: .microphone, title: "Microphone",
                                                 description: "Use voice commands"),
                               PermissionRequest(type: .speechRecognition, title: "Speech Recognition",
                                                 description: "Transcribe your voice")
                           ]),
            OnboardingStep(id: "features", type: .feature, title: "Powerful Features",
                           subtitle: "Discover what Thea can do", description: nil,
                           image: nil, primaryAction: "Continue",
                           secondaryAction: nil, canSkip: true,
                           features: [
                               FeatureHighlight(id: "conversations", title: "Smart Conversations",
                                                description: "Chat naturally", icon: "bubble.left.and.bubble.right"),
                               FeatureHighlight(id: "agents", title: "Custom Agents",
                                                description: "Create specialized assistants", icon: "person.2"),
                               FeatureHighlight(id: "tools", title: "MCP Tools",
                                                description: "Connect to services", icon: "wrench.and.screwdriver")
                           ]),
            OnboardingStep(id: "shortcuts", type: .tutorial, title: "Quick Actions",
                           subtitle: "Keyboard shortcuts",
                           description: "Use these shortcuts to work faster.",
                           image: "keyboard", primaryAction: "Got It",
                           secondaryAction: "Show Me Later", canSkip: true,
                           tutorials: [
                               TutorialItem(title: "New Conversation", shortcut: "\u{2318}N",
                                            description: "Start a new chat"),
                               TutorialItem(title: "Quick Ask", shortcut: "\u{2318}\u{21E7}Space",
                                            description: "Open quick ask overlay")
                           ]),
            OnboardingStep(id: "complete", type: .completion, title: "You're All Set!",
                           subtitle: "Start your AI journey",
                           description: "Thea is ready to help you.",
                           image: "checkmark.circle", primaryAction: "Start Using Thea",
                           secondaryAction: nil, canSkip: false)
        ]
    )

    static let quickStartFlow = OnboardingFlow(
        id: "quick-start",
        name: "Quick Start",
        steps: [
            OnboardingStep(id: "quick-welcome", type: .welcome, title: "Welcome Back",
                           subtitle: "Let's get you set up quickly",
                           description: "We'll guide you through the essentials.",
                           image: "hare", primaryAction: "Let's Go",
                           secondaryAction: nil, canSkip: false),
            OnboardingStep(id: "quick-complete", type: .completion, title: "Ready!",
                           subtitle: "You're good to go",
                           description: "Start chatting right away.",
                           image: "checkmark.circle", primaryAction: "Start",
                           secondaryAction: nil, canSkip: false)
        ]
    )

    // MARK: - StepType Enum Tests

    func testStepTypeAllCases() {
        let allCases = StepType.allCases
        XCTAssertEqual(allCases.count, 7)
    }

    func testStepTypeRawValues() {
        XCTAssertEqual(StepType.welcome.rawValue, "welcome")
        XCTAssertEqual(StepType.selection.rawValue, "selection")
        XCTAssertEqual(StepType.permissions.rawValue, "permissions")
        XCTAssertEqual(StepType.feature.rawValue, "feature")
        XCTAssertEqual(StepType.tutorial.rawValue, "tutorial")
        XCTAssertEqual(StepType.completion.rawValue, "completion")
        XCTAssertEqual(StepType.custom.rawValue, "custom")
    }

    func testStepTypeEquality() {
        XCTAssertEqual(StepType.welcome, StepType.welcome)
        XCTAssertNotEqual(StepType.welcome, StepType.completion)
    }

    // MARK: - PermissionType Enum Tests

    func testPermissionTypeAllCases() {
        let allCases = PermissionType.allCases
        XCTAssertEqual(allCases.count, 8)
    }

    func testPermissionTypeRawValues() {
        XCTAssertEqual(PermissionType.notifications.rawValue, "notifications")
        XCTAssertEqual(PermissionType.microphone.rawValue, "microphone")
        XCTAssertEqual(PermissionType.speechRecognition.rawValue, "speechRecognition")
        XCTAssertEqual(PermissionType.camera.rawValue, "camera")
        XCTAssertEqual(PermissionType.location.rawValue, "location")
        XCTAssertEqual(PermissionType.contacts.rawValue, "contacts")
        XCTAssertEqual(PermissionType.calendar.rawValue, "calendar")
        XCTAssertEqual(PermissionType.healthKit.rawValue, "healthKit")
    }

    // MARK: - OnboardingStep Tests

    func testOnboardingStepIdentifiable() {
        let step = Self.defaultFlow.steps[0]
        XCTAssertEqual(step.id, "welcome")
    }

    func testOnboardingStepProperties() {
        let step = Self.defaultFlow.steps[0]
        XCTAssertEqual(step.type, .welcome)
        XCTAssertEqual(step.title, "Welcome to Thea")
        XCTAssertEqual(step.subtitle, "Your AI-powered assistant")
        XCTAssertNotNil(step.description)
        XCTAssertEqual(step.image, "sparkles")
        XCTAssertEqual(step.primaryAction, "Get Started")
        XCTAssertNil(step.secondaryAction)
        XCTAssertFalse(step.canSkip)
    }

    func testSelectionStepHasOptions() {
        let step = Self.defaultFlow.steps[1]
        XCTAssertEqual(step.type, .selection)
        XCTAssertNotNil(step.options)
        XCTAssertEqual(step.options?.count, 3)
        XCTAssertEqual(step.options?.first?.id, "anthropic")
    }

    func testPermissionsStepHasPermissions() {
        let step = Self.defaultFlow.steps[2]
        XCTAssertEqual(step.type, .permissions)
        XCTAssertNotNil(step.permissions)
        XCTAssertEqual(step.permissions?.count, 3)
        XCTAssertEqual(step.permissions?.first?.type, .notifications)
    }

    func testFeatureStepHasFeatures() {
        let step = Self.defaultFlow.steps[3]
        XCTAssertEqual(step.type, .feature)
        XCTAssertNotNil(step.features)
        XCTAssertEqual(step.features?.count, 3)
        XCTAssertEqual(step.features?.first?.id, "conversations")
    }

    func testTutorialStepHasTutorials() {
        let step = Self.defaultFlow.steps[4]
        XCTAssertEqual(step.type, .tutorial)
        XCTAssertNotNil(step.tutorials)
        XCTAssertEqual(step.tutorials?.count, 2)
        XCTAssertEqual(step.tutorials?.first?.shortcut, "\u{2318}N")
    }

    func testCompletionStepIsNotSkippable() {
        let step = Self.defaultFlow.steps[5]
        XCTAssertEqual(step.type, .completion)
        XCTAssertFalse(step.canSkip)
    }

    // MARK: - OnboardingFlow Tests

    func testDefaultFlowHas6Steps() {
        XCTAssertEqual(Self.defaultFlow.steps.count, 6)
        XCTAssertEqual(Self.defaultFlow.id, "default")
        XCTAssertEqual(Self.defaultFlow.name, "Welcome to Thea")
    }

    func testQuickStartFlowHas2Steps() {
        XCTAssertEqual(Self.quickStartFlow.steps.count, 2)
        XCTAssertEqual(Self.quickStartFlow.id, "quick-start")
        XCTAssertEqual(Self.quickStartFlow.name, "Quick Start")
    }

    func testDefaultFlowStepOrder() {
        let types = Self.defaultFlow.steps.map(\.type)
        XCTAssertEqual(types, [.welcome, .selection, .permissions, .feature, .tutorial, .completion])
    }

    func testQuickStartFlowStepOrder() {
        let types = Self.quickStartFlow.steps.map(\.type)
        XCTAssertEqual(types, [.welcome, .completion])
    }

    func testAllStepIdsUniqueInDefaultFlow() {
        let ids = Self.defaultFlow.steps.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count, "Duplicate step IDs in default flow")
    }

    // MARK: - OnboardingProgress Tracker Tests

    func testProgressStartsAtZero() {
        let tracker = OnboardingProgressTracker(flow: Self.defaultFlow)
        XCTAssertEqual(tracker.currentStepIndex, 0)
        XCTAssertEqual(tracker.progress, 0.0)
        XCTAssertFalse(tracker.isCompleted)
    }

    func testProgressAdvancesOnNextStep() {
        let tracker = OnboardingProgressTracker(flow: Self.defaultFlow)
        tracker.nextStep()
        XCTAssertEqual(tracker.currentStepIndex, 1)
        let expected = 1.0 / 6.0
        XCTAssertEqual(tracker.progress, expected, accuracy: 0.001)
    }

    func testProgressCompletesAtLastStep() {
        let tracker = OnboardingProgressTracker(flow: Self.defaultFlow)
        for _ in 0..<5 {
            tracker.nextStep()
        }
        XCTAssertTrue(tracker.isCompleted)
    }

    func testCurrentStepReturnsCorrectStep() {
        let tracker = OnboardingProgressTracker(flow: Self.defaultFlow)
        XCTAssertEqual(tracker.currentStep?.id, "welcome")
        tracker.nextStep()
        XCTAssertEqual(tracker.currentStep?.id, "ai-provider")
    }

    func testSkipStepRecordsSkippedId() {
        let tracker = OnboardingProgressTracker(flow: Self.defaultFlow)
        tracker.nextStep() // move to ai-provider (canSkip = true)
        tracker.skipStep()
        XCTAssertTrue(tracker.skippedSteps.contains("ai-provider"))
        XCTAssertEqual(tracker.currentStepIndex, 2)
    }

    func testCannotSkipNonSkippableStep() {
        let tracker = OnboardingProgressTracker(flow: Self.defaultFlow)
        // welcome step has canSkip = false
        tracker.skipStep()
        XCTAssertEqual(tracker.currentStepIndex, 0, "Should not advance past non-skippable step")
        XCTAssertTrue(tracker.skippedSteps.isEmpty)
    }

    func testResetClearsAllProgress() {
        let tracker = OnboardingProgressTracker(flow: Self.defaultFlow)
        tracker.nextStep()
        tracker.nextStep()
        tracker.reset()
        XCTAssertEqual(tracker.currentStepIndex, 0)
        XCTAssertFalse(tracker.isCompleted)
        XCTAssertTrue(tracker.skippedSteps.isEmpty)
    }

    func testQuickStartFlowCompletesQuickly() {
        let tracker = OnboardingProgressTracker(flow: Self.quickStartFlow)
        XCTAssertEqual(tracker.currentStep?.type, .welcome)
        tracker.nextStep()
        XCTAssertTrue(tracker.isCompleted)
    }
}
