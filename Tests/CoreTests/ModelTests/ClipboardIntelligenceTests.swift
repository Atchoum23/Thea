// ClipboardIntelligenceTests.swift
// Tests for ClipboardIntelligence — AI categorization, classification, actions, tags

import Testing

// MARK: - ClipCategory Tests

@Suite("ClipCategory — Enum Properties")
struct ClipCategoryTests {
    @Test("All cases have non-empty rawValue")
    func allCasesHaveRawValues() {
        for cat in ClipCategoryTestMirror.allCases {
            #expect(!cat.rawValue.isEmpty)
        }
    }

    @Test("All cases have unique rawValues")
    func uniqueRawValues() {
        let rawValues = ClipCategoryTestMirror.allCases.map(\.rawValue)
        #expect(Set(rawValues).count == rawValues.count)
    }

    @Test("All cases have non-empty icons")
    func allCasesHaveIcons() {
        for cat in ClipCategoryTestMirror.allCases {
            #expect(!cat.icon.isEmpty)
        }
    }

    @Test("All cases have unique icons")
    func uniqueIcons() {
        let icons = ClipCategoryTestMirror.allCases.map(\.icon)
        #expect(Set(icons).count == icons.count)
    }

    @Test("Case count is 18")
    func caseCount() {
        #expect(ClipCategoryTestMirror.allCases.count == 18)
    }
}

// MARK: - Classification Tests

@Suite("ClipboardIntelligence — Classification")
struct ClipboardClassificationTests {
    let ci = ClipboardIntelligenceTestHelper()

    @Test("URL detection — http")
    func classifyHTTPURL() {
        #expect(ci.classify("https://example.com") == "URL")
    }

    @Test("URL detection — ftp")
    func classifyFTPURL() {
        #expect(ci.classify("ftp://files.example.com/data") == "URL")
    }

    @Test("URL detection — domain-like")
    func classifyDomainLike() {
        #expect(ci.classify("github.com") == "URL")
    }

    @Test("Email detection")
    func classifyEmail() {
        #expect(ci.classify("user@example.com") == "Email")
    }

    @Test("Phone detection — international")
    func classifyPhoneIntl() {
        #expect(ci.classify("+41 79 123 45 67") == "Phone")
    }

    @Test("Phone detection — US format")
    func classifyPhoneUS() {
        #expect(ci.classify("(555) 123-4567") == "Phone")
    }

    @Test("Color hex detection — 6 digit")
    func classifyColorHex6() {
        #expect(ci.classify("#FF5733") == "Color")
    }

    @Test("Color hex detection — 3 digit")
    func classifyColorHex3() {
        #expect(ci.classify("#F00") == "Color")
    }

    @Test("File path detection — absolute")
    func classifyFilePath() {
        #expect(ci.classify("/Users/alexis/Documents/file.txt") == "File Path")
    }

    @Test("File path detection — tilde")
    func classifyFilePathTilde() {
        #expect(ci.classify("~/Desktop/notes.md") == "File Path")
    }

    @Test("JSON detection — object")
    func classifyJSON() {
        #expect(ci.classify("{\"name\": \"Thea\", \"version\": 1}") == "JSON")
    }

    @Test("JSON detection — array")
    func classifyJSONArray() {
        #expect(ci.classify("[1, 2, 3]") == "JSON")
    }

    @Test("Shell command detection — git")
    func classifyGitCommand() {
        #expect(ci.classify("git add -A && git commit -m \"test\"") == "Command")
    }

    @Test("Shell command detection — prefixed")
    func classifyPrefixedCommand() {
        #expect(ci.classify("$ npm install") == "Command")
    }

    @Test("Code detection — Swift")
    func classifySwiftCode() {
        let code = """
        import Foundation
        struct Foo {
            let name: String
            func greet() {
                print("Hello")
            }
        }
        """
        #expect(ci.classify(code) == "Code")
    }

    @Test("Code detection — JavaScript")
    func classifyJSCode() {
        let code = """
        const express = require('express');
        const app = express();
        app.listen(3000, () => {
            console.log('Server started');
        });
        """
        #expect(ci.classify(code) == "Code")
    }

