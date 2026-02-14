// DeepLinkAndCodeValidationTests.swift
// Tests for deep link URL parsing, route pattern matching, URL generation,
// Swift code validation (error categorization, quick validation, code extraction),
// and accessibility label generation

import Testing
import Foundation

// MARK: - Deep Link Test Doubles

private struct TestDeepLink {
    let scheme: String
    let host: String
    let path: String
    let parameters: [String: String]

    var pathComponents: [String] {
        path.split(separator: "/").map(String.init)
    }
}

private enum TestDeepLinkSource: String {
    case urlScheme
    case universalLink
    case spotlight
    case handoff
    case widget
    case notification
    case shortcut
    case other
}

private struct TestDeepLinkRoute {
    let pattern: String

    func match(_ link: TestDeepLink) -> [String: String]? {
        let patternComponents = pattern.split(separator: "/").map(String.init)
        let pathComponents = link.pathComponents

        guard patternComponents.count == pathComponents.count else { return nil }

        var params: [String: String] = [:]

        for (patternPart, pathPart) in zip(patternComponents, pathComponents) {
            if patternPart.hasPrefix(":") {
                let key = String(patternPart.dropFirst())
                params[key] = pathPart
            } else if patternPart != pathPart {
                return nil
            }
        }

        return params
    }
}

/// Mirrors parse() logic from DeepLinkRouter
private func parseURL(_ urlString: String) -> TestDeepLink? {
    guard let url = URL(string: urlString) else { return nil }

    let scheme = url.scheme ?? ""
    let host = url.host ?? ""
    var path = url.path
    if path.hasPrefix("/") { path = String(path.dropFirst()) }

    var params: [String: String] = [:]
    if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
       let queryItems = components.queryItems {
        for item in queryItems {
            params[item.name] = item.value ?? ""
        }
    }

    return TestDeepLink(scheme: scheme, host: host, path: path, parameters: params)
}

/// Mirrors generateURL() from DeepLinkRouter
private func generateTheaURL(path: String, parameters: [String: String] = [:]) -> URL? {
    var components = URLComponents()
    components.scheme = "thea"
    components.host = ""
    components.path = "/\(path)"

    if !parameters.isEmpty {
        components.queryItems = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }
    }

    return components.url
}

/// Mirrors generateUniversalLink() from DeepLinkRouter
private func generateUniversalLink(path: String, parameters: [String: String] = [:]) -> URL? {
    var components = URLComponents()
    components.scheme = "https"
    components.host = "theathe.app"
    components.path = "/\(path)"

    if !parameters.isEmpty {
        components.queryItems = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }
    }

    return components.url
}

// MARK: - Swift Validation Test Doubles

private enum TestErrorCategory: Sendable {
    case syntax, type, undeclared, access, concurrency, other
}

private enum TestSeverity: Sendable {
    case error, warning, note
}

private struct TestSwiftError: Sendable {
    let message: String
    let line: Int?
    let column: Int?
    let severity: TestSeverity
    let category: TestErrorCategory
    let suggestion: String?
}

/// Mirrors categorizeError() from SwiftValidator
private func categorizeError(_ message: String) -> TestErrorCategory {
    let lowercased = message.lowercased()

    if lowercased.contains("expected") || lowercased.contains("unexpected") ||
        lowercased.contains("consecutive") || lowercased.contains("missing") {
        return .syntax
    }

    if lowercased.contains("type") || lowercased.contains("cannot convert") ||
        lowercased.contains("incompatible") {
        return .type
    }

    if lowercased.contains("undeclared") || lowercased.contains("not found") ||
        lowercased.contains("undefined") || lowercased.contains("use of unresolved") {
        return .undeclared
    }

    if lowercased.contains("private") || lowercased.contains("internal") ||
        lowercased.contains("inaccessible") {
        return .access
    }

    if lowercased.contains("@mainactor") || lowercased.contains("@sendable") ||
        lowercased.contains("actor") || lowercased.contains("concurrency") ||
        lowercased.contains("async") || lowercased.contains("await") {
        return .concurrency
    }

    return .other
}

