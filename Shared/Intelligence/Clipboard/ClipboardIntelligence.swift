// ClipboardIntelligence.swift
// Thea — AI-powered clipboard content analysis, categorization, and smart actions

import Foundation
import os.log

private let ciLogger = Logger(subsystem: "ai.thea.app", category: "ClipboardIntelligence")

// MARK: - Clip Category

enum ClipCategory: String, Codable, Sendable, CaseIterable {
    case code = "Code"
    case url = "URL"
    case email = "Email"
    case phone = "Phone"
    case address = "Address"
    case snippet = "Snippet"
    case credential = "Credential"
    case json = "JSON"
    case command = "Command"
    case filepath = "File Path"
    case color = "Color"
    case number = "Number"
    case date = "Date"
    case markdown = "Markdown"
    case richText = "Rich Text"
    case image = "Image"
    case file = "File"
    case text = "Text"

    var icon: String {
        switch self {
        case .code: "curlybraces"
        case .url: "link"
        case .email: "envelope"
        case .phone: "phone"
        case .address: "mappin"
        case .snippet: "doc.text"
        case .credential: "key.fill"
        case .json: "curlybraces.square"
        case .command: "terminal"
        case .filepath: "folder"
        case .color: "paintpalette"
        case .number: "number"
        case .date: "calendar"
        case .markdown: "text.badge.checkmark"
        case .richText: "textformat"
        case .image: "photo"
        case .file: "doc"
        case .text: "doc.plaintext"
        }
    }
}

// MARK: - Smart Action

struct ClipSmartAction: Identifiable, Sendable {
    let id = UUID()
    let title: String
    let icon: String
    let actionType: ClipActionType

    // periphery:ignore - Reserved: title property reserved for future feature activation
    // periphery:ignore - Reserved: icon property reserved for future feature activation
    // periphery:ignore - Reserved: actionType property reserved for future feature activation
    enum ClipActionType: String, Sendable {
        case openURL
        case composeEmail
        case callPhone
        case openMap
        case formatCode
        case pasteAsMarkdown
        case createTask
        case translateText
        case searchWeb
        case copyPlain
    }
}

// MARK: - Analysis Result

struct ClipAnalysisResult: Sendable {
    let category: ClipCategory
    let summary: String
    let suggestedActions: [ClipSmartAction]
    // periphery:ignore - Reserved: suggestedActions property reserved for future feature activation
    let tags: [String]
    // periphery:ignore - Reserved: languageHint property reserved for future feature activation
    let languageHint: String?
}

// MARK: - ClipboardIntelligence

@MainActor
final class ClipboardIntelligence {
    static let shared = ClipboardIntelligence()

    private init() {}

    // MARK: - Analysis

    /// Analyze clipboard content and return categorization, summary, and smart actions.
    func analyze(text: String?, contentType: ClipCategory? = nil, sourceApp: String? = nil) -> ClipAnalysisResult {
        guard let text, !text.isEmpty else {
            return ClipAnalysisResult(
                category: contentType ?? .text,
                summary: "",
                suggestedActions: [],
                tags: [],
                languageHint: nil
            )
        }

        let category = contentType ?? classify(text: text, sourceApp: sourceApp)
        let summary = generateSummary(text: text, category: category)
        let actions = suggestActions(text: text, category: category)
        let tags = extractTags(text: text, category: category, sourceApp: sourceApp)
        let lang = detectCodeLanguage(text: text, category: category)

        return ClipAnalysisResult(
            category: category,
            summary: summary,
            suggestedActions: actions,
            tags: tags,
            languageHint: lang
        )
    }

    // MARK: - Classification

    func classify(text: String, sourceApp: String? = nil) -> ClipCategory {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Credential detection first (highest priority)
        if isCredential(trimmed) { return .credential }

        // URL
        if isURL(trimmed) { return .url }

        // Email
        if isEmail(trimmed) { return .email }

        // Color hex
        if isColorHex(trimmed) { return .color }

        // File path
        if isFilePath(trimmed) { return .filepath }

        // JSON
        if isJSON(trimmed) { return .json }

        // Number (before phone — currency like $1,234.56 could match phone)
        if isNumber(trimmed) { return .number }

        // Date (before phone — ISO dates like 2026-02-15 could match phone)
        if isDate(trimmed) { return .date }

        // Phone (after number/date to avoid false positives)
        if isPhone(trimmed) { return .phone }

        // Markdown (before command — # headings would match command prefix)
        if isMarkdown(trimmed) { return .markdown }

        // Code (before command — code with shell-like lines should be code)
        if isCode(trimmed, sourceApp: sourceApp) { return .code }

        // Shell command
        if isCommand(trimmed, sourceApp: sourceApp) { return .command }

        // Address
        if isAddress(trimmed) { return .address }

        // Short text → snippet
        if trimmed.count < 200, !trimmed.contains("\n") {
            return .snippet
        }

        return .text
    }

