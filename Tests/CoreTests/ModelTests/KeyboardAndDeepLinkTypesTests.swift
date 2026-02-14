// KeyboardAndDeepLinkTypesTests.swift
// Tests for KeyboardShortcutsTypes and DeepLinkRouter types

import Testing
import Foundation

// MARK: - Test Doubles: KeyModifier

private enum TestKeyModifier: Int, Codable, Hashable, CaseIterable {
    case command = 1, option = 2, control = 3, shift = 4

    var symbol: String {
        switch self {
        case .command: return "⌘"
        case .option: return "⌥"
        case .control: return "⌃"
        case .shift: return "⇧"
        }
    }
}

// MARK: - Test Doubles: KeyCombo

private struct TestKeyCombo: Equatable, Codable, Sendable {
    let key: String
    let modifiers: Set<TestKeyModifier>

    var displayString: String {
        let sortedModifiers = modifiers.sorted { $0.rawValue < $1.rawValue }
        let modifierSymbols = sortedModifiers.map(\.symbol).joined()
        let displayKey: String
        switch key.lowercased() {
        case "return", "enter": displayKey = "↩"
        case "escape", "esc": displayKey = "⎋"
        case "tab": displayKey = "⇥"
        case "space": displayKey = "␣"
        case "delete", "backspace": displayKey = "⌫"
        case "up": displayKey = "↑"
        case "down": displayKey = "↓"
        case "left": displayKey = "←"
        case "right": displayKey = "→"
        default: displayKey = key.uppercased()
        }
        return "\(modifierSymbols)\(displayKey)"
    }
}

// MARK: - Test Doubles: KeyboardShortcut

private struct TestKeyboardShortcut: Identifiable, Sendable {
    let id: String
    let name: String
    let description: String
    let category: String
    let defaultKey: TestKeyCombo
    let action: String
    var isGlobal: Bool = false
    var customKey: TestKeyCombo?

    var effectiveKeyCombo: TestKeyCombo {
        customKey ?? defaultKey
    }

    var isCustomized: Bool {
        customKey != nil
    }
}

// MARK: - Test Doubles: KeyboardShortcutCategory

private struct TestKeyboardShortcutCategory: Identifiable, Sendable {
    let id: String
    let name: String
    let icon: String
}

// MARK: - Test Doubles: ShortcutConflict

private struct TestShortcutConflict: Identifiable, Sendable {
    let id: UUID
    let shortcut1Id: String
    let shortcut2Id: String
    let keyCombo: TestKeyCombo

    init(shortcut1Id: String, shortcut2Id: String, keyCombo: TestKeyCombo) {
        self.id = UUID()
        self.shortcut1Id = shortcut1Id
        self.shortcut2Id = shortcut2Id
        self.keyCombo = keyCombo
    }
}

// MARK: - Test Doubles: DeepLinkSource

private enum TestDeepLinkSource: String, Sendable, CaseIterable {
    case urlScheme, universalLink, spotlight, handoff, widget, notification, shortcut, other
}

// MARK: - Test Doubles: DeepLink

private struct TestDeepLink: Sendable {
    let url: URL
    let source: TestDeepLinkSource
    let path: String
    let parameters: [String: String]
    let queryParameters: [String: String]

    var pathComponents: [String] {
        path.split(separator: "/").map(String.init).filter { !$0.isEmpty }
    }

    init(url: URL, source: TestDeepLinkSource = .urlScheme, path: String, parameters: [String: String] = [:], queryParameters: [String: String] = [:]) {
        self.url = url
        self.source = source
        self.path = path
        self.parameters = parameters
        self.queryParameters = queryParameters
    }
}

// MARK: - Test Doubles: PatternComponent

private enum TestPatternComponent: Equatable, Sendable {
    case literal(String)
    case parameter(String)
    case wildcard

    static func parse(_ pattern: String) -> [TestPatternComponent] {
        pattern.split(separator: "/").map { segment in
            let s = String(segment)
            if s == "*" { return .wildcard }
            if s.hasPrefix(":") { return .parameter(String(s.dropFirst())) }
            return .literal(s)
        }
    }