/// Mirrors generateSuggestion() from SwiftValidator
private func generateSuggestion(for message: String, category: TestErrorCategory) -> String? {
    let lowercased = message.lowercased()

    switch category {
    case .syntax:
        if lowercased.contains("expected '}'") { return "Add missing closing brace '}'" }
        if lowercased.contains("expected ')'") { return "Add missing closing parenthesis ')'" }
        if lowercased.contains("expected ']'") { return "Add missing closing bracket ']'" }
    case .type:
        if lowercased.contains("cannot convert value of type") { return "Ensure type compatibility or add explicit type conversion" }
    case .undeclared:
        if lowercased.contains("use of unresolved identifier") { return "Check spelling and import necessary modules" }
    case .concurrency:
        if lowercased.contains("@mainactor") { return "Add @MainActor annotation or call from @MainActor context" }
        if lowercased.contains("@sendable") { return "Ensure type conforms to Sendable protocol" }
        if lowercased.contains("await") { return "Add 'await' keyword for async function call" }
    case .access:
        if lowercased.contains("private") { return "Make property/method internal or public" }
    case .other:
        break
    }

    return nil
}

/// Mirrors quickValidate() from SwiftValidator
private func quickValidate(_ code: String) -> (isValid: Bool, issues: [String]) {
    var issues: [String] = []

    let openBraces = code.filter { $0 == "{" }.count
    let closeBraces = code.filter { $0 == "}" }.count
    if openBraces != closeBraces {
        issues.append("Mismatched braces: \(openBraces) '{' vs \(closeBraces) '}'")
    }

    let openParens = code.filter { $0 == "(" }.count
    let closeParens = code.filter { $0 == ")" }.count
    if openParens != closeParens {
        issues.append("Mismatched parentheses: \(openParens) '(' vs \(closeParens) ')'")
    }

    let openBrackets = code.filter { $0 == "[" }.count
    let closeBrackets = code.filter { $0 == "]" }.count
    if openBrackets != closeBrackets {
        issues.append("Mismatched brackets: \(openBrackets) '[' vs \(closeBrackets) ']'")
    }

    return (issues.isEmpty, issues)
}

/// Mirrors extractSwiftCode() from SwiftValidator
private func extractSwiftCode(from text: String) -> String? {
    let pattern = "```(?:swift)?\\n(.*?)```"
    guard let regex = try? NSRegularExpression(pattern: pattern, options: .dotMatchesLineSeparators) else { return nil }
    let range = NSRange(text.startIndex..<text.endIndex, in: text)
    guard let match = regex.firstMatch(in: text, range: range) else { return nil }
    guard let codeRange = Range(match.range(at: 1), in: text) else { return nil }
    return String(text[codeRange])
}

/// Mirrors accessibleCodeDescription from String extension
private func accessibleCodeDescription(_ code: String) -> String {
    code
        .replacingOccurrences(of: "{", with: " open brace ")
        .replacingOccurrences(of: "}", with: " close brace ")
        .replacingOccurrences(of: "(", with: " open paren ")
        .replacingOccurrences(of: ")", with: " close paren ")
        .replacingOccurrences(of: "[", with: " open bracket ")
        .replacingOccurrences(of: "]", with: " close bracket ")
        .replacingOccurrences(of: "->", with: " returns ")
        .replacingOccurrences(of: "==", with: " equals ")
        .replacingOccurrences(of: "!=", with: " not equals ")
        .replacingOccurrences(of: "&&", with: " and ")
        .replacingOccurrences(of: "||", with: " or ")
}

/// Mirrors describeAIResponse() from AccessibilityService
private func describeAIResponse(_ response: String, wordCount: Int, isComplete: Bool) -> String {
    let status = isComplete ? "Complete response" : "Response in progress"
    return "\(status). \(wordCount) words. \(response.prefix(200))"
}

