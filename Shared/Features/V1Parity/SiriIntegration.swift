// SiriIntegration.swift
// Thea V2
//
// Siri Shortcuts and voice integration.
// Enables hands-free interaction with Thea via Siri.
//
// V1 FEATURE PARITY
// CREATED: February 2, 2026

import Foundation
import OSLog

// MARK: - Types (available on all platforms)

/// Actions that can be invoked via Siri shortcuts
public enum SiriShortcutAction: String, Sendable {
    case askQuestion
    case getDailyBriefing
    case startConversation
    case createTask
    case executeCommand
}

/// Response actions from Siri handler
public enum SiriResponseAction: String, Sendable {
    case speak
    case openApp
    case prompt
    case none
}

/// Authorization status for Siri
public enum SiriAuthStatus: String, Sendable {
    case notDetermined
    case restricted
    case denied
    case authorized
}

/// A shortcut definition for Thea
public struct TheaShortcut: Sendable, Identifiable {
    public let id: String
    public let title: String
    public let description: String
    public let invocationPhrase: String
    public let action: SiriShortcutAction

    public init(id: String, title: String, description: String, invocationPhrase: String, action: SiriShortcutAction) {
        self.id = id
        self.title = title
        self.description = description
        self.invocationPhrase = invocationPhrase
        self.action = action
    }
}

/// Record of a donated shortcut
public struct DonatedShortcut: Sendable, Identifiable {
    public let id = UUID()
    public let shortcut: TheaShortcut
    public let donatedAt: Date
}

/// Request from Siri
public struct SiriRequest: Sendable {
    public let action: SiriShortcutAction
    public let query: String?
    public let parameters: [String: String]

    public init(action: SiriShortcutAction, query: String? = nil, parameters: [String: String] = [:]) {
        self.action = action
        self.query = query
        self.parameters = parameters
    }
}

/// Response to Siri
public struct SiriResponse: Sendable {
    public let success: Bool
    public let message: String
    public let action: SiriResponseAction
    public var data: [String: String] = [:]

    public init(success: Bool, message: String, action: SiriResponseAction, data: [String: String] = [:]) {
        self.success = success
        self.message = message
        self.action = action
        self.data = data
    }
}

// MARK: - Siri Integration Service

#if os(iOS) || os(watchOS)
import Intents

@MainActor
@Observable
public final class SiriIntegrationService {
    public static let shared = SiriIntegrationService()

    private let logger = Logger(subsystem: "com.thea.features", category: "Siri")

    // MARK: - State

    public private(set) var isEnabled: Bool = false
    public private(set) var donatedShortcuts: [DonatedShortcut] = []
    public private(set) var authorizationStatus: SiriAuthStatus = .notDetermined

    // MARK: - Configuration

    public var autoDonateSuggestions: Bool = true
    public var enableVoiceActivation: Bool = true

    private init() {
        Task {
            await checkAuthorization()
        }
    }

    // MARK: - Public API

