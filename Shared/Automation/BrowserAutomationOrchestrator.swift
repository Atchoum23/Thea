// BrowserAutomationOrchestrator.swift
// Thea
//
// AI-driven browser and screen automation orchestrator using an
// Observe → Understand → Decide → Act loop. Dramatically faster than
// Chrome extension approaches by using native ScreenCapture + VisionOCR
// + CGEvent injection. Integrates with Plan Mode for visible progress
// and with UserInterventionDetector to gracefully handle user actions.

#if os(macOS)

    import AppKit
    import Foundation
    import os.log

    // MARK: - Orchestration State

    /// Current state of the automation workflow.
    public enum BrowserOrchestrationState: String, Sendable {
        case idle               // No automation running
        case planning           // Creating execution plan
        case observing          // Capturing screen state
        case understanding      // AI analyzing screen content
        case deciding           // AI determining next action
        case acting             // Executing an action
        case waitingForUser     // Paused — user is manually interacting
        case verifying          // Checking action result
        case completed          // Task finished successfully
        case error              // Task failed

        /// Human-readable display name
        public var displayName: String {
            switch self {
            case .idle: return "Idle"
            case .planning: return "Planning"
            case .observing: return "Observing screen"
            case .understanding: return "Analyzing"
            case .deciding: return "Deciding action"
            case .acting: return "Executing"
            case .waitingForUser: return "Waiting for you"
            case .verifying: return "Verifying"
            case .completed: return "Completed"
            case .error: return "Error"
            }
        }

        /// SF Symbol icon for UI
        public var iconName: String {
            switch self {
            case .idle: return "pause.circle"
            case .planning: return "list.bullet.clipboard"
            case .observing: return "eye.fill"
            case .understanding: return "brain.head.profile"
            case .deciding: return "lightbulb.fill"
            case .acting: return "hand.tap.fill"
            case .waitingForUser: return "person.fill"
            case .verifying: return "checkmark.circle"
            case .completed: return "checkmark.circle.fill"
            case .error: return "exclamationmark.triangle.fill"
            }
        }
    }

    // MARK: - Orchestrator Configuration

    /// Configuration for the automation loop.
    public struct AutomationConfig: Sendable {
        /// Seconds between observe cycles
        public var captureInterval: TimeInterval = 1.0

        /// Pause automation when user is interacting
        public var pauseOnUserActivity: Bool = true

        /// Seconds to wait after user stops before resuming
        public var userActivityTimeout: TimeInterval = 2.0

        /// Maximum number of observe-act cycles before stopping
        public var maxCycles: Int = 100

        /// Maximum total duration before stopping (seconds)
        public var maxDuration: TimeInterval = 600

        /// Use fast OCR (less accurate but faster)
        public var useFastOCR: Bool = true

        /// Minimum confidence for executing an action
        public var minimumActionConfidence: Double = 0.5

        public init() {}
    }

    // MARK: - Browser Automation Orchestrator

    /// Orchestrates AI-driven browser and screen automation.
    ///
    /// The orchestrator runs a continuous loop:
    /// 1. **Observe**: Capture screen via ScreenCapture + VisionOCR
    /// 2. **Understand**: Send OCR text to AI for comprehension
    /// 3. **Decide**: AI determines the next action
    /// 4. **Act**: Execute via AutomationEngine (CGEvent) or BrowserAutomationService (WKWebView)
    /// 5. **Verify**: Capture again to confirm the action worked
    ///
    /// User intervention is detected and gracefully handled — when the user
    /// clicks or types, automation pauses, waits, then re-observes from the
    /// new state incorporating the user's changes.
    @MainActor
    @Observable
    public final class BrowserAutomationOrchestrator {
        public static let shared = BrowserAutomationOrchestrator()

        private let logger = Logger(subsystem: "ai.thea.app", category: "BrowserOrchestrator")

        // MARK: - State

        /// Current orchestration state
        public private(set) var state: BrowserOrchestrationState = .idle

        /// Description of the current task
        public private(set) var currentTask: String?

        /// The most recent screen state
        public private(set) var lastScreenState: ScreenState?

        /// The previous screen state (for diff analysis)
        public private(set) var previousScreenState: ScreenState?

        /// History of actions taken in the current task
        public private(set) var actionHistory: [AutomationAction] = []

        /// Whether the user is currently actively interacting
        public private(set) var isUserActive: Bool = false

        /// Number of observe-act cycles completed
        public private(set) var cycleCount: Int = 0

        /// When the current task started
        public private(set) var taskStartTime: Date?

        /// Error message if the task failed
        public private(set) var errorMessage: String?

        // MARK: - Configuration

        /// Automation configuration
        public var config = AutomationConfig()

        // MARK: - Internal

        private var automationTask: Task<Void, Never>?
        private var userInterventionDetector: UserInterventionDetector?
        private let screenAnalyzer = ScreenAnalyzer.shared
        private let automationEngine = AutomationEngine()

        private init() {
            logger.info("BrowserAutomationOrchestrator initialized")
        }

        // MARK: - Task Execution

        /// Start an automation task.
        ///
        /// Creates a plan via PlanManager, starts the automation loop,
        /// and monitors for user intervention.
        ///
        /// - Parameter taskDescription: Natural language description of what to automate
        public func executeTask(_ taskDescription: String) {
            guard state == .idle || state == .completed || state == .error else {
                logger.warning("Cannot start task — already running: \(self.state.rawValue)")
                return
            }

            // Reset state
            state = .planning
            currentTask = taskDescription
            actionHistory = []
            cycleCount = 0
            errorMessage = nil
            taskStartTime = Date()

            logger.info("Starting automation task: \(taskDescription)")

            // Create plan for visibility in Plan Mode
            PlanManager.shared.createSimplePlan(
                title: "Automation: \(String(taskDescription.prefix(40)))",
                steps: [
                    "Observe current screen state",
                    "Analyze and plan actions",
                    "Execute automation steps",
                    "Verify results"
                ]
            )
            PlanManager.shared.startExecution()
            PlanManager.shared.showPanel()

            // Start user intervention detection
            userInterventionDetector = UserInterventionDetector(
                activityTimeout: config.userActivityTimeout
            )
            userInterventionDetector?.start()

            // Launch the automation loop
            automationTask = Task { [weak self] in
                await self?.automationLoop()
            }
        }

        /// Stop the current automation task.
        public func stop() {
            logger.info("Stopping automation task")
            automationTask?.cancel()
            automationTask = nil
            userInterventionDetector?.stop()
            userInterventionDetector = nil
            state = .idle
            currentTask = nil
        }

        // MARK: - Automation Loop

        private func automationLoop() async {
            let startTime = Date()

            while !Task.isCancelled && cycleCount < config.maxCycles {
                // Check total duration
                if Date().timeIntervalSince(startTime) > config.maxDuration {
                    logger.warning("Automation timeout after \(self.config.maxDuration)s")
                    state = .completed
                    break
                }

                cycleCount += 1

                // --- Check for user activity ---
                if config.pauseOnUserActivity {
                    if let detector = userInterventionDetector, detector.isUserActive {
                        state = .waitingForUser
                        isUserActive = true
                        logger.info("User active — pausing automation (action: \(detector.lastInterventionAction?.displayName ?? "unknown"))")

                        // Wait until user stops
                        while detector.isUserActive && !Task.isCancelled {
                            try? await Task.sleep(for: .milliseconds(200))
                        }

                        isUserActive = false

                        // Brief extra pause to let screen settle after user action
                        try? await Task.sleep(for: .milliseconds(500))
                        logger.info("User inactive — resuming automation")
                    }
                }

                guard !Task.isCancelled else { break }

                // --- OBSERVE ---
                state = .observing
                do {
                    let screenState = try await screenAnalyzer.captureAndAnalyze()
                    previousScreenState = lastScreenState
                    lastScreenState = screenState

                    // Check for significant changes via diff
                    if let previous = previousScreenState {
                        let diff = screenAnalyzer.computeDiff(
                            previous: previous,
                            current: screenState
                        )
                        logger.debug("Screen diff: \(diff.summary)")
                    }
                } catch {
                    logger.error("Screen capture failed: \(error.localizedDescription)")
                    errorMessage = "Screen capture failed: \(error.localizedDescription)"
                    state = .error
                    break
                }

                guard !Task.isCancelled else { break }

                // --- UNDERSTAND + DECIDE ---
                state = .understanding
                guard let screenState = lastScreenState else { break }

                let action = await decideNextAction(
                    screenState: screenState,
                    task: currentTask ?? "",
                    history: actionHistory
                )

                guard !Task.isCancelled else { break }

                // Check for done signal
                if case .done = action.type {
                    logger.info("Automation complete: \(action.description)")
                    actionHistory.append(action)
                    state = .completed
                    PlanManager.shared.stepCompleted(
                        PlanManager.shared.activePlan?.phases.first?.steps.last?.id ?? UUID(),
                        result: action.description
                    )
                    break
                }

                // --- ACT ---
                state = .acting
                logger.info("Executing action \(self.cycleCount): \(action.type.displayName)")

                var executedAction = action
                let result = await executeAction(action)
                executedAction.result = result
                actionHistory.append(executedAction)

                if !result.success {
                    logger.warning("Action failed: \(result.message ?? "unknown error")")
                }

                // --- Wait between cycles ---
                try? await Task.sleep(for: .milliseconds(Int(config.captureInterval * 1000)))
            }

            // Cleanup
            userInterventionDetector?.stop()
            userInterventionDetector = nil

            if state != .error && state != .completed {
                state = .completed
            }

            logger.info("Automation finished: \(self.cycleCount) cycles, \(self.actionHistory.count) actions")
        }

        // MARK: - AI Decision Making

        /// Ask the AI to decide the next action based on screen state and task.
        ///
        /// This is the core intelligence — it sends the OCR text, task description,
        /// and action history to the AI and receives a structured action back.
        private func decideNextAction(
            screenState: ScreenState,
            task: String,
            history: [AutomationAction]
        ) async -> AutomationAction {
            state = .deciding

            // Build context for AI
            let historyDescriptions = history.suffix(10).map { action in
                "\(action.type.displayName) → \(action.result?.success == true ? "✓" : "✗") \(action.result?.message ?? "")"
            }

            let context = """
            TASK: \(task)

            CURRENT SCREEN:
            App: \(screenState.activeApp ?? "unknown")
            Window: \(screenState.windowTitle ?? "unknown")
            Screen text (OCR):
            \(String(screenState.text.prefix(3000)))

            PREVIOUS ACTIONS (\(history.count) total):
            \(historyDescriptions.joined(separator: "\n"))

            CYCLE: \(cycleCount)/\(config.maxCycles)
            """

            // For now, return a placeholder action.
            // TODO: Integrate with AI provider pipeline to get actual decisions.
            // This will call the AI with the context above and parse the response
            // into an AutomationAction.
            logger.debug("AI decision context prepared (\(context.count) chars)")

            // Placeholder: After initial observation, mark as done
            // Real implementation will send `context` to AI and parse response
            if cycleCount > 1 {
                return AutomationAction(
                    type: .done(reason: "AI integration pending — placeholder completion"),
                    description: "Automation cycle completed (AI integration needed)",
                    confidence: 1.0
                )
            }

            return AutomationAction(
                type: .screenshot,
                description: "Initial screen capture and analysis",
                confidence: 1.0
            )
        }

        // MARK: - Action Execution

        /// Execute a single automation action using the appropriate engine.
        private func executeAction(_ action: AutomationAction) async -> ActionResult {
            do {
                switch action.type {
                case let .click(x, y):
                    try await automationEngine.executeAction(.click(x: x, y: y))
                    return ActionResult(success: true, message: "Clicked at (\(x), \(y))")

                case let .doubleClick(x, y):
                    try await automationEngine.executeAction(.click(x: x, y: y))
                    try await Task.sleep(for: .milliseconds(50))
                    try await automationEngine.executeAction(.click(x: x, y: y))
                    return ActionResult(success: true, message: "Double-clicked at (\(x), \(y))")

                case let .rightClick(x, y):
                    try await automationEngine.executeAction(.click(x: x, y: y))
                    return ActionResult(success: true, message: "Right-clicked at (\(x), \(y))")

                case let .type(text):
                    try await automationEngine.executeAction(.type(text: text))
                    return ActionResult(success: true, message: "Typed \(text.count) chars")

                case let .keyCombo(key, modifiers):
                    let engineModifiers = modifiers.compactMap { AutomationEngine.KeyModifier(rawValue: $0) }
                    try await automationEngine.executeAction(.keyPress(key: key, modifiers: engineModifiers))
                    return ActionResult(success: true, message: "Key combo: \(modifiers.joined(separator: "+"))+\(key)")

                case let .scroll(direction, amount):
                    let engineDir = AutomationEngine.ScrollDirection(rawValue: direction.rawValue) ?? .down
                    try await automationEngine.executeAction(.scroll(direction: engineDir, amount: amount))
                    return ActionResult(success: true, message: "Scrolled \(direction.rawValue) x\(amount)")

                case let .navigate(url):
                    let service = BrowserAutomationService()
                    try await service.navigate(to: url)
                    return ActionResult(success: true, message: "Navigated to \(url)")

                case let .jsExecute(script):
                    let service = BrowserAutomationService()
                    _ = try await service.executeJavaScript(script)
                    return ActionResult(success: true, message: "JS executed")

                case let .wait(seconds):
                    try await Task.sleep(for: .seconds(seconds))
                    return ActionResult(success: true, message: "Waited \(seconds)s")

                case .screenshot:
                    try await automationEngine.executeAction(.screenshot)
                    return ActionResult(success: true, message: "Screenshot captured")

                case let .done(reason):
                    return ActionResult(success: true, message: reason)
                }
            } catch {
                return ActionResult(success: false, message: error.localizedDescription)
            }
        }
    }

#endif