    // MARK: - Pattern Matching

    private func isURL(_ text: String) -> Bool {
        let single = text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        guard single.count == 1, let candidate = single.first else { return false }
        if candidate.hasPrefix("http://") || candidate.hasPrefix("https://") || candidate.hasPrefix("ftp://") {
            return URL(string: candidate) != nil
        }
        // Domain-like patterns: example.com, foo.bar.io
        let domainPattern = "^[a-zA-Z0-9][a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}(/.*)?$"
        return candidate.range(of: domainPattern, options: .regularExpression) != nil
    }

    private func isEmail(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.contains(" "), trimmed.count < 254 else { return false }
        let pattern = "^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        return trimmed.range(of: pattern, options: .regularExpression) != nil
    }

    private func isPhone(_ text: String) -> Bool {
        let digits = text.filter(\.isNumber)
        guard digits.count >= 7, digits.count <= 15 else { return false }
        let pattern = "^[+]?[\\d\\s().-]{7,20}$"
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
            .range(of: pattern, options: .regularExpression) != nil
    }

    private func isColorHex(_ text: String) -> Bool {
        let pattern = "^#[0-9a-fA-F]{3,8}$"
        return text.range(of: pattern, options: .regularExpression) != nil
    }

    private func isFilePath(_ text: String) -> Bool {
        text.hasPrefix("/") || text.hasPrefix("~/") || text.hasPrefix("file://")
    }

    private func isJSON(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (trimmed.hasPrefix("{") && trimmed.hasSuffix("}"))
            || (trimmed.hasPrefix("[") && trimmed.hasSuffix("]")) else { return false }
        do {
            try JSONSerialization.jsonObject(with: Data(trimmed.utf8))
            return true
        } catch {
            return false
        }
    }

    private func isCommand(_ text: String, sourceApp: String?) -> Bool {
        let codeApps = ["Terminal", "iTerm2", "Warp", "Alacritty", "kitty"]
        if let app = sourceApp, codeApps.contains(app) { return true }

        let lines = text.components(separatedBy: "\n").map {
            $0.trimmingCharacters(in: .whitespaces)
        }
        let commandPrefixes = ["$", "#", "%", "❯", "➜", ">>>"]
        let shellCommands = ["cd ", "ls ", "rm ", "mv ", "cp ", "mkdir ", "cat ", "grep ",
                             "git ", "brew ", "npm ", "yarn ", "pip ", "docker ", "kubectl ",
                             "swift ", "xcodebuild ", "make ", "curl ", "wget ", "ssh ",
                             "sudo ", "chmod ", "chown ", "find ", "awk ", "sed "]

        if let first = lines.first {
            if commandPrefixes.contains(where: { first.hasPrefix($0) }) { return true }
            if shellCommands.contains(where: { first.hasPrefix($0) }) { return true }
        }
        return false
    }

    private func isCode(_ text: String, sourceApp: String?) -> Bool {
        let codeApps = ["Xcode", "VS Code", "Visual Studio Code", "Cursor",
                        "Sublime Text", "Nova", "BBEdit", "TextMate"]
        if let app = sourceApp, codeApps.contains(app) { return true }

        let codeSignals = [
            "func ", "let ", "var ", "class ", "struct ", "enum ", "import ",
            "def ", "return ", "if (", "for (", "while (",
            "function ", "const ", "=>", "async ", "await ",
            "public ", "private ", "static ", "void ", "int ",
            "println", "printf", "console.log", "print(",
            "};", "});", "//", "/*", "*/", "#include", "#import",
            "<html", "<body", "<div", "<span", "<head", "<!DOCTYPE"
        ]

        let matchCount = codeSignals.filter { text.contains($0) }.count
        return matchCount >= 2
    }

    private func isMarkdown(_ text: String) -> Bool {
        let lines = text.components(separatedBy: "\n")
        let mdSignals = ["# ", "## ", "### ", "- [ ] ", "- [x] ", "```", "**", "~~", "[]("]
        let matchCount = mdSignals.filter { signal in
            lines.contains { $0.trimmingCharacters(in: .whitespaces).hasPrefix(signal)
                || $0.contains(signal) }
        }.count
        return matchCount >= 2
    }

