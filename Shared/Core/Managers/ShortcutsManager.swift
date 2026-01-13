import Foundation
import Intents

#if os(iOS) || os(watchOS)
import IntentsUI
#endif

@MainActor
@Observable
final class ShortcutsManager {
    static let shared = ShortcutsManager()

    private init() {}

    // MARK: - Donate Shortcuts

    func donateNewConversationShortcut() {
        let intent = StartConversationIntent()
        intent.suggestedInvocationPhrase = "Start a THEA conversation"

        let interaction = INInteraction(intent: intent, response: nil)
        interaction.donate { error in
            if let error = error {
                print("Failed to donate shortcut: \(error)")
            }
        }
    }

    func donateAskQuestionShortcut(question: String) {
        let intent = AskQuestionIntent()
        intent.question = question
        intent.suggestedInvocationPhrase = "Ask THEA \(question)"

        let interaction = INInteraction(intent: intent, response: nil)
        interaction.donate { error in
            if let error = error {
                print("Failed to donate shortcut: \(error)")
            }
        }
    }

    func donateVoiceCommandShortcut() {
        let intent = VoiceCommandIntent()
        intent.suggestedInvocationPhrase = "Talk to THEA"

        let interaction = INInteraction(intent: intent, response: nil)
        interaction.donate { error in
            if let error = error {
                print("Failed to donate shortcut: \(error)")
            }
        }
    }

    func donateOpenProjectShortcut(project: Project) {
        let intent = OpenProjectIntent()
        intent.projectName = project.title
        intent.projectID = project.id.uuidString
        intent.suggestedInvocationPhrase = "Open \(project.title) in THEA"

        let interaction = INInteraction(intent: intent, response: nil)
        interaction.donate { error in
            if let error = error {
                print("Failed to donate shortcut: \(error)")
            }
        }
    }

    // MARK: - Handle Shortcuts

    func handleShortcut(_ intent: INIntent) async throws -> ShortcutAction {
        if let startIntent = intent as? StartConversationIntent {
            return try await handleStartConversation(startIntent)
        }

        if let askIntent = intent as? AskQuestionIntent {
            return try await handleAskQuestion(askIntent)
        }

        if let voiceIntent = intent as? VoiceCommandIntent {
            return try await handleVoiceCommand(voiceIntent)
        }

        if let projectIntent = intent as? OpenProjectIntent {
            return try await handleOpenProject(projectIntent)
        }

        throw ShortcutError.unsupportedIntent
    }

    private func handleStartConversation(_ intent: StartConversationIntent) async throws -> ShortcutAction {
        let conversation = ChatManager.shared.createConversation(title: "Siri Conversation")
        return .openConversation(conversation.id)
    }

    private func handleAskQuestion(_ intent: AskQuestionIntent) async throws -> ShortcutAction {
        guard let question = intent.question else {
            throw ShortcutError.missingParameter
        }

        let conversation = ChatManager.shared.createConversation(title: "Siri Question")
        guard ProviderRegistry.shared.getProvider(id: SettingsManager.shared.defaultProvider) != nil else {
            throw ShortcutError.invalidParameter
        }

        try await ChatManager.shared.sendMessage(question, in: conversation)

        return .openConversation(conversation.id)
    }

    private func handleVoiceCommand(_ intent: VoiceCommandIntent) async throws -> ShortcutAction {
        let conversation = ChatManager.shared.createConversation(title: "Voice Command")
        return .startVoiceInput(conversation.id)
    }

    private func handleOpenProject(_ intent: OpenProjectIntent) async throws -> ShortcutAction {
        guard let projectIDString = intent.projectID,
              let projectID = UUID(uuidString: projectIDString) else {
            throw ShortcutError.invalidParameter
        }

        return .openProject(projectID)
    }
}

// MARK: - Intents

class StartConversationIntent: INIntent {
    override var suggestedInvocationPhrase: String? {
        get { "Start a THEA conversation" }
        set { super.suggestedInvocationPhrase = newValue }
    }
}

class AskQuestionIntent: INIntent {
    @NSManaged var question: String?

    override var suggestedInvocationPhrase: String? {
        get { "Ask THEA a question" }
        set { super.suggestedInvocationPhrase = newValue }
    }
}

class VoiceCommandIntent: INIntent {
    override var suggestedInvocationPhrase: String? {
        get { "Talk to THEA" }
        set { super.suggestedInvocationPhrase = newValue }
    }
}

class OpenProjectIntent: INIntent {
    @NSManaged var projectName: String?
    @NSManaged var projectID: String?

    override var suggestedInvocationPhrase: String? {
        get { "Open project in THEA" }
        set { super.suggestedInvocationPhrase = newValue }
    }
}

// MARK: - Shortcut Actions

enum ShortcutAction {
    case openConversation(UUID)
    case openProject(UUID)
    case startVoiceInput(UUID)
}

enum ShortcutError: LocalizedError {
    case unsupportedIntent
    case missingParameter
    case invalidParameter

    var errorDescription: String? {
        switch self {
        case .unsupportedIntent:
            return "This shortcut is not supported"
        case .missingParameter:
            return "Required parameter is missing"
        case .invalidParameter:
            return "Invalid parameter value"
        }
    }
}