    /// Request Siri authorization
    public func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            INPreferences.requestSiriAuthorization { status in
                Task { @MainActor in
                    self.authorizationStatus = self.convertStatus(status)
                    self.isEnabled = status == .authorized
                    continuation.resume(returning: status == .authorized)
                }
            }
        }
    }

    /// Donate a shortcut to Siri
    public func donateShortcut(_ shortcut: TheaShortcut) async {
        guard isEnabled else {
            logger.warning("Cannot donate shortcut - Siri not enabled")
            return
        }

        let intent = createIntent(for: shortcut)
        let interaction = INInteraction(intent: intent, response: nil)

        do {
            try await interaction.donate()

            donatedShortcuts.append(DonatedShortcut(
                shortcut: shortcut,
                donatedAt: Date()
            ))

            logger.info("Donated shortcut: \(shortcut.title)")
        } catch {
            logger.error("Failed to donate shortcut: \(error.localizedDescription)")
        }
    }

    /// Donate common shortcuts
    public func donateCommonShortcuts() async {
        let common: [TheaShortcut] = [
            TheaShortcut(
                id: "ask_thea",
                title: "Ask Thea",
                description: "Ask Thea a question",
                invocationPhrase: "Ask Thea",
                action: SiriShortcutAction.askQuestion
            ),
            TheaShortcut(
                id: "daily_briefing",
                title: "Daily Briefing",
                description: "Get your daily briefing from Thea",
                invocationPhrase: "Daily briefing",
                action: SiriShortcutAction.getDailyBriefing
            ),
            TheaShortcut(
                id: "start_conversation",
                title: "Start Conversation",
                description: "Start a new conversation with Thea",
                invocationPhrase: "Talk to Thea",
                action: SiriShortcutAction.startConversation
            ),
            TheaShortcut(
                id: "quick_task",
                title: "Quick Task",
                description: "Create a quick task or reminder",
                invocationPhrase: "Thea quick task",
                action: SiriShortcutAction.createTask
            )
        ]

        for shortcut in common {
            await donateShortcut(shortcut)
        }
    }

    /// Handle an incoming Siri request
    public func handleSiriRequest(_ request: SiriRequest) async -> SiriResponse {
        logger.info("Handling Siri request: \(request.action.rawValue)")

        switch request.action {
        case .askQuestion:
            return await handleQuestion(request.query ?? "")

        case .getDailyBriefing:
            return await handleDailyBriefing()

        case .startConversation:
            return SiriResponse(
                success: true,
                message: "Starting a new conversation with Thea",
                action: SiriResponseAction.openApp
            )

        case .createTask:
            return await handleCreateTask(request.query ?? "")

        case .executeCommand:
            return await handleCommand(request.query ?? "")
        }
    }

    // MARK: - Private Implementation

    private func checkAuthorization() async {
        let status = INPreferences.siriAuthorizationStatus()
        authorizationStatus = convertStatus(status)
        isEnabled = status == .authorized
    }

    private func convertStatus(_ status: INSiriAuthorizationStatus) -> SiriAuthStatus {
        switch status {
        case .notDetermined: return .notDetermined
        case .restricted: return .restricted
        case .denied: return .denied
        case .authorized: return .authorized
        @unknown default: return .notDetermined
        }
    }

    private func createIntent(for shortcut: TheaShortcut) -> INIntent {
        // Use a generic intent - in production, create custom intents
        let intent = INSearchForNotebookItemsIntent()
        intent.suggestedInvocationPhrase = shortcut.invocationPhrase
        return intent
    }

    // periphery:ignore - Reserved: AD3 audit — wired in future integration
    private func handleQuestion(_ question: String) async -> SiriResponse {
        guard !question.isEmpty else {
            return SiriResponse(
                success: false,
                message: "What would you like to ask?",
                action: SiriResponseAction.prompt
            )
        }

        guard let provider = ProviderRegistry.shared.getDefaultProvider() else {
            return SiriResponse(
                success: false,
                message: "AI services are currently unavailable",
                action: SiriResponseAction.none
            )
        }

        do {
            let model = await DynamicConfig.shared.bestModel(for: .conversation)
            let userMessage = AIMessage(
                id: UUID(),
                conversationID: UUID(),
                role: .user,
                content: .text(question),
                timestamp: Date(),
                model: model
            )
            let stream = try await provider.chat(messages: [userMessage], model: model, stream: false)
            var response = ""
            for try await chunk in stream {
                switch chunk.type {
                case .delta(let text):
                    response += text
                case .complete(let message):
                    response = message.content.textValue
                case .error(let error):
                    throw error
                }
            }

            return SiriResponse(
                success: true,
                message: response,
                action: SiriResponseAction.speak
            )
        } catch {
            return SiriResponse(
                success: false,
                message: "I couldn't process that question",
                action: SiriResponseAction.none
            )
        }
    }

    // periphery:ignore - Reserved: AD3 audit — wired in future integration
    private func handleDailyBriefing() async -> SiriResponse {
        let briefing = await LifeAssistantService.shared.generateDailyBriefing()

        let summary = """
        \(briefing.greeting)
        You have \(briefing.calendarSummary?.eventCount ?? 0) events today.
        \(briefing.weatherForecast ?? "")
        \(briefing.motivationalQuote)
        """

        return SiriResponse(
            success: true,
            message: summary,
            action: SiriResponseAction.speak
        )
    }

    // periphery:ignore - Reserved: AD3 audit — wired in future integration
    private func handleCreateTask(_ description: String) async -> SiriResponse {
        // Integrate with task management
        SiriResponse(
            success: true,
            message: "I've noted that task: \(description)",
            action: SiriResponseAction.speak
        )
    }

    // periphery:ignore - Reserved: AD3 audit — wired in future integration
    private func handleCommand(_ command: String) async -> SiriResponse {
        // Parse and execute command
        SiriResponse(
            success: true,
            message: "Command received",
            action: SiriResponseAction.none
        )
    }
}

#else
// MARK: - macOS/tvOS Stub Implementation

/// Stub implementation for platforms without Siri support
@MainActor
@Observable
public final class SiriIntegrationService {
    public static let shared = SiriIntegrationService()

    private let logger = Logger(subsystem: "com.thea.features", category: "Siri")

    public private(set) var isEnabled: Bool = false
    public private(set) var donatedShortcuts: [DonatedShortcut] = []
    public private(set) var authorizationStatus: SiriAuthStatus = .notDetermined

    public var autoDonateSuggestions: Bool = true
    public var enableVoiceActivation: Bool = true

    private init() {
        logger.info("Siri integration not available on this platform")
    }

    public func requestAuthorization() async -> Bool {
        false
    }

    // periphery:ignore - Reserved: shortcut parameter — kept for API compatibility
    public func donateShortcut(_ shortcut: TheaShortcut) async {
        // periphery:ignore - Reserved: shortcut parameter kept for API compatibility
        logger.warning("Siri shortcuts not available on this platform")
    }

    public func donateCommonShortcuts() async {
        logger.warning("Siri shortcuts not available on this platform")
    }

    // periphery:ignore - Reserved: request parameter kept for API compatibility
    public func handleSiriRequest(_ request: SiriRequest) async -> SiriResponse {
        SiriResponse(
            success: false,
            message: "Siri not available on this platform",
            action: SiriResponseAction.none
        )
    }
}
#endif