    private func isAddress(_ text: String) -> Bool {
        let patterns = [
            "\\d+\\s+[A-Za-z]+\\s+(Street|St|Avenue|Ave|Road|Rd|Boulevard|Blvd|Lane|Ln|Drive|Dr)",
            "\\b\\d{4,5}\\b.*\\b[A-Z][a-z]+\\b", // Postal code + city (Swiss/EU)
            "\\b(rue|avenue|chemin|place|boulevard)\\s+",
            "\\b\\d{5}\\s+[A-Z]" // US/EU zip + city
        ]
        return patterns.contains { text.range(of: $0, options: [.regularExpression, .caseInsensitive]) != nil }
    }

    private func isCredential(_ text: String) -> Bool {
        let credPatterns = [
            "^sk-[A-Za-z0-9]{20,}$",
            "^ghp_[A-Za-z0-9]{36}$",
            "^AKIA[0-9A-Z]{16}$",
            "^xox[bpas]-[A-Za-z0-9-]+$",
            "(?i)(password|secret|token|api[_-]?key)\\s*[:=]\\s*[\"']?\\S{8,}"
        ]
        return credPatterns.contains { text.range(of: $0, options: .regularExpression) != nil }
    }

    private func isNumber(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count < 30 else { return false }
        // Reject date-like patterns (multiple dots/hyphens separating groups)
        let dotCount = trimmed.filter { $0 == "." }.count
        let hyphenCount = trimmed.filter { $0 == "-" }.count
        if dotCount >= 2 || hyphenCount >= 2 { return false }
        return Double(trimmed.replacingOccurrences(of: ",", with: "")) != nil
            || trimmed.range(of: "^[$€£¥₽CHF]?\\s?[\\d,.]+\\s?[$€£¥₽CHF]?$", options: .regularExpression) != nil
    }

    private func isDate(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count < 40 else { return false }
        let datePatterns = [
            "\\d{4}-\\d{2}-\\d{2}",
            "\\d{1,2}/\\d{1,2}/\\d{2,4}",
            "\\d{1,2}\\.\\d{1,2}\\.\\d{2,4}",
            "(?i)(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)\\w*\\s+\\d{1,2},?\\s+\\d{4}"
        ]
        return datePatterns.contains { trimmed.range(of: $0, options: .regularExpression) != nil }
    }

    // MARK: - Summary Generation

