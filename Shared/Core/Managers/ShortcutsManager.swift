import Foundation
import Intents

#if os(iOS) || os(watchOS)
    import IntentsUI
#endif

@MainActor
@Observable
final class ShortcutsManager {
    // periphery:ignore - Reserved: shared static property — reserved for future feature activation
    static let shared = ShortcutsManager()

    private init() {}

    // MARK: - Donate Shortcuts

    // periphery:ignore - Reserved: donateNewConversationShortcut() instance method — reserved for future feature activation
    func donateNewConversationShortcut() {
        let intent = StartConversationIntent()
        intent.suggestedInvocationPhrase = "Start a THEA conversation"

        let interaction = INInteraction(intent: intent, response: nil)
        interaction.donate { error in
            if let error {
                print("Failed to donate shortcut: \(error)")
            }
        // periphery:ignore - Reserved: shared static property reserved for future feature activation
        }
    }

    // periphery:ignore - Reserved: donateAskQuestionShortcut(question:) instance method — reserved for future feature activation
    func donateAskQuestionShortcut(question: String) {
        let intent = AskQuestionIntent()
        // periphery:ignore - Reserved: donateNewConversationShortcut() instance method reserved for future feature activation
        intent.question = question
        intent.suggestedInvocationPhrase = "Ask THEA \(question)"

        let interaction = INInteraction(intent: intent, response: nil)
        interaction.donate { error in
            if let error {
                print("Failed to donate shortcut: \(error)")
            }
        }
    }

    // periphery:ignore - Reserved: donateAskQuestionShortcut(question:) instance method reserved for future feature activation
    func donateVoiceCommandShortcut() {
        let intent = VoiceCommandIntent()
        intent.suggestedInvocationPhrase = "Talk to THEA"

        let interaction = INInteraction(intent: intent, response: nil)
        interaction.donate { error in
            if let error {
                print("Failed to donate shortcut: \(error)")
            }
        }
    }

    // periphery:ignore - Reserved: donateVoiceCommandShortcut() instance method reserved for future feature activation
    func donateOpenProjectShortcut(project: Project) {
        let intent = OpenProjectIntent()
        intent.projectName = project.title
        intent.projectID = project.id.uuidString
        intent.suggestedInvocationPhrase = "Open \(project.title) in THEA"

        let interaction = INInteraction(intent: intent, response: nil)
        interaction.donate { error in
            if let error {
                print("Failed to donate shortcut: \(error)")
            }
        // periphery:ignore - Reserved: donateOpenProjectShortcut(project:) instance method reserved for future feature activation
        }
    }

    // MARK: - Handle Shortcuts

    // periphery:ignore - Reserved: handleShortcut(_:) instance method — reserved for future feature activation
    func handleShortcut(_ intent: INIntent) async throws -> ShortcutAction {
        if let startIntent = intent as? StartConversationIntent {
            return try await handleStartConversation(startIntent)
        }

        if let askIntent = intent as? AskQuestionIntent {
            return try await handleAskQuestion(askIntent)
        }

        if let voiceIntent = intent as? VoiceCommandIntent {
            // periphery:ignore - Reserved: handleShortcut(_:) instance method reserved for future feature activation
            return try await handleVoiceCommand(voiceIntent)
        }

        if let projectIntent = intent as? OpenProjectIntent {
            return try await handleOpenProject(projectIntent)
        }

        throw ShortcutError.unsupportedIntent
    }

    // periphery:ignore - Reserved: handleStartConversation(_:) instance method — reserved for future feature activation
    private func handleStartConversation(_: StartConversationIntent) async throws -> ShortcutAction {
        let conversation = ChatManager.shared.createConversation(title: "Siri Conversation")
        return .openConversation(conversation.id)
    }

