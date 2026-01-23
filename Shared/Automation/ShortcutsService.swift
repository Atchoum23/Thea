//
//  ShortcutsService.swift
//  Thea
//
//  Advanced Shortcuts automation and Siri integration
//

import Foundation
import AppIntents
import Intents

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

// MARK: - Extended App Intents

// MARK: Ask with Context Intent

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
struct AskWithContextIntent: AppIntent {
    static var title: LocalizedStringResource = "Ask Thea with Context"
    static var description: IntentDescription = "Ask Thea a question with additional context from files or clipboard"

    @Parameter(title: "Question")
    var question: String

    @Parameter(title: "Include Clipboard", default: false)
    var includeClipboard: Bool

    @Parameter(title: "Context Files")
    var contextFiles: [IntentFile]?

    @Parameter(title: "AI Model")
    var model: AIModelParameter?

    @Parameter(title: "Response Length")
    var responseLength: ResponseLengthParameter?

    static var parameterSummary: some ParameterSummary {
        Summary("Ask \(\.$question)") {
            \.$includeClipboard
            \.$contextFiles
            \.$model
            \.$responseLength
        }
    }

    func perform() async throws -> some ReturningIntent<String> {
        var fullContext = question

        // Add clipboard content if requested
        if includeClipboard {
            #if os(iOS)
            if let clipboardText = UIPasteboard.general.string {
                fullContext += "\n\nClipboard content:\n\(clipboardText)"
            }
            #elseif os(macOS)
            if let clipboardText = NSPasteboard.general.string(forType: .string) {
                fullContext += "\n\nClipboard content:\n\(clipboardText)"
            }
            #endif
        }

        // Add file contents
        if let files = contextFiles {
            for file in files {
                if let data = file.data, let text = String(data: data, encoding: .utf8) {
                    fullContext += "\n\nFile (\(file.filename)):\n\(text)"
                }
            }
        }

        // Process with AI (placeholder)
        let response = "AI response to: \(fullContext.prefix(100))..."

        return .result(value: response)
    }
}

// MARK: Generate Code Intent

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
struct GenerateCodeIntent: AppIntent {
    static var title: LocalizedStringResource = "Generate Code"
    static var description: IntentDescription = "Generate code using Thea AI"

    @Parameter(title: "Description")
    var description: String

    @Parameter(title: "Programming Language")
    var language: ProgrammingLanguageParameter

    @Parameter(title: "Include Comments", default: true)
    var includeComments: Bool

    @Parameter(title: "Framework/Library")
    var framework: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Generate \(\.$language) code for \(\.$description)") {
            \.$includeComments
            \.$framework
        }
    }

    func perform() async throws -> some ReturningIntent<String> {
        // Code generation logic would go here
        let code = """
        // Generated \(language.rawValue) code
        // Description: \(description)

        func generatedFunction() {
            // Implementation
        }
        """

        return .result(value: code)
    }
}

// MARK: Summarize Content Intent

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
struct SummarizeContentIntent: AppIntent {
    static var title: LocalizedStringResource = "Summarize Content"
    static var description: IntentDescription = "Summarize text, files, or web pages"

    @Parameter(title: "Content Type")
    var contentType: ContentTypeParameter

    @Parameter(title: "Content")
    var content: String?

    @Parameter(title: "URL")
    var url: URL?

    @Parameter(title: "File")
    var file: IntentFile?

    @Parameter(title: "Summary Style")
    var style: SummaryStyleParameter?

    @Parameter(title: "Maximum Length")
    var maxLength: Int?

    static var parameterSummary: some ParameterSummary {
        Summary("Summarize \(\.$contentType)") {
            \.$content
            \.$url
            \.$file
            \.$style
            \.$maxLength
        }
    }

    func perform() async throws -> some ReturningIntent<String> {
        let textToSummarize: String

        switch contentType {
        case .text:
            textToSummarize = content ?? ""
        case .url:
            // Fetch URL content
            textToSummarize = "Content from URL: \(url?.absoluteString ?? "")"
        case .file:
            if let data = file?.data, let text = String(data: data, encoding: .utf8) {
                textToSummarize = text
            } else {
                textToSummarize = ""
            }
        }

        let summary = "Summary of: \(textToSummarize.prefix(200))..."
        return .result(value: summary)
    }
}

// MARK: Translate Intent

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
struct TranslateTextIntent: AppIntent {
    static var title: LocalizedStringResource = "Translate with Thea"
    static var description: IntentDescription = "Translate text to another language"

    @Parameter(title: "Text")
    var text: String

    @Parameter(title: "Target Language")
    var targetLanguage: LanguageParameter

    @Parameter(title: "Source Language")
    var sourceLanguage: LanguageParameter?

    @Parameter(title: "Preserve Formatting", default: true)
    var preserveFormatting: Bool

    static var parameterSummary: some ParameterSummary {
        Summary("Translate \(\.$text) to \(\.$targetLanguage)") {
            \.$sourceLanguage
            \.$preserveFormatting
        }
    }

    func perform() async throws -> some ReturningIntent<String> {
        let translation = "Translated text: \(text)"
        return .result(value: translation)
    }
}

// MARK: Create Automation Intent

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
struct CreateAutomationIntent: AppIntent {
    static var title: LocalizedStringResource = "Create Thea Automation"
    static var description: IntentDescription = "Create a new automation workflow"