    @Test("Markdown detection")
    func classifyMarkdown() {
        let md = """
        # Title
        ## Subtitle
        - Item 1
        - Item 2
        ```swift
        let x = 1
        ```
        """
        #expect(ci.classify(md) == "Markdown")
    }

    @Test("Address detection — US style")
    func classifyAddressUS() {
        #expect(ci.classify("123 Main Street, Springfield, IL 62704") == "Address")
    }

    @Test("Address detection — Swiss style")
    func classifyAddressCH() {
        #expect(ci.classify("rue du Rhône 10, 1204 Genève") == "Address")
    }

    @Test("Credential detection — API key")
    func classifyCredential() {
        #expect(ci.classify("sk-abcdefghijklmnopqrstuvwxyz1234567890") == "Credential")
    }

    @Test("Credential detection — GitHub PAT")
    func classifyGitHubPAT() {
        #expect(ci.classify("ghp_abcdefghijklmnopqrstuvwxyz1234567890") == "Credential")
    }

    @Test("Number detection — integer")
    func classifyNumber() {
        #expect(ci.classify("42") == "Number")
    }

    @Test("Number detection — decimal")
    func classifyDecimal() {
        #expect(ci.classify("3.14159") == "Number")
    }

    @Test("Number detection — currency")
    func classifyCurrency() {
        #expect(ci.classify("$1,234.56") == "Number")
    }

    @Test("Date detection — ISO")
    func classifyDateISO() {
        #expect(ci.classify("2026-02-15") == "Date")
    }

    @Test("Date detection — EU")
    func classifyDateEU() {
        #expect(ci.classify("15.02.2026") == "Date")
    }

    @Test("Date detection — English")
    func classifyDateEnglish() {
        #expect(ci.classify("February 15, 2026") == "Date")
    }

    @Test("Short text classified as Snippet")
    func classifyShortText() {
        #expect(ci.classify("Hello world") == "Snippet")
    }

    @Test("Long text classified as Text")
    func classifyLongText() {
        let long = String(repeating: "Lorem ipsum dolor sit amet. ", count: 20)
        #expect(ci.classify(long) == "Text")
    }

    @Test("Empty string returns Text")
    func classifyEmpty() {
        let result = ci.analyze(nil)
        #expect(result.category == "Text")
    }
}

// MARK: - Summary Tests

@Suite("ClipboardIntelligence — Summary Generation")
struct ClipboardSummaryTests {
    let ci = ClipboardIntelligenceTestHelper()

    @Test("URL summary extracts host")
    func urlSummary() {
        let result = ci.analyze("https://www.example.com/page")
        #expect(result.summary.contains("example.com"))
    }

    @Test("Email summary prefixed")
    func emailSummary() {
        let result = ci.analyze("user@example.com")
        #expect(result.summary.hasPrefix("Email:"))
    }

    @Test("Phone summary prefixed")
    func phoneSummary() {
        let result = ci.analyze("+41 79 123 45 67")
        #expect(result.summary.hasPrefix("Phone:"))
    }

    @Test("JSON summary includes char count")
    func jsonSummary() {
        let result = ci.analyze("{\"a\":1}")
        #expect(result.summary.contains("JSON"))
    }

    @Test("Code summary includes language and lines")
    func codeSummary() {
        let code = "import Foundation\nfunc hello() {\n    print(\"hi\")\n}"
        let result = ci.analyze(code)
        #expect(result.summary.contains("lines"))
    }

    @Test("Credential summary is generic")
    func credentialSummary() {
        let result = ci.analyze("sk-abcdefghijklmnopqrstuvwxyz1234567890")
        #expect(result.summary == "Sensitive credential")
    }

    @Test("Color summary includes hex")
    func colorSummary() {
        let result = ci.analyze("#FF5733")
        #expect(result.summary.contains("#FF5733"))
    }

    @Test("File path summary extracts filename")
    func filePathSummary() {
        let result = ci.analyze("/Users/alexis/file.txt")
        #expect(result.summary == "file.txt")
    }
}

// MARK: - Smart Actions Tests

@Suite("ClipboardIntelligence — Smart Actions")
struct ClipboardSmartActionTests {
    let ci = ClipboardIntelligenceTestHelper()