/// Mirrors hintForAction() from AccessibilityService
private func hintForAction(_ action: String) -> String {
    switch action {
    case "send": "Double tap to send message to Thea"
    case "copy": "Double tap to copy to clipboard"
    case "share": "Double tap to open sharing options"
    case "speak": "Double tap to have Thea read this aloud"
    default: "Double tap to \(action)"
    }
}

// MARK: - Tests: Deep Link Route Matching

@Suite("Deep Link Route — Pattern Matching")
struct DeepLinkRouteTests {
    @Test("Match conversation/:id pattern")
    func matchConversationId() {
        let route = TestDeepLinkRoute(pattern: "conversation/:id")
        let link = TestDeepLink(scheme: "thea", host: "", path: "conversation/abc123", parameters: [:])
        let params = route.match(link)
        #expect(params?["id"] == "abc123")
    }

    @Test("Match agent/:id pattern")
    func matchAgentId() {
        let route = TestDeepLinkRoute(pattern: "agent/:id")
        let link = TestDeepLink(scheme: "thea", host: "", path: "agent/worker-42", parameters: [:])
        let params = route.match(link)
        #expect(params?["id"] == "worker-42")
    }

    @Test("Match settings/:section pattern")
    func matchSettingsSection() {
        let route = TestDeepLinkRoute(pattern: "settings/:section")
        let link = TestDeepLink(scheme: "thea", host: "", path: "settings/privacy", parameters: [:])
        let params = route.match(link)
        #expect(params?["section"] == "privacy")
    }

    @Test("No match for wrong component count")
    func noMatchWrongCount() {
        let route = TestDeepLinkRoute(pattern: "conversation/:id")
        let link = TestDeepLink(scheme: "thea", host: "", path: "conversation/abc/extra", parameters: [:])
        #expect(route.match(link) == nil)
    }

    @Test("No match for wrong static component")
    func noMatchWrongStatic() {
        let route = TestDeepLinkRoute(pattern: "conversation/:id")
        let link = TestDeepLink(scheme: "thea", host: "", path: "agent/abc123", parameters: [:])
        #expect(route.match(link) == nil)
    }

    @Test("Match static-only pattern")
    func matchStatic() {
        let route = TestDeepLinkRoute(pattern: "conversation/new")
        let link = TestDeepLink(scheme: "thea", host: "", path: "conversation/new", parameters: [:])
        let params = route.match(link)
        #expect(params != nil)
        #expect(params?.isEmpty == true)
    }

    @Test("Multiple parameters")
    func multipleParams() {
        let route = TestDeepLinkRoute(pattern: ":type/:id")
        let link = TestDeepLink(scheme: "thea", host: "", path: "agent/uuid-123", parameters: [:])
        let params = route.match(link)
        #expect(params?["type"] == "agent")
        #expect(params?["id"] == "uuid-123")
    }
}

// MARK: - Tests: URL Parsing

@Suite("Deep Link — URL Parsing")
struct URLParsingTests {
    @Test("Parse thea:// scheme URL")
    func parseScheme() {
        let link = parseURL("thea:///conversation/abc")
        #expect(link?.scheme == "thea")
        #expect(link?.path == "conversation/abc")
    }

    @Test("Parse universal link")
    func parseUniversal() {
        let link = parseURL("https://theathe.app/conversation/abc")
        #expect(link?.scheme == "https")
        #expect(link?.host == "theathe.app")
        #expect(link?.path == "conversation/abc")
    }

    @Test("Parse query parameters")
    func parseQuery() {
        let link = parseURL("thea:///search?q=hello&limit=10")
        #expect(link?.parameters["q"] == "hello")
        #expect(link?.parameters["limit"] == "10")
    }

    @Test("Path components split correctly")
    func pathComponents() {
        let link = TestDeepLink(scheme: "thea", host: "", path: "conversation/abc/messages", parameters: [:])
        #expect(link.pathComponents == ["conversation", "abc", "messages"])
    }