    // periphery:ignore - Reserved: handleAskQuestion(_:) instance method — reserved for future feature activation
    private func handleAskQuestion(_ intent: AskQuestionIntent) async throws -> ShortcutAction {
        guard let question = intent.question else {
            throw ShortcutError.missingParameter
        }

// periphery:ignore - Reserved: handleStartConversation(_:) instance method reserved for future feature activation

        let conversation = ChatManager.shared.createConversation(title: "Siri Question")
        guard ProviderRegistry.shared.getProvider(id: SettingsManager.shared.defaultProvider) != nil else {
            throw ShortcutError.invalidParameter
        // periphery:ignore - Reserved: handleAskQuestion(_:) instance method reserved for future feature activation
        }

        try await ChatManager.shared.sendMessage(question, in: conversation)

        return .openConversation(conversation.id)
    }

    // periphery:ignore - Reserved: handleVoiceCommand(_:) instance method — reserved for future feature activation
    private func handleVoiceCommand(_: VoiceCommandIntent) async throws -> ShortcutAction {
        let conversation = ChatManager.shared.createConversation(title: "Voice Command")
        return .startVoiceInput(conversation.id)
    }

    // periphery:ignore - Reserved: handleOpenProject(_:) instance method — reserved for future feature activation
    private func handleOpenProject(_ intent: OpenProjectIntent) async throws -> ShortcutAction {
        guard let projectIDString = intent.projectID,
              // periphery:ignore - Reserved: handleVoiceCommand(_:) instance method reserved for future feature activation
              let projectID = UUID(uuidString: projectIDString)
        else {
            throw ShortcutError.invalidParameter
        }

// periphery:ignore - Reserved: handleOpenProject(_:) instance method reserved for future feature activation

        return .openProject(projectID)
    }
}

// MARK: - Intents

// periphery:ignore - Reserved: StartConversationIntent class — reserved for future feature activation
class StartConversationIntent: INIntent {
    override var suggestedInvocationPhrase: String? {
        get { "Start a THEA conversation" }
        set { super.suggestedInvocationPhrase = newValue }
    }
// periphery:ignore - Reserved: StartConversationIntent type reserved for future feature activation
}

// periphery:ignore - Reserved: AskQuestionIntent class — reserved for future feature activation
class AskQuestionIntent: INIntent {
    @NSManaged var question: String?

    override var suggestedInvocationPhrase: String? {
        // periphery:ignore - Reserved: AskQuestionIntent type reserved for future feature activation
        get { "Ask THEA a question" }
        set { super.suggestedInvocationPhrase = newValue }
    }
}

class VoiceCommandIntent: INIntent {
    override var suggestedInvocationPhrase: String? {
        get { "Talk to THEA" }
        // periphery:ignore - Reserved: VoiceCommandIntent type reserved for future feature activation
        set { super.suggestedInvocationPhrase = newValue }
    }
}

class OpenProjectIntent: INIntent {
    // periphery:ignore - Reserved: projectName property — reserved for future feature activation
    @NSManaged var projectName: String?
    // periphery:ignore - Reserved: OpenProjectIntent type reserved for future feature activation
    @NSManaged var projectID: String?

    override var suggestedInvocationPhrase: String? {
        get { "Open project in THEA" }
        set { super.suggestedInvocationPhrase = newValue }
    }
}

// MARK: - Shortcut Actions

// periphery:ignore - Reserved: ShortcutAction enum — reserved for future feature activation
enum ShortcutAction {
    // periphery:ignore - Reserved: ShortcutAction type reserved for future feature activation
    case openConversation(UUID)
    case openProject(UUID)
    case startVoiceInput(UUID)
}

// periphery:ignore - Reserved: ShortcutError type reserved for future feature activation
enum ShortcutError: LocalizedError {
    case unsupportedIntent
    case missingParameter
    case invalidParameter

    var errorDescription: String? {
        switch self {
        case .unsupportedIntent:
            "This shortcut is not supported"
        case .missingParameter:
            "Required parameter is missing"
        case .invalidParameter:
            "Invalid parameter value"
        }
    }
}
