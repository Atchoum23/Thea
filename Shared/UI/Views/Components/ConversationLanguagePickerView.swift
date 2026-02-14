import SwiftUI

// MARK: - Conversation Language Picker

/// Toolbar menu for switching a conversation's language.
/// Uses ConversationLanguageService to set/toggle language per conversation.
struct ConversationLanguagePickerView: View {
    let conversation: Conversation

    private let languageService = ConversationLanguageService.shared

    var body: some View {
        Menu {
            let current = languageService.currentLanguage(for: conversation)

            if let lang = current {
                Button("\(lang.flag) \(lang.name) (Active)") {
                    languageService.setLanguage(nil, for: conversation)
                }

                Divider()
            }

            ForEach(languageService.supportedLanguages, id: \.code) { lang in
                Button {
                    languageService.setLanguage(lang.code, for: conversation)
                } label: {
                    HStack {
                        Text("\(lang.flag) \(lang.name)")
                        if current?.code == lang.code {
                            Image(systemName: "checkmark")
                                .accessibilityHidden(true)
                        }
                    }
                }
            }

            Divider()

            if current != nil {
                Button("Disable Language Override") {
                    languageService.setLanguage(nil, for: conversation)
                }
            }
        } label: {
            Image(systemName: "globe")
        }
    }
}

// MARK: - Conversation Language Badge

/// Inline badge showing the active language in the chat header.
struct ConversationLanguageBadge: View {
    let conversation: Conversation

    private let languageService = ConversationLanguageService.shared

    var body: some View {
        if let lang = languageService.currentLanguage(for: conversation) {
            HStack(spacing: 4) {
                Text("\(lang.flag) \(lang.nativeName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button {
                    languageService.setLanguage(nil, for: conversation)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.quaternary, in: Capsule())
        }
    }
}