    @Test("Empty path produces no components")
    func emptyPath() {
        let link = TestDeepLink(scheme: "thea", host: "", path: "", parameters: [:])
        #expect(link.pathComponents.isEmpty)
    }
}

// MARK: - Tests: URL Generation

@Suite("Deep Link — URL Generation")
struct URLGenerationTests {
    @Test("Generate thea:// URL")
    func generateScheme() {
        let url = generateTheaURL(path: "conversation/new")
        #expect(url?.scheme == "thea")
        #expect(url?.path.contains("conversation/new") == true)
    }

    @Test("Generate universal link")
    func generateUniversal() {
        let url = generateUniversalLink(path: "conversation/abc")
        #expect(url?.scheme == "https")
        #expect(url?.host == "theathe.app")
    }

    @Test("Generate URL with parameters")
    func generateWithParams() {
        let url = generateTheaURL(path: "search", parameters: ["q": "hello"])
        #expect(url?.absoluteString.contains("q=hello") == true)
    }

    @Test("Generate URL without parameters")
    func generateNoParams() {
        let url = generateTheaURL(path: "settings")
        #expect(url != nil)
        #expect(url?.absoluteString.contains("?") == false)
    }
}

// MARK: - Tests: Error Categorization

@Suite("SwiftValidator — Error Categorization")
struct ErrorCategorizationTests {
    @Test("Syntax: 'expected' keyword")
    func syntaxExpected() {
        #expect(categorizeError("expected '}' at end of closure") == .syntax)
    }

    @Test("Syntax: 'unexpected' keyword")
    func syntaxUnexpected() {
        #expect(categorizeError("unexpected ')' in expression") == .syntax)
    }

    @Test("Syntax: 'consecutive' keyword")
    func syntaxConsecutive() {
        #expect(categorizeError("consecutive statements on same line") == .syntax)
    }

    @Test("Syntax: 'missing' keyword")
    func syntaxMissing() {
        #expect(categorizeError("missing return in function") == .syntax)
    }

    @Test("Type: 'type' keyword")
    func typeCategory() {
        #expect(categorizeError("value of type 'String' has no member 'foo'") == .type)
    }

    @Test("Type: 'cannot convert'")
    func typeConvert() {
        #expect(categorizeError("cannot convert value of type 'Int' to 'String'") == .type)
    }

    @Test("Type: 'incompatible'")
    func typeIncompatible() {
        #expect(categorizeError("incompatible types in assignment") == .type)
    }

    @Test("Undeclared: 'use of unresolved'")
    func undeclaredUnresolved() {
        #expect(categorizeError("use of unresolved identifier 'foo'") == .undeclared)
    }

    @Test("Undeclared: 'not found'")
    func undeclaredNotFound() {
        #expect(categorizeError("'foo' not found in scope") == .undeclared)
    }

    @Test("Access: 'private'")
    func accessPrivate() {
        #expect(categorizeError("'foo' is private and cannot be referenced") == .access)
    }

    @Test("Access: 'inaccessible'")
    func accessInaccessible() {
        #expect(categorizeError("setter is inaccessible") == .access)
    }

    @Test("Concurrency: '@MainActor'")
    func concurrencyMainActor() {
        #expect(categorizeError("call to @MainActor function") == .concurrency)
    }

    @Test("Concurrency: 'async'")
    func concurrencyAsync() {
        #expect(categorizeError("expression is async but not awaited") == .concurrency)
    }

    @Test("Concurrency: '@Sendable'")
    func concurrencySendable() {
        // Note: "type" keyword matches .type category first in production code
        // Use a message without "type" to test @Sendable detection
        #expect(categorizeError("closure is not @Sendable") == .concurrency)
    }

    @Test("Type check wins over @Sendable when both keywords present")
    func typeWinsOverSendable() {
        // "type" matches before "@Sendable" due to ordering
        #expect(categorizeError("type does not conform to @Sendable") == .type)
    }

