// SiriShortcuts.swift
// Siri Shortcuts and App Intents integration

import AppIntents
import Foundation
import OSLog

// MARK: - Siri Shortcuts (Intents only - shortcuts registered in TheaAppIntents.swift)

// MARK: - Ask Thea Intent

@available(iOS 16.0, macOS 13.0, watchOS 9.0, *)
public struct SiriAskTheaIntent: AppIntent {
    nonisolated(unsafe) public static var title: LocalizedStringResource = "Ask Thea"
    nonisolated(unsafe) public static var description = IntentDescription("Ask Thea AI a question and get an intelligent response")

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
        "I'll help you with: \(query)"
    }
}

// MARK: - Start Conversation Intent

@available(iOS 16.0, macOS 13.0, watchOS 9.0, *)
public struct SiriStartConversationIntent: AppIntent {
    nonisolated(unsafe) public static var title: LocalizedStringResource = "Start Conversation"
    nonisolated(unsafe) public static var description = IntentDescription("Start a new conversation with Thea AI")
    nonisolated(unsafe) public static var openAppWhenRun = true

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
public struct SiriQuickPromptIntent: AppIntent {
    nonisolated(unsafe) public static var title: LocalizedStringResource = "Quick Prompt"
    nonisolated(unsafe) public static var description = IntentDescription("Open the quick prompt overlay")
    nonisolated(unsafe) public static var openAppWhenRun = true

    public init() {}

    public func perform() async throws -> some IntentResult {
        // Signal to open quick prompt
        UserDefaults.standard.set(true, forKey: "shortcut.openQuickPrompt")
        return .result()
    }
}

// MARK: - Run Agent Intent

@available(iOS 16.0, macOS 13.0, watchOS 9.0, *)
public struct SiriRunAgentIntent: AppIntent {
    nonisolated(unsafe) public static var title: LocalizedStringResource = "Run Agent"
    nonisolated(unsafe) public static var description = IntentDescription("Run a Thea AI agent")

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
        "Started agent '\(name)' with task: \(task ?? "default")"
    }
}

// MARK: - Summarize Intent

@available(iOS 16.0, macOS 13.0, watchOS 9.0, *)
public struct SiriSummarizeTextIntent: AppIntent {
    nonisolated(unsafe) public static var title: LocalizedStringResource = "Summarize"
    nonisolated(unsafe) public static var description = IntentDescription("Summarize text using Thea AI")

    @Parameter(title: "Text to Summarize")
    public var text: String

    @Parameter(title: "Summary Length", default: .medium)
    public var length: SiriSummaryLength

    public init() {}

    public func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let summary = try await summarize(text, length: length)

        return .result(
            value: summary,
            dialog: IntentDialog(stringLiteral: summary)
        )
    }

    private func summarize(_ text: String, length _: SiriSummaryLength) async throws -> String {
        // This would integrate with your AI service
        "Summary of: \(text.prefix(50))..."
    }
}

public enum SiriSummaryLength: String, AppEnum {
    case brief
    case medium
    case detailed

    nonisolated(unsafe) public static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Summary Length")

    nonisolated(unsafe) public static var caseDisplayRepresentations: [SiriSummaryLength: DisplayRepresentation] = [
        .brief: "Brief",
        .medium: "Medium",
        .detailed: "Detailed"
    ]
}

// MARK: - Translate Intent

@available(iOS 16.0, macOS 13.0, watchOS 9.0, *)
public struct SiriTranslateTextIntent: AppIntent {
    nonisolated(unsafe) public static var title: LocalizedStringResource = "Translate"
    nonisolated(unsafe) public static var description = IntentDescription("Translate text using Thea AI")

    @Parameter(title: "Text to Translate")
    public var text: String

    @Parameter(title: "Target Language")
    public var targetLanguage: SiriTranslationLanguage

    public init() {}

    public func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let translation = try await translate(text, to: targetLanguage)

        return .result(
            value: translation,
            dialog: IntentDialog(stringLiteral: translation)
        )
    }

    private func translate(_ text: String, to language: SiriTranslationLanguage) async throws -> String {
        // This would integrate with your AI service
        "[\(language.rawValue)] \(text)"
    }
}