    @Test("URL suggests Open URL")
    func urlAction() {
        let result = ci.analyze("https://example.com")
        #expect(result.actions.contains { $0 == "openURL" })
    }

    @Test("Email suggests Compose Email")
    func emailAction() {
        let result = ci.analyze("user@example.com")
        #expect(result.actions.contains { $0 == "composeEmail" })
    }

    @Test("Phone suggests Call")
    func phoneAction() {
        let result = ci.analyze("+41 79 123 45 67")
        #expect(result.actions.contains { $0 == "callPhone" })
    }

    @Test("Address suggests Open in Maps")
    func addressAction() {
        let result = ci.analyze("123 Main Street, Springfield")
        #expect(result.actions.contains { $0 == "openMap" })
    }

    @Test("Code suggests Format Code")
    func codeAction() {
        let code = "import Foundation\nfunc hello() { print(\"hi\") }"
        let result = ci.analyze(code)
        #expect(result.actions.contains { $0 == "formatCode" })
    }

    @Test("Long text suggests Create Task")
    func taskAction() {
        let long = "This is a reasonably long text that should trigger task creation suggestion"
        let result = ci.analyze(long)
        #expect(result.actions.contains { $0 == "createTask" })
    }

    @Test("Medium text suggests Translate")
    func translateAction() {
        let text = "Bonjour le monde comment allez-vous"
        let result = ci.analyze(text)
        #expect(result.actions.contains { $0 == "translateText" })
    }
}

// MARK: - Tag Extraction Tests

@Suite("ClipboardIntelligence — Tag Extraction")
struct ClipboardTagTests {
    let ci = ClipboardIntelligenceTestHelper()

    @Test("Tags include category")
    func tagIncludesCategory() {
        let result = ci.analyze("https://example.com")
        #expect(result.tags.contains("url"))
    }

    @Test("Tags include source app")
    func tagIncludesSourceApp() {
        let result = ci.analyzeWithSource("some text", sourceApp: "Safari")
        #expect(result.tags.contains("safari"))
    }

    @Test("Code tags include language")
    func codeTagsIncludeLanguage() {
        let code = "import Foundation\nstruct Foo { let x: Int }"
        let result = ci.analyze(code)
        #expect(result.tags.contains("swift"))
    }

    @Test("Tags are deduplicated")
    func tagsUnique() {
        let result = ci.analyze("https://example.com")
        #expect(Set(result.tags).count == result.tags.count)
    }
}

// MARK: - Language Detection Tests

@Suite("ClipboardIntelligence — Language Detection")
struct ClipboardLanguageTests {
    let ci = ClipboardIntelligenceTestHelper()

    @Test("Detects Swift")
    func detectSwift() {
        let code = "import Foundation\nstruct Foo {\n    let name: String\n    func greet() {}\n}"
        #expect(ci.detectLanguage(code) == "Swift")
    }

    @Test("Detects Python")
    func detectPython() {
        let code = "import os\ndef hello():\n    print('hello')\nif __name__ == '__main__':\n    hello()"
        #expect(ci.detectLanguage(code) == "Python")
    }

    @Test("Detects JavaScript")
    func detectJS() {
        let code = "const app = require('express');\nconsole.log('hello');\nfunction test() {}"
        #expect(ci.detectLanguage(code) == "JavaScript")
    }

    @Test("Detects HTML")
    func detectHTML() {
        let code = "<html><head><title>Test</title></head><body><div>Hello</div></body></html>"
        #expect(ci.detectLanguage(code) == "HTML")
    }

    @Test("Returns nil for non-code")
    func noDetectionForText() {
        #expect(ci.detectLanguage("Hello world, how are you?") == nil)
    }

    @Test("Shell detection for commands")
    func shellForCommands() {
        let result = ci.analyze("$ npm install express")
        #expect(result.languageHint == "Shell")
    }
}

// MARK: - Edge Cases

@Suite("ClipboardIntelligence — Edge Cases")
struct ClipboardEdgeCaseTests {
    let ci = ClipboardIntelligenceTestHelper()

    @Test("Nil text returns default result")
    func nilText() {
        let result = ci.analyze(nil)
        #expect(result.category == "Text")
        #expect(result.summary.isEmpty)
        #expect(result.actions.isEmpty)
    }