    @Test("Other: unrecognized error")
    func otherError() {
        #expect(categorizeError("some completely random error message") == .other)
    }
}

// MARK: - Tests: Error Suggestions

@Suite("SwiftValidator — Suggestions")
struct ErrorSuggestionTests {
    @Test("Missing closing brace")
    func missingBrace() {
        let suggestion = generateSuggestion(for: "expected '}' at end of closure", category: .syntax)
        #expect(suggestion?.contains("brace") == true)
    }

    @Test("Missing closing paren")
    func missingParen() {
        let suggestion = generateSuggestion(for: "expected ')' in expression", category: .syntax)
        #expect(suggestion?.contains("parenthesis") == true)
    }

    @Test("Type conversion")
    func typeConversion() {
        let suggestion = generateSuggestion(for: "cannot convert value of type 'Int' to 'String'", category: .type)
        #expect(suggestion?.contains("type compatibility") == true)
    }

    @Test("Unresolved identifier")
    func unresolvedId() {
        let suggestion = generateSuggestion(for: "use of unresolved identifier 'foo'", category: .undeclared)
        #expect(suggestion?.contains("spelling") == true)
    }

    @Test("MainActor annotation")
    func mainActor() {
        let suggestion = generateSuggestion(for: "call to @MainActor function in non-MainActor context", category: .concurrency)
        #expect(suggestion?.contains("@MainActor") == true)
    }

    @Test("Await keyword")
    func awaitKeyword() {
        let suggestion = generateSuggestion(for: "expression is async and requires await", category: .concurrency)
        #expect(suggestion?.contains("await") == true)
    }

    @Test("No suggestion for unknown .other")
    func noSuggestionOther() {
        let suggestion = generateSuggestion(for: "random error", category: .other)
        #expect(suggestion == nil)
    }
}

// MARK: - Tests: Quick Validation

@Suite("SwiftValidator — Quick Validation")
struct QuickValidationTests {
    @Test("Valid code passes")
    func validCode() {
        let result = quickValidate("func hello() { print(\"hi\") }")
        #expect(result.isValid)
        #expect(result.issues.isEmpty)
    }

    @Test("Mismatched braces detected")
    func mismatchedBraces() {
        let result = quickValidate("func hello() { print(\"hi\")")
        #expect(!result.isValid)
        #expect(result.issues.first?.contains("brace") == true)
    }

    @Test("Mismatched parens detected")
    func mismatchedParens() {
        let result = quickValidate("func hello( { }")
        #expect(!result.isValid)
        #expect(result.issues.contains { $0.contains("parenthes") })
    }

    @Test("Mismatched brackets detected")
    func mismatchedBrackets() {
        let result = quickValidate("let a = [1, 2, 3")
        #expect(!result.isValid)
        #expect(result.issues.contains { $0.contains("bracket") })
    }

    @Test("Empty code is valid")
    func emptyCode() {
        let result = quickValidate("")
        #expect(result.isValid)
    }

    @Test("Multiple mismatches produce multiple issues")
    func multipleIssues() {
        let result = quickValidate("func hello( { [")
        #expect(!result.isValid)
        #expect(result.issues.count >= 2)
    }
}

// MARK: - Tests: Code Extraction

@Suite("SwiftValidator — Code Extraction")
struct CodeExtractionTests {
    @Test("Extract from ```swift block")
    func extractSwiftBlock() {
        let text = "Here's some code:\n```swift\nlet x = 42\n```\nDone."
        let code = extractSwiftCode(from: text)
        #expect(code?.contains("let x = 42") == true)
    }

    @Test("Extract from untyped ``` block")
    func extractUntypedBlock() {
        let text = "Code:\n```\nprint(\"hello\")\n```"
        let code = extractSwiftCode(from: text)
        #expect(code?.contains("print") == true)
    }

    @Test("Returns nil when no code block")
    func noCodeBlock() {
        let text = "Just some regular text without code blocks."
        let code = extractSwiftCode(from: text)
        #expect(code == nil)
    }