public enum SiriTranslationLanguage: String, AppEnum {
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

    nonisolated(unsafe) public static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Language")

    nonisolated(unsafe) public static var caseDisplayRepresentations: [SiriTranslationLanguage: DisplayRepresentation] = [
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
public struct SiriConversationEntity: AppEntity {
    nonisolated(unsafe) public static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Conversation")

    public var id: String
    public var title: String
    public var createdAt: Date

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: LocalizedStringResource(stringLiteral: title),
            subtitle: LocalizedStringResource(stringLiteral: createdAt.formatted())
        )
    }

    nonisolated(unsafe) public static var defaultQuery = SiriConversationQuery()
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, *)
public struct SiriConversationQuery: EntityQuery {
    public init() {}

    public func entities(for _: [String]) async throws -> [SiriConversationEntity] {
        // Fetch conversations by IDs
        []
    }

    public func suggestedEntities() async throws -> [SiriConversationEntity] {
        // Return recent conversations
        []
    }
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, *)
public struct SiriAgentEntity: AppEntity {
    nonisolated(unsafe) public static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Agent")

    public var id: String
    public var name: String
    public var description: String

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: LocalizedStringResource(stringLiteral: name),
            subtitle: LocalizedStringResource(stringLiteral: description)
        )
    }

    nonisolated(unsafe) public static var defaultQuery = SiriAgentQuery()
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, *)
public struct SiriAgentQuery: EntityQuery {
    public init() {}

    public func entities(for _: [String]) async throws -> [SiriAgentEntity] {
        []
    }

    public func suggestedEntities() async throws -> [SiriAgentEntity] {
        []
    }
}

// MARK: - Continue Conversation Intent

@available(iOS 16.0, macOS 13.0, watchOS 9.0, *)
public struct SiriContinueConversationIntent: AppIntent {
    nonisolated(unsafe) public static var title: LocalizedStringResource = "Continue Conversation"
    nonisolated(unsafe) public static var description = IntentDescription("Continue an existing Thea conversation")
    nonisolated(unsafe) public static var openAppWhenRun = true

    @Parameter(title: "Conversation")
    public var conversation: SiriConversationEntity

    public init() {}

    public func perform() async throws -> some IntentResult {
        UserDefaults.standard.set(conversation.id, forKey: "shortcut.openConversation")
        return .result()
    }
}

// MARK: - Analyze Image Intent

@available(iOS 16.0, macOS 13.0, watchOS 9.0, *)
public struct SiriAnalyzeImageIntent: AppIntent {
    nonisolated(unsafe) public static var title: LocalizedStringResource = "Analyze Image"
    nonisolated(unsafe) public static var description = IntentDescription("Analyze an image using Thea AI vision")

    @Parameter(title: "Image")
    public var image: IntentFile

    @Parameter(title: "Analysis Type", default: .general)
    public var analysisType: SiriImageAnalysisType

    public init() {}

    public func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let imageData = image.data

        let analysis = try await analyzeImage(imageData, type: analysisType)

        return .result(
            value: analysis,
            dialog: IntentDialog(stringLiteral: analysis)
        )
    }

    private func analyzeImage(_: Data, type: SiriImageAnalysisType) async throws -> String {
        // This would integrate with your vision service
        "Image analysis result for \(type.rawValue)"
    }
}

public enum SiriImageAnalysisType: String, AppEnum {
    case general
    case text
    case objects
    case faces
    case document

    nonisolated(unsafe) public static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Analysis Type")

    nonisolated(unsafe) public static var caseDisplayRepresentations: [SiriImageAnalysisType: DisplayRepresentation] = [
        .general: "General",
        .text: "Extract Text",
        .objects: "Identify Objects",
        .faces: "Detect Faces",
        .document: "Document Analysis"
    ]
}

// MARK: - Error Types

public enum SiriIntentError: Error, LocalizedError {
    case invalidInput(String)
    case processingFailed(String)
    case serviceUnavailable

    public var errorDescription: String? {
        switch self {
        case let .invalidInput(reason):
            "Invalid input: \(reason)"
        case let .processingFailed(reason):
            "Processing failed: \(reason)"
        case .serviceUnavailable:
            "Thea AI service is unavailable"
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