    @Parameter(title: "Automation Name")
    var name: String

    @Parameter(title: "Trigger Type")
    var triggerType: AutomationTriggerParameter

    @Parameter(title: "Action")
    var action: String

    @Parameter(title: "Enabled", default: true)
    var enabled: Bool

    func perform() async throws -> some IntentResult {
        // Create automation
        return .result()
    }
}

// MARK: - Parameter Types

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
enum AIModelParameter: String, AppEnum {
    case claude = "Claude"
    case gpt4 = "GPT-4"
    case gemini = "Gemini"
    case local = "Local"

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "AI Model")
    }

    static var caseDisplayRepresentations: [AIModelParameter: DisplayRepresentation] {
        [
            .claude: "Claude (Anthropic)",
            .gpt4: "GPT-4 (OpenAI)",
            .gemini: "Gemini (Google)",
            .local: "Local Model"
        ]
    }
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
enum ResponseLengthParameter: String, AppEnum {
    case brief = "brief"
    case standard = "standard"
    case detailed = "detailed"

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Response Length")
    }

    static var caseDisplayRepresentations: [ResponseLengthParameter: DisplayRepresentation] {
        [
            .brief: "Brief (1-2 sentences)",
            .standard: "Standard",
            .detailed: "Detailed (comprehensive)"
        ]
    }
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
enum ProgrammingLanguageParameter: String, AppEnum {
    case swift = "Swift"
    case python = "Python"
    case javascript = "JavaScript"
    case typescript = "TypeScript"
    case rust = "Rust"
    case go = "Go"
    case java = "Java"
    case csharp = "C#"
    case cpp = "C++"
    case ruby = "Ruby"

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Programming Language")
    }

    static var caseDisplayRepresentations: [ProgrammingLanguageParameter: DisplayRepresentation] {
        [
            .swift: "Swift",
            .python: "Python",
            .javascript: "JavaScript",
            .typescript: "TypeScript",
            .rust: "Rust",
            .go: "Go",
            .java: "Java",
            .csharp: "C#",
            .cpp: "C++",
            .ruby: "Ruby"
        ]
    }
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
enum ContentTypeParameter: String, AppEnum {
    case text = "text"
    case url = "url"
    case file = "file"

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Content Type")
    }

    static var caseDisplayRepresentations: [ContentTypeParameter: DisplayRepresentation] {
        [
            .text: "Text",
            .url: "URL/Web Page",
            .file: "File"
        ]
    }
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
enum SummaryStyleParameter: String, AppEnum {
    case bullets = "bullets"
    case paragraph = "paragraph"
    case keyPoints = "keyPoints"
    case executive = "executive"

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Summary Style")
    }

    static var caseDisplayRepresentations: [SummaryStyleParameter: DisplayRepresentation] {
        [
            .bullets: "Bullet Points",
            .paragraph: "Paragraph",
            .keyPoints: "Key Points",
            .executive: "Executive Summary"
        ]
    }
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
enum LanguageParameter: String, AppEnum {
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

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Language")
    }

    static var caseDisplayRepresentations: [LanguageParameter: DisplayRepresentation] {
        [
            .english: "English",
            .spanish: "Spanish",
            .french: "French",
            .german: "German",
            .italian: "Italian",
            .portuguese: "Portuguese",
            .chinese: "Chinese",
            .japanese: "Japanese",
            .korean: "Korean",
            .arabic: "Arabic"
        ]
    }
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
enum AutomationTriggerParameter: String, AppEnum {
    case time = "time"
    case location = "location"
    case appOpen = "appOpen"
    case focusMode = "focusMode"
    case webhook = "webhook"
    case manual = "manual"

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Trigger Type")
    }

    static var caseDisplayRepresentations: [AutomationTriggerParameter: DisplayRepresentation] {
        [
            .time: "Time-based",
            .location: "Location",
            .appOpen: "App Open",
            .focusMode: "Focus Mode",
            .webhook: "Webhook",
            .manual: "Manual"
        ]
    }
}

// MARK: - Extended Shortcuts Provider

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
struct TheaExtendedShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AskWithContextIntent(),
            phrases: [
                "Ask \(.applicationName) with context",
                "Ask \(.applicationName) about my clipboard"
            ],
            shortTitle: "Ask with Context",
            systemImageName: "doc.text.magnifyingglass"
        )

        AppShortcut(
            intent: GenerateCodeIntent(),
            phrases: [
                "Generate code with \(.applicationName)",
                "Write \(\.$language) code with \(.applicationName)"
            ],
            shortTitle: "Generate Code",
            systemImageName: "chevron.left.forwardslash.chevron.right"
        )

        AppShortcut(
            intent: SummarizeContentIntent(),
            phrases: [
                "Summarize with \(.applicationName)",
                "Get a summary from \(.applicationName)"
            ],
            shortTitle: "Summarize",
            systemImageName: "doc.text"
        )

        AppShortcut(
            intent: TranslateTextIntent(),
            phrases: [
                "Translate with \(.applicationName)",
                "Translate to \(\.$targetLanguage) using \(.applicationName)"
            ],
            shortTitle: "Translate",
            systemImageName: "globe"
        )
    }
}

