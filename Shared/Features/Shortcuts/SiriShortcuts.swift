// SiriShortcuts.swift
// Siri Shortcuts and App Intents integration

import Foundation
import AppIntents
import OSLog

// MARK: - App Shortcuts Provider

@available(iOS 16.0, macOS 13.0, watchOS 9.0, *)
public struct TheaShortcuts: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AskTheaIntent(),
            phrases: [
                "Ask \(.applicationName)",
                "Ask \(.applicationName) \(\.$query)",
                "What does \(.applicationName) think about \(\.$query)",
                "Hey \(.applicationName)",
                "\(.applicationName) help me with \(\.$query)"
            ],
            shortTitle: "Ask Thea",
            systemImageName: "sparkles"
        )

        AppShortcut(
            intent: StartConversationIntent(),
            phrases: [
                "Start a conversation with \(.applicationName)",
                "New chat with \(.applicationName)",
                "Begin \(.applicationName) conversation"
            ],
            shortTitle: "New Conversation",
            systemImageName: "bubble.left.and.bubble.right"
        )

        AppShortcut(
            intent: QuickPromptIntent(),
            phrases: [
                "Quick prompt \(.applicationName)",
                "\(.applicationName) quick question"
            ],
            shortTitle: "Quick Prompt",
            systemImageName: "text.cursor"
        )

        AppShortcut(
            intent: RunAgentIntent(),
            phrases: [
                "Run \(.applicationName) agent \(\.$agentName)",
                "Start \(\.$agentName) agent",
                "Use \(\.$agentName) in \(.applicationName)"
            ],
            shortTitle: "Run Agent",
            systemImageName: "person.fill.badge.plus"
        )

        AppShortcut(
            intent: SummarizeTextIntent(),
            phrases: [
                "Summarize with \(.applicationName)",
                "\(.applicationName) summarize this",
                "Get summary from \(.applicationName)"
            ],
            shortTitle: "Summarize",
            systemImageName: "doc.text"
        )

        AppShortcut(
            intent: TranslateTextIntent(),
            phrases: [
                "Translate with \(.applicationName)",
                "\(.applicationName) translate to \(\.$targetLanguage)"
            ],
            shortTitle: "Translate",
            systemImageName: "globe"
        )
    }
}

// MARK: - Ask Thea Intent

@available(iOS 16.0, macOS 13.0, watchOS 9.0, *)
public struct AskTheaIntent: AppIntent {
    public static var title: LocalizedStringResource = "Ask Thea"
    public static var description = IntentDescription("Ask Thea AI a question and get an intelligent response")

    @Parameter(title: "Question")
    public var query: String

    @Parameter(title: "Use Quick Response", default: true)
    public var quickResponse: Bool

    public init() {}

    public func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        // Process with AI
        let response = try await processQuery(query)

        return .result(
            value: response,
            dialog: IntentDialog(stringLiteral: response)
        )
    }

    private func processQuery(_ query: String) async throws -> String {
        // This would integrate with your AI service
        // For now, return a placeholder
        return "I'll help you with: \(query)"
    }
}

// MARK: - Start Conversation Intent

@available(iOS 16.0, macOS 13.0, watchOS 9.0, *)
public struct StartConversationIntent: AppIntent {
    public static var title: LocalizedStringResource = "Start Conversation"
    public static var description = IntentDescription("Start a new conversation with Thea AI")
    public static var openAppWhenRun = true

    @Parameter(title: "Initial Message")
    public var initialMessage: String?

    public init() {}

    public func perform() async throws -> some IntentResult {
        // Open app with new conversation
        if let message = initialMessage {
            // Pass message to new conversation
            UserDefaults.standard.set(message, forKey: "shortcut.pendingMessage")
        }

        return .result()
    }
}

// MARK: - Quick Prompt Intent

@available(iOS 16.0, macOS 13.0, watchOS 9.0, *)
public struct QuickPromptIntent: AppIntent {
    public static var title: LocalizedStringResource = "Quick Prompt"
    public static var description = IntentDescription("Open the quick prompt overlay")
    public static var openAppWhenRun = true

    public init() {}

    public func perform() async throws -> some IntentResult {
        // Signal to open quick prompt
        UserDefaults.standard.set(true, forKey: "shortcut.openQuickPrompt")
        return .result()
    }
}

// MARK: - Run Agent Intent

@available(iOS 16.0, macOS 13.0, watchOS 9.0, *)
public struct RunAgentIntent: AppIntent {
    public static var title: LocalizedStringResource = "Run Agent"
    public static var description = IntentDescription("Run a Thea AI agent")