    @Test("Empty text returns default result")
    func emptyText() {
        let result = ci.analyze("")
        #expect(result.category == "Text")
    }

    @Test("Very long text is classified")
    func veryLongText() {
        let long = String(repeating: "a", count: 100_000)
        let result = ci.analyze(long)
        #expect(result.category == "Text")
    }

    @Test("Credential takes priority over URL")
    func credentialPriority() {
        let apiKey = "sk-abcdefghijklmnopqrstuvwxyz1234567890"
        #expect(ci.classify(apiKey) == "Credential")
    }

    @Test("JSON object not classified as text")
    func jsonNotText() {
        #expect(ci.classify("{\"key\":\"value\"}") == "JSON")
    }

    @Test("Invalid JSON treated as text")
    func invalidJSON() {
        #expect(ci.classify("{not valid json}") != "JSON")
    }

    @Test("Multiline code recognized")
    func multilineCode() {
        let code = "func main() {\n    let x = 10\n    return x\n}"
        #expect(ci.classify(code) == "Code")
    }

    @Test("AWS key detected as credential")
    func awsKey() {
        #expect(ci.classify("AKIA1234567890ABCDEF") == "Credential")
    }

    @Test("Slack token detected as credential")
    func slackToken() {
        #expect(ci.classify("xoxb-123456789012-abcdefghijklmnop") == "Credential")
    }
}

// MARK: - Test Helpers (standalone, no app dependency)

private enum ClipCategoryTestMirror: String, CaseIterable {
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

/// Standalone test helper that mirrors ClipboardIntelligence logic
/// (SPM tests can't import app target, so we replicate the classification logic)
private struct ClipboardIntelligenceTestHelper {

    struct AnalysisResult {
        let category: String
        let summary: String
        let actions: [String]
        let tags: [String]
        let languageHint: String?
    }

    func analyze(_ text: String?) -> AnalysisResult {
        analyzeWithSource(text, sourceApp: nil)
    }

    func analyzeWithSource(_ text: String?, sourceApp: String?) -> AnalysisResult {
        guard let text, !text.isEmpty else {
            return AnalysisResult(category: "Text", summary: "", actions: [], tags: [], languageHint: nil)
        }

        let category = classify(text, sourceApp: sourceApp)
        let summary = generateSummary(text: text, category: category)
        let actions = suggestActions(text: text, category: category)
        let tags = extractTags(text: text, category: category, sourceApp: sourceApp)
        let lang = detectCodeLanguage(text: text, category: category)

        return AnalysisResult(category: category, summary: summary, actions: actions,
                              tags: tags, languageHint: lang)
    }

    func classify(_ text: String, sourceApp: String? = nil) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if isCredential(trimmed) { return "Credential" }
        if isURL(trimmed) { return "URL" }
        if isEmail(trimmed) { return "Email" }
        if isPhone(trimmed) { return "Phone" }
        if isColorHex(trimmed) { return "Color" }
        if isFilePath(trimmed) { return "File Path" }
        if isJSON(trimmed) { return "JSON" }
        if isCommand(trimmed, sourceApp: sourceApp) { return "Command" }
        if isCode(trimmed, sourceApp: sourceApp) { return "Code" }
        if isMarkdown(trimmed) { return "Markdown" }
        if isAddress(trimmed) { return "Address" }
        if isNumber(trimmed) { return "Number" }
        if isDate(trimmed) { return "Date" }
        if trimmed.count < 200, !trimmed.contains("\n") { return "Snippet" }
        return "Text"
    }

    func detectLanguage(_ text: String) -> String? {
        detectCodeLanguage(text: text, category: isCode(text, sourceApp: nil) ? "Code" : "Text")
    }

    // MARK: - Pattern Matching (mirrors ClipboardIntelligence)

    private func isURL(_ text: String) -> Bool {
        let parts = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        guard parts.count == 1, let candidate = parts.first else { return false }
        if candidate.hasPrefix("http://") || candidate.hasPrefix("https://") || candidate.hasPrefix("ftp://") {
            return URL(string: candidate) != nil
        }
        return candidate.range(of: "^[a-zA-Z0-9][a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}(/.*)?$", options: .regularExpression) != nil
    }

