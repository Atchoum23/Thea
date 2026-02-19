//
//  ShortcutsService.swift
//  Thea
//
//  Advanced Shortcuts automation and Siri integration
//

import AppIntents
import Foundation
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
    nonisolated(unsafe) static var title: LocalizedStringResource = "Ask Thea with Context"
    nonisolated(unsafe) static var description: IntentDescription = "Ask Thea a question with additional context from files or clipboard"

    // periphery:ignore - Reserved: AskWithContextIntent type reserved for future feature activation
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

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
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
                let data = file.data
                if let text = String(data: data, encoding: .utf8) {
                    fullContext += "\n\nFile (\(file.filename)):\n\(text)"
                }
            }
        }

        // Route through AI provider for real response
        let response = await ShortcutsAIHelper.chat(prompt: fullContext)
        return .result(value: response)
    }
}

// MARK: - Shared AI Helper for Shortcuts

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
enum ShortcutsAIHelper {
    @MainActor
    static func chat(prompt: String) async -> String {
        guard let provider = ProviderRegistry.shared.getProvider(
            id: SettingsManager.shared.defaultProvider
        ) else {
            return "No AI provider configured. Please set up a provider in Thea Settings."
        }

        let message = AIMessage(
            id: UUID(),
            conversationID: UUID(),
            role: .user,
            content: .text(prompt),
            timestamp: Date(),
            model: ""
        )

        do {
            var responseText = ""
            let stream = try await provider.chat(
                messages: [message],
                model: "",
                stream: false
            )
            for try await chunk in stream {
                if case .delta(let text) = chunk.type {
                    responseText += text
                } else if case .complete(let msg) = chunk.type {
                    responseText = msg.content.textValue
                }
            }
            return responseText.isEmpty ? "I couldn't generate a response." : responseText
        } catch {
            return "Error: \(error.localizedDescription)"
        }
    }
}

// MARK: Generate Code Intent

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
struct GenerateCodeIntent: AppIntent {
    nonisolated(unsafe) static var title: LocalizedStringResource = "Generate Code"
    nonisolated(unsafe) static var description: IntentDescription = "Generate code using Thea AI"

// periphery:ignore - Reserved: GenerateCodeIntent type reserved for future feature activation

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

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        var prompt = "Generate \(language.rawValue) code for: \(description)"
        if includeComments {
            prompt += "\nInclude clear comments explaining the code."
        }
        if let framework {
            prompt += "\nUse the \(framework) framework/library."
        }
        prompt += "\nReturn only the code, no explanations outside of code comments."

        let code = await ShortcutsAIHelper.chat(prompt: prompt)
        return .result(value: code)
    }
}

// MARK: Summarize Content Intent

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
struct SummarizeContentIntent: AppIntent {
    nonisolated(unsafe) static var title: LocalizedStringResource = "Summarize Content"
    // periphery:ignore - Reserved: SummarizeContentIntent type reserved for future feature activation
    nonisolated(unsafe) static var description: IntentDescription = "Summarize text, files, or web pages"

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

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        var textToSummarize: String
        switch contentType {
        case .text:
            textToSummarize = content ?? ""
        case .url:
            if let url {
                let (data, _) = try await URLSession.shared.data(from: url)
                textToSummarize = String(data: data, encoding: .utf8) ?? ""
            } else {
                textToSummarize = ""
            }
        case .file:
            if let data = file?.data, let text = String(data: data, encoding: .utf8) {
                textToSummarize = text
            } else {
                textToSummarize = ""
            }
        }

        guard !textToSummarize.isEmpty else {
            return .result(value: "No content provided to summarize.")
        }

        let styleInstructions: String
        switch style ?? .paragraph {
        case .bullets: styleInstructions = "Format as bullet points."
        case .paragraph: styleInstructions = "Write as a concise paragraph."
        case .keyPoints: styleInstructions = "List only the key points."
        case .executive: styleInstructions = "Write an executive summary suitable for decision makers."
        }

        let lengthInstruction = maxLength.map { "Keep the summary under \($0) words." } ?? ""
        let prompt = "Summarize the following content. \(styleInstructions) \(lengthInstruction)\n\n\(textToSummarize)"

        let summary = await ShortcutsAIHelper.chat(prompt: prompt)
        return .result(value: summary)
    }
}

// MARK: Translate Intent

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
struct AutomationTranslateIntent: AppIntent {
    // periphery:ignore - Reserved: AutomationTranslateIntent type reserved for future feature activation
    nonisolated(unsafe) static var title: LocalizedStringResource = "Translate with Thea"
    nonisolated(unsafe) static var description: IntentDescription = "Translate text to another language"

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

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        var prompt = "Translate the following text to \(targetLanguage.rawValue)."
        if let sourceLanguage {
            prompt += " The source language is \(sourceLanguage.rawValue)."
        }
        if preserveFormatting {
            prompt += " Preserve all formatting (line breaks, bullet points, etc.)."
        }
        prompt += " Return ONLY the translated text, nothing else.\n\n\(text)"

        let translation = await ShortcutsAIHelper.chat(prompt: prompt)
        return .result(value: translation)
    }
}

// MARK: Create Automation Intent

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
// periphery:ignore - Reserved: CreateAutomationIntent type reserved for future feature activation
struct CreateAutomationIntent: AppIntent {
    nonisolated(unsafe) static var title: LocalizedStringResource = "Create Thea Automation"
    nonisolated(unsafe) static var description: IntentDescription = "Create a new automation workflow"

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
        .result()
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
    case brief
    case standard
    case detailed

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
    case text
    case url
    case file

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
    case bullets
    case paragraph
    case keyPoints
    case executive

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
    case time
    case location
    case appOpen
    case focusMode
    case webhook
    case manual

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

// MARK: - Extended Shortcuts (Intents only - shortcuts registered in TheaAppIntents.swift)