    @Parameter(title: "Agent Name")
    public var agentName: String

    @Parameter(title: "Task Description")
    public var taskDescription: String?

    public init() {}

    public func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        // Start the agent
        let result = try await startAgent(agentName, task: taskDescription)

        return .result(
            value: result,
            dialog: IntentDialog(stringLiteral: result)
        )
    }

    private func startAgent(_ name: String, task: String?) async throws -> String {
        // This would integrate with your agent system
        return "Started agent '\(name)' with task: \(task ?? "default")"
    }
}

// MARK: - Summarize Intent

@available(iOS 16.0, macOS 13.0, watchOS 9.0, *)
public struct SummarizeTextIntent: AppIntent {
    public static var title: LocalizedStringResource = "Summarize"
    public static var description = IntentDescription("Summarize text using Thea AI")

    @Parameter(title: "Text to Summarize")
    public var text: String

    @Parameter(title: "Summary Length", default: .medium)
    public var length: SummaryLength

    public init() {}

    public func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let summary = try await summarize(text, length: length)

        return .result(
            value: summary,
            dialog: IntentDialog(stringLiteral: summary)
        )
    }

    private func summarize(_ text: String, length: SummaryLength) async throws -> String {
        // This would integrate with your AI service
        return "Summary of: \(text.prefix(50))..."
    }
}

public enum SummaryLength: String, AppEnum {
    case brief
    case medium
    case detailed

    public static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Summary Length")

    public static var caseDisplayRepresentations: [SummaryLength: DisplayRepresentation] = [
        .brief: "Brief",
        .medium: "Medium",
        .detailed: "Detailed"
    ]
}

// MARK: - Translate Intent

@available(iOS 16.0, macOS 13.0, watchOS 9.0, *)
public struct TranslateTextIntent: AppIntent {
    public static var title: LocalizedStringResource = "Translate"
    public static var description = IntentDescription("Translate text using Thea AI")

    @Parameter(title: "Text to Translate")
    public var text: String

    @Parameter(title: "Target Language")
    public var targetLanguage: TranslationLanguage

    public init() {}

    public func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let translation = try await translate(text, to: targetLanguage)

        return .result(
            value: translation,
            dialog: IntentDialog(stringLiteral: translation)
        )
    }

    private func translate(_ text: String, to language: TranslationLanguage) async throws -> String {
        // This would integrate with your AI service
        return "[\(language.rawValue)] \(text)"
    }
}

public enum TranslationLanguage: String, AppEnum {
    case english = "en"
    case spanish = "es"
    case french = "fr"
    case german = "de"
    case italian = "it"
    case portuguese = "pt"
    case chinese = "zh"
    case japanese = "ja"
    case korean = "ko"
    case arabic = "ar"
    case russian = "ru"
    case hindi = "hi"

    public static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Language")

    public static var caseDisplayRepresentations: [TranslationLanguage: DisplayRepresentation] = [
        .english: "English",
        .spanish: "Spanish",
        .french: "French",
        .german: "German",
        .italian: "Italian",
        .portuguese: "Portuguese",
        .chinese: "Chinese",
        .japanese: "Japanese",
        .korean: "Korean",
        .arabic: "Arabic",
        .russian: "Russian",
        .hindi: "Hindi"
    ]
}

// MARK: - Entity Queries

@available(iOS 16.0, macOS 13.0, watchOS 9.0, *)
public struct ConversationEntity: AppEntity {
    public static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Conversation")

    public var id: String
    public var title: String
    public var createdAt: Date

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: LocalizedStringResource(stringLiteral: title),
            subtitle: LocalizedStringResource(stringLiteral: createdAt.formatted())
        )
    }

    public static var defaultQuery = ConversationQuery()
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, *)
public struct ConversationQuery: EntityQuery {
    public init() {}

    public func entities(for identifiers: [String]) async throws -> [ConversationEntity] {
        // Fetch conversations by IDs
        return []
    }

    public func suggestedEntities() async throws -> [ConversationEntity] {
        // Return recent conversations
        return []
    }
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, *)
public struct AgentEntity: AppEntity {
    public static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Agent")

    public var id: String
    public var name: String
    public var description: String

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: LocalizedStringResource(stringLiteral: name),
            subtitle: LocalizedStringResource(stringLiteral: description)
        )
    }

    public static var defaultQuery = AgentQuery()
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, *)
public struct AgentQuery: EntityQuery {
    public init() {}

    public func entities(for identifiers: [String]) async throws -> [AgentEntity] {
        return []
    }

