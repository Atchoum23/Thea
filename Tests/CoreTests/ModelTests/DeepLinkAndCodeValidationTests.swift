// DeepLinkAndCodeValidationTests.swift
// Tests for deep link URL parsing, route pattern matching, and URL generation

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
