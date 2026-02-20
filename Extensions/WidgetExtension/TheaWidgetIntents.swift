//
//  TheaWidgetIntents.swift
//  TheaWidgetExtension
//
//  AAB3-1: AppIntents for widget interactive / configurable actions.
//  Enables AppIntentConfiguration on widgets (replaces StaticConfiguration for memory widget).
//

import AppIntents
import WidgetKit

// MARK: - StartVoiceQueryIntent

/// Deep-links into Thea's voice input UI.
struct StartVoiceQueryIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Voice Query"
    static var description = IntentDescription("Open Thea and start a voice conversation.")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult & OpensIntent {
        guard let url = URL(string: "thea://voice") else { return .result() }
        return .result(opensIntent: OpenURLIntent(url))
    }
}

// MARK: - NewConversationIntent

/// Deep-links to a new conversation in Thea.
struct NewConversationIntent: AppIntent {
    static var title: LocalizedStringResource = "New Conversation"
    static var description = IntentDescription("Open Thea and start a new conversation.")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult & OpensIntent {
        guard let url = URL(string: "thea://new") else { return .result() }
        return .result(opensIntent: OpenURLIntent(url))
    }
}

// MARK: - SearchMemoryIntent

/// Configurable widget intent — user sets a topic, widget shows filtered memories.
struct SearchMemoryIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Search Memory"
    static var description = IntentDescription("Filter the memory widget by topic.")

    @Parameter(title: "Topic", default: nil)
    var topic: String?

    func perform() async throws -> some IntentResult & OpensIntent {
        let path = topic.map { "thea://memory?q=\($0.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" } ?? "thea://memory"
        guard let url = URL(string: path) else { return .result() }
        return .result(opensIntent: OpenURLIntent(url))
    }
}

// MARK: - OpenURLIntent helper

/// Minimal OpenURLIntent wrapper for use with .result(opensIntent:).
private struct OpenURLIntent: OpenIntent {
    var target: URL
    init(_ url: URL) { self.target = url }
    static var title: LocalizedStringResource = "Open URL"
    func perform() async throws -> some IntentResult { .result() }
}