    public func suggestedEntities() async throws -> [AgentEntity] {
        return []
    }
}

// MARK: - Continue Conversation Intent

@available(iOS 16.0, macOS 13.0, watchOS 9.0, *)
public struct ContinueConversationIntent: AppIntent {
    public static var title: LocalizedStringResource = "Continue Conversation"
    public static var description = IntentDescription("Continue an existing Thea conversation")
    public static var openAppWhenRun = true

    @Parameter(title: "Conversation")
    public var conversation: ConversationEntity

    public init() {}

    public func perform() async throws -> some IntentResult {
        UserDefaults.standard.set(conversation.id, forKey: "shortcut.openConversation")
        return .result()
    }
}

// MARK: - Analyze Image Intent

@available(iOS 16.0, macOS 13.0, watchOS 9.0, *)
public struct AnalyzeImageIntent: AppIntent {
    public static var title: LocalizedStringResource = "Analyze Image"
    public static var description = IntentDescription("Analyze an image using Thea AI vision")

    @Parameter(title: "Image")
    public var image: IntentFile

    @Parameter(title: "Analysis Type", default: .general)
    public var analysisType: ImageAnalysisType

    public init() {}

    public func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        guard let imageData = image.data else {
            throw TheaIntentError.invalidInput("No image data")
        }

        let analysis = try await analyzeImage(imageData, type: analysisType)

        return .result(
            value: analysis,
            dialog: IntentDialog(stringLiteral: analysis)
        )
    }

    private func analyzeImage(_ data: Data, type: ImageAnalysisType) async throws -> String {
        // This would integrate with your vision service
        return "Image analysis result for \(type.rawValue)"
    }
}

public enum ImageAnalysisType: String, AppEnum {
    case general
    case text
    case objects
    case faces
    case document

    public static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Analysis Type")

    public static var caseDisplayRepresentations: [ImageAnalysisType: DisplayRepresentation] = [
        .general: "General",
        .text: "Extract Text",
        .objects: "Identify Objects",
        .faces: "Detect Faces",
        .document: "Document Analysis"
    ]
}

// MARK: - Error Types

public enum TheaIntentError: Error, LocalizedError {
    case invalidInput(String)
    case processingFailed(String)
    case serviceUnavailable

    public var errorDescription: String? {
        switch self {
        case .invalidInput(let reason):
            return "Invalid input: \(reason)"
        case .processingFailed(let reason):
            return "Processing failed: \(reason)"
        case .serviceUnavailable:
            return "Thea AI service is unavailable"
        }
    }
}

// MARK: - Shortcuts Manager

@MainActor
public final class SiriShortcutsManager: ObservableObject {
    public static let shared = SiriShortcutsManager()

    private let logger = Logger(subsystem: "com.thea.app", category: "Shortcuts")

    @Published public private(set) var donatedShortcuts: [String] = []

    private init() {}

    /// Donate a shortcut for a conversation
    @available(iOS 16.0, macOS 13.0, *)
    public func donateConversationShortcut(
        conversationId: String,
        title: String
    ) {
        // The system handles shortcut donations automatically with App Intents
        // This method can be used to track donated shortcuts
        donatedShortcuts.append(conversationId)
        logger.info("Donated shortcut for conversation: \(title)")
    }

    /// Handle shortcut activation from user defaults
    public func handlePendingShortcuts() {
        if UserDefaults.standard.bool(forKey: "shortcut.openQuickPrompt") {
            UserDefaults.standard.removeObject(forKey: "shortcut.openQuickPrompt")
            Task { @MainActor in
                GlobalQuickPromptManager.shared.show()
            }
        }

        if let conversationId = UserDefaults.standard.string(forKey: "shortcut.openConversation") {
            UserDefaults.standard.removeObject(forKey: "shortcut.openConversation")
            // Open the conversation
            NotificationCenter.default.post(
                name: .shortcutOpenConversation,
                object: nil,
                userInfo: ["conversationId": conversationId]
            )
        }

        if let message = UserDefaults.standard.string(forKey: "shortcut.pendingMessage") {
            UserDefaults.standard.removeObject(forKey: "shortcut.pendingMessage")
            // Create new conversation with message
            NotificationCenter.default.post(
                name: .shortcutNewConversation,
                object: nil,
                userInfo: ["message": message]
            )
        }
    }
}

// MARK: - Notifications

public extension Notification.Name {
    static let shortcutOpenConversation = Notification.Name("thea.shortcut.openConversation")
    static let shortcutNewConversation = Notification.Name("thea.shortcut.newConversation")
}
