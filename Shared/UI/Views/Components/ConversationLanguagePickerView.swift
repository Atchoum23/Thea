import SwiftUI

// MARK: - Conversation Language Picker

/// Toolbar menu for switching a conversation's language.
/// Uses ConversationLanguageService to set/toggle language per conversation.
struct ConversationLanguagePickerView: View {
    let conversation: Conversation

    private let languageService = ConversationLanguageService.shared

    private let languages: [(code: String, name: String, flag: String)] = [
        ("en", "English", "\u{1F1FA}\u{1F1F8}"),
        ("fr", "French", "\u{1F1EB}\u{1F1F7}"),
        ("es", "Spanish", "\u{1F1EA}\u{1F1F8}"),
        ("de", "German", "\u{1F1E9}\u{1F1EA}"),
        ("it", "Italian", "\u{1F1EE}\u{1F1F9}"),
        ("pt", "Portuguese", "\u{1F1E7}\u{1F1F7}"),
        ("nl", "Dutch", "\u{1F1F3}\u{1F1F1}"),
        ("ru", "Russian", "\u{1F1F7}\u{1F1FA}"),
        ("zh", "Chinese", "\u{1F1E8}\u{1F1F3}"),
        ("ja", "Japanese", "\u{1F1EF}\u{1F1F5}"),
        ("ko", "Korean", "\u{1F1F0}\u{1F1F7}"),
        ("ar", "Arabic", "\u{1F1F8}\u{1F1E6}"),
        ("hi", "Hindi", "\u{1F1EE}\u{1F1F3}"),
        ("tr", "Turkish", "\u{1F1F9}\u{1F1F7}"),
        ("pl", "Polish", "\u{1F1F5}\u{1F1F1}"),
        ("sv", "Swedish", "\u{1F1F8}\u{1F1EA}"),
        ("da", "Danish", "\u{1F1E9}\u{1F1F0}"),
        ("no", "Norwegian", "\u{1F1F3}\u{1F1F4}"),
        ("fi", "Finnish", "\u{1F1EB}\u{1F1EE}"),
        ("el", "Greek", "\u{1F1EC}\u{1F1F7}"),
        ("he", "Hebrew", "\u{1F1EE}\u{1F1F1}"),
        ("th", "Thai", "\u{1F1F9}\u{1F1ED}"),
        ("vi", "Vietnamese", "\u{1F1FB}\u{1F1F3}"),
        ("id", "Indonesian", "\u{1F1EE}\u{1F1E9}"),
        ("ms", "Malay", "\u{1F1F2}\u{1F1FE}"),
        ("uk", "Ukrainian", "\u{1F1FA}\u{1F1E6}"),
        ("cs", "Czech", "\u{1F1E8}\u{1F1FF}")
    ]

    var body: some View {
        Menu {
            let currentCode = languageService.getLanguage(for: conversation)

            if let code = currentCode,
               let lang = languages.first(where: { $0.code == code })
            {
                Button("\(lang.flag) \(lang.name) (Active)") {
                    languageService.toggleLanguage(for: conversation)
                }

                Divider()
            }

            ForEach(languages, id: \.code) { lang in
                Button {
                    languageService.setLanguage(lang.code, for: conversation)
                } label: {
                    HStack {
                        Text("\(lang.flag) \(lang.name)")
                        if currentCode == lang.code {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }

            Divider()

            if currentCode != nil {
                Button("Disable Language Override") {
                    languageService.toggleLanguage(for: conversation)
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

    private let codeToFlag: [String: String] = [
        "en": "\u{1F1FA}\u{1F1F8}", "fr": "\u{1F1EB}\u{1F1F7}", "es": "\u{1F1EA}\u{1F1F8}",
        "de": "\u{1F1E9}\u{1F1EA}", "it": "\u{1F1EE}\u{1F1F9}", "pt": "\u{1F1E7}\u{1F1F7}",
        "nl": "\u{1F1F3}\u{1F1F1}", "ru": "\u{1F1F7}\u{1F1FA}", "zh": "\u{1F1E8}\u{1F1F3}",
        "ja": "\u{1F1EF}\u{1F1F5}", "ko": "\u{1F1F0}\u{1F1F7}", "ar": "\u{1F1F8}\u{1F1E6}",
        "hi": "\u{1F1EE}\u{1F1F3}", "tr": "\u{1F1F9}\u{1F1F7}", "pl": "\u{1F1F5}\u{1F1F1}",
        "sv": "\u{1F1F8}\u{1F1EA}", "da": "\u{1F1E9}\u{1F1F0}", "no": "\u{1F1F3}\u{1F1F4}",
        "fi": "\u{1F1EB}\u{1F1EE}", "el": "\u{1F1EC}\u{1F1F7}", "he": "\u{1F1EE}\u{1F1F1}",
        "th": "\u{1F1F9}\u{1F1ED}", "vi": "\u{1F1FB}\u{1F1F3}", "id": "\u{1F1EE}\u{1F1E9}",
        "ms": "\u{1F1F2}\u{1F1FE}", "uk": "\u{1F1FA}\u{1F1E6}", "cs": "\u{1F1E8}\u{1F1FF}"
    ]

    var body: some View {
        if let code = languageService.getLanguage(for: conversation) {
            let flag = codeToFlag[code] ?? ""
            let name = Locale.current.localizedString(forLanguageCode: code) ?? code

            HStack(spacing: 4) {
                Text("\(flag) \(name)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button {
                    languageService.toggleLanguage(for: conversation)
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