    @Test("Extracts first block only")
    func firstBlockOnly() {
        let text = "```swift\nfirst\n```\n```swift\nsecond\n```"
        let code = extractSwiftCode(from: text)
        #expect(code?.contains("first") == true)
    }
}

// MARK: - Tests: Accessibility Labels

@Suite("Accessibility — Code Description")
struct AccessibleCodeDescriptionTests {
    @Test("Replaces { with 'open brace'")
    func openBrace() {
        #expect(accessibleCodeDescription("{").contains("open brace"))
    }

    @Test("Replaces } with 'close brace'")
    func closeBrace() {
        #expect(accessibleCodeDescription("}").contains("close brace"))
    }

    @Test("Replaces ( with 'open paren'")
    func openParen() {
        #expect(accessibleCodeDescription("(").contains("open paren"))
    }

    @Test("Replaces ) with 'close paren'")
    func closeParen() {
        #expect(accessibleCodeDescription(")").contains("close paren"))
    }

    @Test("Replaces -> with 'returns'")
    func arrowReturns() {
        #expect(accessibleCodeDescription("->").contains("returns"))
    }

    @Test("Replaces == with 'equals'")
    func doubleEquals() {
        #expect(accessibleCodeDescription("==").contains("equals"))
    }

    @Test("Replaces != with 'not equals'")
    func notEquals() {
        #expect(accessibleCodeDescription("!=").contains("not equals"))
    }

    @Test("Replaces && with 'and'")
    func logicalAnd() {
        #expect(accessibleCodeDescription("&&").contains(" and "))
    }

    @Test("Replaces || with 'or'")
    func logicalOr() {
        #expect(accessibleCodeDescription("||").contains(" or "))
    }

    @Test("Full function declaration")
    func fullFunction() {
        let desc = accessibleCodeDescription("func foo() -> Bool { return true }")
        #expect(desc.contains("open paren"))
        #expect(desc.contains("close paren"))
        #expect(desc.contains("returns"))
        #expect(desc.contains("open brace"))
        #expect(desc.contains("close brace"))
    }
}

@Suite("Accessibility — AI Response Description")
struct AIResponseDescriptionTests {
    @Test("Complete response label")
    func completeResponse() {
        let desc = describeAIResponse("Hello world", wordCount: 2, isComplete: true)
        #expect(desc.hasPrefix("Complete response"))
        #expect(desc.contains("2 words"))
    }

    @Test("In-progress response label")
    func inProgressResponse() {
        let desc = describeAIResponse("Generating...", wordCount: 1, isComplete: false)
        #expect(desc.hasPrefix("Response in progress"))
    }

    @Test("Truncates long response to 200 chars")
    func truncatesLong() {
        let longResponse = String(repeating: "A", count: 300)
        let desc = describeAIResponse(longResponse, wordCount: 1, isComplete: true)
        // Response text portion should be at most 200 chars from prefix(200)
        #expect(!desc.contains(String(repeating: "A", count: 250)))
    }

    @Test("Zero word count")
    func zeroWords() {
        let desc = describeAIResponse("", wordCount: 0, isComplete: true)
        #expect(desc.contains("0 words"))
    }
}

@Suite("Accessibility — Action Hints")
struct ActionHintTests {
    @Test("Send action hint")
    func sendHint() {
        #expect(hintForAction("send") == "Double tap to send message to Thea")
    }

    @Test("Copy action hint")
    func copyHint() {
        #expect(hintForAction("copy") == "Double tap to copy to clipboard")
    }

    @Test("Share action hint")
    func shareHint() {
        #expect(hintForAction("share") == "Double tap to open sharing options")
    }

    @Test("Speak action hint")
    func speakHint() {
        #expect(hintForAction("speak") == "Double tap to have Thea read this aloud")
    }

    @Test("Unknown action falls through to default")
    func unknownAction() {
        let hint = hintForAction("delete")
        #expect(hint == "Double tap to delete")
    }
}