    func generateSummary(text: String, category: ClipCategory) -> String {
        let maxLen = 120
        switch category {
        case .url:
            if let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)) {
                return url.host ?? String(text.prefix(maxLen))
            }
            return String(text.prefix(maxLen))
        case .email:
            return "Email: \(text.trimmingCharacters(in: .whitespacesAndNewlines))"
        case .phone:
            return "Phone: \(text.trimmingCharacters(in: .whitespacesAndNewlines))"
        case .json:
            return "JSON (\(text.count) chars)"
        case .code:
            let lang = detectCodeLanguage(text: text, category: .code) ?? "code"
            let lineCount = text.components(separatedBy: "\n").count
            return "\(lang) (\(lineCount) lines)"
        case .command:
            let first = text.components(separatedBy: "\n").first ?? text
            return String(first.prefix(maxLen))
        case .credential:
            return "Sensitive credential"
        case .color:
            return "Color: \(text.trimmingCharacters(in: .whitespacesAndNewlines))"
        case .filepath:
            if let last = text.components(separatedBy: "/").last, !last.isEmpty {
                return last
            }
            return String(text.prefix(maxLen))
        case .address:
            return String(text.prefix(maxLen))
        case .number:
            return "Number: \(text.trimmingCharacters(in: .whitespacesAndNewlines))"
        case .date:
            return "Date: \(text.trimmingCharacters(in: .whitespacesAndNewlines))"
        case .markdown:
            let lineCount = text.components(separatedBy: "\n").count
            return "Markdown (\(lineCount) lines)"
        default:
            return String(text.prefix(maxLen))
        }
    }

    // MARK: - Smart Actions

    func suggestActions(text: String, category: ClipCategory) -> [ClipSmartAction] {
        var actions: [ClipSmartAction] = []

        switch category {
        case .url:
            actions.append(ClipSmartAction(title: "Open URL", icon: "safari", actionType: .openURL))
            actions.append(ClipSmartAction(title: "Search Web", icon: "magnifyingglass", actionType: .searchWeb))
        case .email:
            actions.append(ClipSmartAction(title: "Compose Email", icon: "envelope", actionType: .composeEmail))
        case .phone:
            actions.append(ClipSmartAction(title: "Call", icon: "phone", actionType: .callPhone))
        case .address:
            actions.append(ClipSmartAction(title: "Open in Maps", icon: "map", actionType: .openMap))
        case .code:
            actions.append(ClipSmartAction(title: "Format Code", icon: "text.alignleft", actionType: .formatCode))
            actions.append(ClipSmartAction(title: "Copy as Plain", icon: "doc.on.doc", actionType: .copyPlain))
        case .markdown:
            actions.append(ClipSmartAction(title: "Paste as Markdown", icon: "text.badge.checkmark", actionType: .pasteAsMarkdown))
        case .command:
            actions.append(ClipSmartAction(title: "Copy as Plain", icon: "doc.on.doc", actionType: .copyPlain))
        default:
            break
        }

        // Universal actions for text content
        if text.count > 20 {
            actions.append(ClipSmartAction(title: "Create Task", icon: "checklist", actionType: .createTask))
        }
        if text.count > 5, text.count < 2000 {
            actions.append(ClipSmartAction(title: "Translate", icon: "globe", actionType: .translateText))
        }

        return actions
    }

    // MARK: - Tag Extraction

    func extractTags(text: String, category: ClipCategory, sourceApp: String?) -> [String] {
        var tags: [String] = [category.rawValue.lowercased()]

        if let app = sourceApp {
            tags.append(app.lowercased())
        }

        // Detect programming language
        if category == .code, let lang = detectCodeLanguage(text: text, category: category) {
            tags.append(lang.lowercased())
        }

        // Detect format
        if text.contains("```") { tags.append("fenced-code") }
        if text.contains("<html") || text.contains("<div") { tags.append("html") }

        return Array(Set(tags)).sorted()
    }

    // MARK: - Language Detection

    func detectCodeLanguage(text: String, category: ClipCategory) -> String? {
        guard category == .code || category == .command else { return nil }

        if category == .command { return "Shell" }

        let indicators: [(String, [String])] = [
            ("Swift", ["import Foundation", "import SwiftUI", "import UIKit",
                       "@Observable", "@MainActor", "@Model", "func ", "let ", "var ",
                       "guard ", "struct ", "enum ", "protocol "]),
            ("Python", ["def ", "import ", "from ", "print(", "self.", "__init__",
                        "if __name__", "elif ", "lambda "]),
            ("JavaScript", ["const ", "let ", "function ", "=>", "console.log",
                            "require(", "module.exports", "async ", "Promise"]),
            ("TypeScript", ["interface ", ": string", ": number", ": boolean",
                            "export ", "import ", "type "]),
            ("Rust", ["fn ", "let mut ", "impl ", "pub ", "use ", "mod ", "&str", "Vec<"]),
            ("Go", ["func ", "package ", "import ", "fmt.", "err != nil",
                    "go func", "chan ", "defer "]),
            ("Java", ["public class", "private ", "System.out", "import java.",
                      "void ", "String[]"]),
            ("C++", ["#include", "std::", "cout", "int main", "nullptr", "template<"]),
            ("HTML", ["<html", "<div", "<span", "<body", "<head", "<!DOCTYPE"]),
            ("CSS", ["{", ":", ";", "margin:", "padding:", "display:", "color:",
                     "font-size:", "background:"])
        ]

        var bestMatch = ""
        var bestScore = 0

        for (lang, keywords) in indicators {
            let score = keywords.filter { text.contains($0) }.count
            if score > bestScore {
                bestScore = score
                bestMatch = lang
            }
        }

        return bestScore >= 2 ? bestMatch : nil
    }

    // MARK: - Process Entry (called after clipboard capture)

    func processEntry(_ entry: TheaClipEntry) {
        guard SettingsManager.shared.clipboardAutoCategorize else { return }

        let result = analyze(
            text: entry.textContent,
            sourceApp: entry.sourceAppName
        )

        entry.aiCategory = result.category.rawValue
        entry.aiSummary = result.summary

        // Merge tags (keep existing, add new)
        let existingTags = Set(entry.tags)
        let newTags = result.tags.filter { !existingTags.contains($0) }
        if !newTags.isEmpty {
            entry.tags.append(contentsOf: newTags)
        }

        ciLogger.debug("Categorized entry as \(result.category.rawValue)")
    }
}