    static func match(pattern: [TestPatternComponent], path: [String]) -> [String: String]? {
        guard pattern.count == path.count else { return nil }
        var params: [String: String] = [:]
        for (comp, segment) in zip(pattern, path) {
            switch comp {
            case .literal(let expected):
                if expected != segment { return nil }
            case .parameter(let name):
                params[name] = segment
            case .wildcard:
                continue
            }
        }
        return params
    }
}

// MARK: - Tests: KeyModifier

@Suite("Key Modifier")
struct KeyModifierTests {
    @Test("All cases exist")
    func allCases() {
        #expect(TestKeyModifier.allCases.count == 4)
    }

    @Test("Symbols are Unicode modifier characters")
    func symbols() {
        #expect(TestKeyModifier.command.symbol == "⌘")
        #expect(TestKeyModifier.option.symbol == "⌥")
        #expect(TestKeyModifier.control.symbol == "⌃")
        #expect(TestKeyModifier.shift.symbol == "⇧")
    }

    @Test("Raw values are unique")
    func uniqueRawValues() {
        let values = Set(TestKeyModifier.allCases.map(\.rawValue))
        #expect(values.count == TestKeyModifier.allCases.count)
    }

    @Test("Codable roundtrip")
    func codable() throws {
        for modifier in TestKeyModifier.allCases {
            let data = try JSONEncoder().encode(modifier)
            let decoded = try JSONDecoder().decode(TestKeyModifier.self, from: data)
            #expect(decoded == modifier)
        }
    }
}

// MARK: - Tests: KeyCombo

@Suite("Key Combo")
struct KeyComboTests {
    @Test("Display string: Cmd+N")
    func cmdN() {
        let combo = TestKeyCombo(key: "n", modifiers: [.command])
        #expect(combo.displayString == "⌘N")
    }

    @Test("Display string: Cmd+Shift+S")
    func cmdShiftS() {
        let combo = TestKeyCombo(key: "s", modifiers: [.command, .shift])
        #expect(combo.displayString == "⌘⇧S")
    }

    @Test("Display string: Return key")
    func returnKey() {
        let combo = TestKeyCombo(key: "return", modifiers: [])
        #expect(combo.displayString == "↩")
    }

    @Test("Display string: Escape key")
    func escapeKey() {
        let combo = TestKeyCombo(key: "escape", modifiers: [])
        #expect(combo.displayString == "⎋")
    }

    @Test("Display string: Tab key")
    func tabKey() {
        let combo = TestKeyCombo(key: "tab", modifiers: [.command])
        #expect(combo.displayString == "⌘⇥")
    }

    @Test("Display string: Arrow keys")
    func arrowKeys() {
        #expect(TestKeyCombo(key: "up", modifiers: []).displayString == "↑")
        #expect(TestKeyCombo(key: "down", modifiers: []).displayString == "↓")
        #expect(TestKeyCombo(key: "left", modifiers: []).displayString == "←")
        #expect(TestKeyCombo(key: "right", modifiers: []).displayString == "→")
    }

    @Test("Display string: Delete key")
    func deleteKey() {
        let combo = TestKeyCombo(key: "delete", modifiers: [.command])
        #expect(combo.displayString == "⌘⌫")
    }

    @Test("Display string: Space key")
    func spaceKey() {
        let combo = TestKeyCombo(key: "space", modifiers: [.control])
        #expect(combo.displayString == "⌃␣")
    }

    @Test("Modifiers sorted by raw value")
    func modifierSorting() {
        let combo = TestKeyCombo(key: "k", modifiers: [.shift, .command, .option])
        // Command=1, Option=2, Shift=4 → ⌘⌥⇧K
        #expect(combo.displayString == "⌘⌥⇧K")
    }

