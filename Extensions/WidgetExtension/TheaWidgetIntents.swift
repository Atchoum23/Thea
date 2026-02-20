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

/// Opens Thea's voice input UI via openAppWhenRun.
struct StartVoiceQueryIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Voice Query"
    static let description = IntentDescription("Open Thea and start a voice conversation.")
    static let openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult { .result() }
}

// MARK: - NewConversationIntent

/// Opens a new conversation in Thea.
struct NewConversationIntent: AppIntent {
    static let title: LocalizedStringResource = "New Conversation"
    static let description = IntentDescription("Open Thea and start a new conversation.")
    static let openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult { .result() }
}

// MARK: - SearchMemoryIntent

/// Configurable widget intent — user sets a topic, widget shows filtered memories.
struct SearchMemoryIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Search Memory"
    static let description = IntentDescription("Filter the memory widget by topic.")

    @Parameter(title: "Topic", default: nil)
    var topic: String?
}