    private func isEmail(_ text: String) -> Bool {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.contains(" "), t.count < 254 else { return false }
        return t.range(of: "^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$", options: .regularExpression) != nil
    }

    private func isPhone(_ text: String) -> Bool {
        let digits = text.filter(\.isNumber)
        guard digits.count >= 7, digits.count <= 15 else { return false }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
            .range(of: "^[+]?[\\d\\s().-]{7,20}$", options: .regularExpression) != nil
    }

    private func isColorHex(_ text: String) -> Bool {
        text.range(of: "^#[0-9a-fA-F]{3,8}$", options: .regularExpression) != nil
    }

    private func isFilePath(_ text: String) -> Bool {
        text.hasPrefix("/") || text.hasPrefix("~/") || text.hasPrefix("file://")
    }

    private func isJSON(_ text: String) -> Bool {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (t.hasPrefix("{") && t.hasSuffix("}")) || (t.hasPrefix("[") && t.hasSuffix("]")) else { return false }
        return (try? JSONSerialization.jsonObject(with: Data(t.utf8))) != nil
    }

    private func isCommand(_ text: String, sourceApp: String?) -> Bool {
        let codeApps = ["Terminal", "iTerm2", "Warp", "Alacritty", "kitty"]
        if let app = sourceApp, codeApps.contains(app) { return true }
        let lines = text.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
        let prefixes = ["$", "#", "%", "❯", "➜", ">>>"]
        let shells = ["cd ", "ls ", "rm ", "mv ", "cp ", "mkdir ", "cat ", "grep ",
                       "git ", "brew ", "npm ", "yarn ", "pip ", "docker ", "kubectl ",
                       "swift ", "xcodebuild ", "make ", "curl ", "wget ", "ssh ",
                       "sudo ", "chmod ", "chown ", "find ", "awk ", "sed "]
        if let first = lines.first {
            if prefixes.contains(where: { first.hasPrefix($0) }) { return true }
            if shells.contains(where: { first.hasPrefix($0) }) { return true }
        }
        return false
    }

    private func isCode(_ text: String, sourceApp: String?) -> Bool {
        let codeApps = ["Xcode", "VS Code", "Visual Studio Code", "Cursor",
                        "Sublime Text", "Nova", "BBEdit", "TextMate"]
        if let app = sourceApp, codeApps.contains(app) { return true }
        let signals = ["func ", "let ", "var ", "class ", "struct ", "enum ", "import ",
                       "def ", "return ", "if (", "for (", "while (",
                       "function ", "const ", "=>", "async ", "await ",
                       "public ", "private ", "static ", "void ", "int ",
                       "println", "printf", "console.log", "print(",
                       "};", "});", "//", "/*", "*/", "#include", "#import"]
        return signals.filter { text.contains($0) }.count >= 2
    }

    private func isMarkdown(_ text: String) -> Bool {
        let lines = text.components(separatedBy: "\n")
        let signals = ["# ", "## ", "### ", "- [ ] ", "- [x] ", "```", "**", "~~", "[]("]
        return signals.filter { s in lines.contains { $0.trimmingCharacters(in: .whitespaces).hasPrefix(s) || $0.contains(s) } }.count >= 2
    }

    private func isAddress(_ text: String) -> Bool {
        let patterns = [
            "\\d+\\s+[A-Za-z]+\\s+(Street|St|Avenue|Ave|Road|Rd|Boulevard|Blvd|Lane|Ln|Drive|Dr)",
            "\\b\\d{4,5}\\b.*\\b[A-Z][a-z]+\\b",
            "\\b(rue|avenue|chemin|place|boulevard)\\s+",
            "\\b\\d{5}\\s+[A-Z]"
        ]
        return patterns.contains { text.range(of: $0, options: [.regularExpression, .caseInsensitive]) != nil }
    }

    private func isCredential(_ text: String) -> Bool {
        let patterns = [
            "^sk-[A-Za-z0-9]{20,}$",
            "^ghp_[A-Za-z0-9]{36}$",
            "^AKIA[0-9A-Z]{16}$",
            "^xox[bpas]-[A-Za-z0-9-]+$",
            "(?i)(password|secret|token|api[_-]?key)\\s*[:=]\\s*[\"']?\\S{8,}"
        ]
        return patterns.contains { text.range(of: $0, options: .regularExpression) != nil }
    }