    @Test("Equatable")
    func equatable() {
        let a = TestKeyCombo(key: "n", modifiers: [.command])
        let b = TestKeyCombo(key: "n", modifiers: [.command])
        let c = TestKeyCombo(key: "m", modifiers: [.command])
        #expect(a == b)
        #expect(a != c)
    }

    @Test("Codable roundtrip")
    func codable() throws {
        let combo = TestKeyCombo(key: "f", modifiers: [.command, .shift])
        let data = try JSONEncoder().encode(combo)
        let decoded = try JSONDecoder().decode(TestKeyCombo.self, from: data)
        #expect(decoded == combo)
    }
}

// MARK: - Tests: KeyboardShortcut

@Suite("Keyboard Shortcut")
struct KeyboardShortcutTests {
    @Test("Effective key combo uses default when no custom")
    func effectiveDefault() {
        let shortcut = TestKeyboardShortcut(id: "send", name: "Send", description: "Send message", category: "chat", defaultKey: TestKeyCombo(key: "return", modifiers: [.command]), action: "send")
        #expect(shortcut.effectiveKeyCombo == shortcut.defaultKey)
        #expect(!shortcut.isCustomized)
    }

    @Test("Effective key combo uses custom when set")
    func effectiveCustom() {
        let customKey = TestKeyCombo(key: "return", modifiers: [.shift])
        let shortcut = TestKeyboardShortcut(id: "send", name: "Send", description: "Send message", category: "chat", defaultKey: TestKeyCombo(key: "return", modifiers: [.command]), action: "send", customKey: customKey)
        #expect(shortcut.effectiveKeyCombo == customKey)
        #expect(shortcut.isCustomized)
    }

    @Test("Global vs local")
    func globalVsLocal() {
        let global = TestKeyboardShortcut(id: "quick", name: "Quick Entry", description: "Open quick entry", category: "global", defaultKey: TestKeyCombo(key: "space", modifiers: [.option, .option]), action: "quickEntry", isGlobal: true)
        let local = TestKeyboardShortcut(id: "send", name: "Send", description: "Send message", category: "chat", defaultKey: TestKeyCombo(key: "return", modifiers: [.command]), action: "send")
        #expect(global.isGlobal)
        #expect(!local.isGlobal)
    }
}

// MARK: - Tests: ShortcutConflict

@Suite("Shortcut Conflict")
struct ShortcutConflictTests {
    @Test("Conflict has unique ID")
    func uniqueId() {
        let combo = TestKeyCombo(key: "n", modifiers: [.command])
        let c1 = TestShortcutConflict(shortcut1Id: "new_conversation", shortcut2Id: "new_window", keyCombo: combo)
        let c2 = TestShortcutConflict(shortcut1Id: "new_conversation", shortcut2Id: "new_window", keyCombo: combo)
        #expect(c1.id != c2.id)
    }

    @Test("Conflict references two shortcuts")
    func references() {
        let combo = TestKeyCombo(key: "w", modifiers: [.command])
        let conflict = TestShortcutConflict(shortcut1Id: "close_tab", shortcut2Id: "close_window", keyCombo: combo)
        #expect(conflict.shortcut1Id == "close_tab")
        #expect(conflict.shortcut2Id == "close_window")
    }
}

// MARK: - Tests: KeyboardShortcutCategory

@Suite("Keyboard Shortcut Category")
struct KeyboardShortcutCategoryTests {
    @Test("Creation")
    func creation() {
        let cat = TestKeyboardShortcutCategory(id: "chat", name: "Chat", icon: "bubble.left")
        #expect(cat.id == "chat")
        #expect(cat.name == "Chat")
        #expect(cat.icon == "bubble.left")
    }
}

// MARK: - Tests: DeepLinkSource

@Suite("Deep Link Source")
struct DeepLinkSourceTests {
    @Test("All cases exist")
    func allCases() {
        #expect(TestDeepLinkSource.allCases.count == 8)
    }

    @Test("Raw values are unique")
    func uniqueRawValues() {
        let rawValues = Set(TestDeepLinkSource.allCases.map(\.rawValue))
        #expect(rawValues.count == TestDeepLinkSource.allCases.count)
    }
}

// MARK: - Tests: DeepLink

@Suite("Deep Link")
struct DeepLinkTests {
    @Test("Path components parsing")
    func pathComponents() {
        let link = TestDeepLink(url: URL(string: "thea://conversation/123")!, path: "/conversation/123")
        #expect(link.pathComponents == ["conversation", "123"])
    }

    @Test("Path components with trailing slash")
    func pathWithTrailingSlash() {
        let link = TestDeepLink(url: URL(string: "thea://settings/ai/")!, path: "/settings/ai/")
        #expect(link.pathComponents == ["settings", "ai"])
    }

    @Test("Empty path")
    func emptyPath() {
        let link = TestDeepLink(url: URL(string: "thea://")!, path: "")
        #expect(link.pathComponents.isEmpty)
    }

    @Test("Root path")
    func rootPath() {
        let link = TestDeepLink(url: URL(string: "thea:///")!, path: "/")
        #expect(link.pathComponents.isEmpty)
    }

    @Test("Query parameters")
    func queryParams() {
        let link = TestDeepLink(url: URL(string: "thea://search?q=hello&lang=en")!, path: "/search", queryParameters: ["q": "hello", "lang": "en"])
        #expect(link.queryParameters["q"] == "hello")
        #expect(link.queryParameters["lang"] == "en")
    }

    @Test("Source assignment")
    func sourceAssignment() {
        let link = TestDeepLink(url: URL(string: "thea://x")!, source: .spotlight, path: "/x")
        #expect(link.source == .spotlight)
    }
}

// MARK: - Tests: PatternComponent

@Suite("Deep Link Pattern")
struct PatternComponentTests {
    @Test("Parse literal pattern")
    func parseLiteral() {
        let components = TestPatternComponent.parse("conversation/list")
        #expect(components == [.literal("conversation"), .literal("list")])
    }

    @Test("Parse parameter pattern")
    func parseParameter() {
        let components = TestPatternComponent.parse("conversation/:id")
        #expect(components == [.literal("conversation"), .parameter("id")])
    }

    @Test("Parse wildcard pattern")
    func parseWildcard() {
        let components = TestPatternComponent.parse("api/*/data")
        #expect(components == [.literal("api"), .wildcard, .literal("data")])
    }

    @Test("Match literal path")
    func matchLiteral() {
        let pattern = TestPatternComponent.parse("settings/ai")
        let result = TestPatternComponent.match(pattern: pattern, path: ["settings", "ai"])
        #expect(result != nil)
        #expect(result!.isEmpty)
    }

    @Test("Match parameter path")
    func matchParameter() {
        let pattern = TestPatternComponent.parse("conversation/:id")
        let result = TestPatternComponent.match(pattern: pattern, path: ["conversation", "abc-123"])
        #expect(result != nil)
        #expect(result!["id"] == "abc-123")
    }

    @Test("Match wildcard path")
    func matchWildcard() {
        let pattern = TestPatternComponent.parse("api/*/data")
        let result = TestPatternComponent.match(pattern: pattern, path: ["api", "v2", "data"])
        #expect(result != nil)
    }

    @Test("No match: wrong literal")
    func noMatchWrongLiteral() {
        let pattern = TestPatternComponent.parse("settings/ai")
        let result = TestPatternComponent.match(pattern: pattern, path: ["settings", "sync"])
        #expect(result == nil)
    }

    @Test("No match: wrong length")
    func noMatchWrongLength() {
        let pattern = TestPatternComponent.parse("settings/ai")
        let result = TestPatternComponent.match(pattern: pattern, path: ["settings"])
        #expect(result == nil)
    }

    @Test("Multiple parameters")
    func multipleParams() {
        let pattern = TestPatternComponent.parse(":type/:id")
        let result = TestPatternComponent.match(pattern: pattern, path: ["conversation", "xyz"])
        #expect(result?["type"] == "conversation")
        #expect(result?["id"] == "xyz")
    }
}