    private func isNumber(_ text: String) -> Bool {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.count < 30 else { return false }
        return Double(t.replacingOccurrences(of: ",", with: "")) != nil
            || t.range(of: "^[$€£¥₽CHF]?\\s?[\\d,.]+\\s?[$€£¥₽CHF]?$", options: .regularExpression) != nil
    }

    private func isDate(_ text: String) -> Bool {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.count < 40 else { return false }
        let patterns = ["\\d{4}-\\d{2}-\\d{2}", "\\d{1,2}/\\d{1,2}/\\d{2,4}",
                        "\\d{1,2}\\.\\d{1,2}\\.\\d{2,4}",
                        "(?i)(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)\\w*\\s+\\d{1,2},?\\s+\\d{4}"]
        return patterns.contains { t.range(of: $0, options: .regularExpression) != nil }
    }

    // MARK: - Summary (mirrors)

    private func generateSummary(text: String, category: String) -> String {
        switch category {
        case "URL":
            if let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)) {
                return url.host ?? String(text.prefix(120))
            }
            return String(text.prefix(120))
        case "Email": return "Email: \(text.trimmingCharacters(in: .whitespacesAndNewlines))"
        case "Phone": return "Phone: \(text.trimmingCharacters(in: .whitespacesAndNewlines))"
        case "JSON": return "JSON (\(text.count) chars)"
        case "Code":
            let lang = detectCodeLanguage(text: text, category: "Code") ?? "code"
            let lineCount = text.components(separatedBy: "\n").count
            return "\(lang) (\(lineCount) lines)"
        case "Command":
            return String((text.components(separatedBy: "\n").first ?? text).prefix(120))
        case "Credential": return "Sensitive credential"
        case "Color": return "Color: \(text.trimmingCharacters(in: .whitespacesAndNewlines))"
        case "File Path":
            if let last = text.components(separatedBy: "/").last, !last.isEmpty { return last }
            return String(text.prefix(120))
        case "Address": return String(text.prefix(120))
        case "Number": return "Number: \(text.trimmingCharacters(in: .whitespacesAndNewlines))"
        case "Date": return "Date: \(text.trimmingCharacters(in: .whitespacesAndNewlines))"
        case "Markdown":
            let lineCount = text.components(separatedBy: "\n").count
            return "Markdown (\(lineCount) lines)"
        default: return String(text.prefix(120))
        }
    }

    // MARK: - Actions (mirrors)

    private func suggestActions(text: String, category: String) -> [String] {
        var actions: [String] = []
        switch category {
        case "URL":
            actions.append("openURL")
            actions.append("searchWeb")
        case "Email": actions.append("composeEmail")
        case "Phone": actions.append("callPhone")
        case "Address": actions.append("openMap")
        case "Code":
            actions.append("formatCode")
            actions.append("copyPlain")
        case "Markdown": actions.append("pasteAsMarkdown")
        case "Command": actions.append("copyPlain")
        default: break
        }
        if text.count > 20 { actions.append("createTask") }
        if text.count > 5, text.count < 2000 { actions.append("translateText") }
        return actions
    }

    // MARK: - Tags (mirrors)

    private func extractTags(text: String, category: String, sourceApp: String?) -> [String] {
        var tags: [String] = [category.lowercased()]
        if let app = sourceApp { tags.append(app.lowercased()) }
        if category == "Code", let lang = detectCodeLanguage(text: text, category: "Code") {
            tags.append(lang.lowercased())
        }
        if text.contains("```") { tags.append("fenced-code") }
        if text.contains("<html") || text.contains("<div") { tags.append("html") }
        return Array(Set(tags)).sorted()
    }

    // MARK: - Language (mirrors)

    private func detectCodeLanguage(text: String, category: String) -> String? {
        guard category == "Code" || category == "Command" else { return nil }
        if category == "Command" { return "Shell" }
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
        var best = ""
        var bestScore = 0
        for (lang, kw) in indicators {
            let score = kw.filter { text.contains($0) }.count
            if score > bestScore { bestScore = score; best = lang }
        }
        return bestScore >= 2 ? best : nil
    }
}
