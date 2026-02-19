// DeepLinkRouter.swift
// Universal deep linking and URL scheme handling

import Combine
import Foundation
import OSLog

// MARK: - Deep Link Router

/// Handles URL schemes, universal links, and deep navigation
@MainActor
public final class DeepLinkRouter: ObservableObject {
    public static let shared = DeepLinkRouter()

    private let logger = Logger(subsystem: "com.thea.app", category: "DeepLink")

    // MARK: - Published State

    @Published public private(set) var lastHandledLink: DeepLink?
    @Published public private(set) var pendingLink: DeepLink?
    @Published public private(set) var isProcessing = false

    // MARK: - Routes

    private var routes: [DeepLinkRoute] = []
    private var wildcardHandler: ((DeepLink) async -> Bool)?

    // MARK: - URL Schemes

    nonisolated public static let urlScheme = "thea"
    nonisolated public static let universalLinkDomain = "theathe.app"

    // MARK: - Initialization

    private init() {
        registerDefaultRoutes()
    }

    // MARK: - Route Registration

    /// Register a route handler
    public func register(_ pattern: String, handler: @escaping (DeepLink) async -> Bool) {
        let route = DeepLinkRoute(pattern: pattern, handler: handler)
        routes.append(route)
        logger.debug("Registered route: \(pattern)")
    }

    /// Register wildcard handler for unmatched routes
    public func registerWildcard(handler: @escaping (DeepLink) async -> Bool) {
        wildcardHandler = handler
    }

    private func registerDefaultRoutes() {
        registerConversationRoutes()
        registerEntityRoutes()
        registerSettingsRoutes()
        registerQuickActionRoutes()
        registerShareImportRoutes()
        registerWidgetAndSpotlightRoutes()
        registerOAuthRoutes()

        logger.info("Registered \(self.routes.count) default routes")
    }

    private func registerConversationRoutes() {
        register("conversation/:id") { link in
            if let conversationId = link.parameters["id"] {
                NotificationCenter.default.post(
                    name: .deepLinkNavigate,
                    object: nil,
                    userInfo: ["destination": "conversation", "id": conversationId]
                )
                return true
            }
            return false
        }

        register("conversation/new") { _ in
            NotificationCenter.default.post(
                name: .deepLinkNavigate,
                object: nil,
                userInfo: ["destination": "newConversation"]
            )
            return true
        }
    }

    private func registerEntityRoutes() {
        register("agent/:id") { link in
            if let agentId = link.parameters["id"] {
                NotificationCenter.default.post(
                    name: .deepLinkNavigate,
                    object: nil,
                    userInfo: ["destination": "agent", "id": agentId]
                )
                return true
            }
            return false
        }

        register("artifact/:id") { link in
            if let artifactId = link.parameters["id"] {
                NotificationCenter.default.post(
                    name: .deepLinkNavigate,
                    object: nil,
                    userInfo: ["destination": "artifact", "id": artifactId]
                )
                return true
            }
            return false
        }

        register("memory/:id") { link in
            if let memoryId = link.parameters["id"] {
                NotificationCenter.default.post(
                    name: .deepLinkNavigate,
                    object: nil,
                    userInfo: ["destination": "memory", "id": memoryId]
                )
                return true
            }
            return false
        }
    }

    private func registerSettingsRoutes() {
        register("settings") { _ in
            NotificationCenter.default.post(
                name: .deepLinkNavigate,
                object: nil,
                userInfo: ["destination": "settings"]
            )
            return true
        }

        register("settings/:section") { link in
            if let section = link.parameters["section"] {
                NotificationCenter.default.post(
                    name: .deepLinkNavigate,
                    object: nil,
                    userInfo: ["destination": "settings", "section": section]
                )
                return true
            }
            return false
        }
    }

    private func registerQuickActionRoutes() {
        register("ask") { link in
            let query = link.queryParameters["q"] ?? link.queryParameters["query"] ?? ""
            NotificationCenter.default.post(
                name: .deepLinkNavigate,
                object: nil,
                userInfo: ["destination": "quickAsk", "query": query]
            )
            return true
        }

        register("voice") { _ in
            NotificationCenter.default.post(
                name: .deepLinkNavigate,
                object: nil,
                userInfo: ["destination": "voiceMode"]
            )
            return true
        }

        register("search") { link in
            let query = link.queryParameters["q"] ?? ""
            NotificationCenter.default.post(
                name: .deepLinkNavigate,
                object: nil,
                userInfo: ["destination": "search", "query": query]
            )
            return true
        }
    }

    private func registerShareImportRoutes() {
        register("share") { link in
            if let text = link.queryParameters["text"] {
                NotificationCenter.default.post(
                    name: .deepLinkNavigate,
                    object: nil,
                    userInfo: ["destination": "shareText", "text": text]
                )
                return true
            }
            return false
        }

        register("import") { link in
            if let url = link.queryParameters["url"] {
                NotificationCenter.default.post(
                    name: .deepLinkNavigate,
                    object: nil,
                    userInfo: ["destination": "import", "url": url]
                )
                return true
            }
            return false
        }
    }

    private func registerWidgetAndSpotlightRoutes() {
        register("widget/:action") { link in
            if let action = link.parameters["action"] {
                NotificationCenter.default.post(
                    name: .deepLinkNavigate,
                    object: nil,
                    userInfo: ["destination": "widget", "action": action]
                )
                return true
            }
            return false
        }

        register("spotlight/:type/:id") { link in
            if let type = link.parameters["type"],
               let id = link.parameters["id"]
            {
                NotificationCenter.default.post(
                    name: .deepLinkNavigate,
                    object: nil,
                    userInfo: ["destination": "spotlight", "type": type, "id": id]
                )
                return true
            }
            return false
        }
    }

    private func registerOAuthRoutes() {
        register("oauth/callback") { link in
            NotificationCenter.default.post(
                name: .deepLinkOAuthCallback,
                object: nil,
                userInfo: ["parameters": link.queryParameters]
            )
            return true
        }
    }

    // MARK: - Navigation

    /// Navigate to a path using the internal URL scheme
    @discardableResult
    public func navigate(to path: String) async -> Bool {
        var components = URLComponents()
        components.scheme = Self.urlScheme
        components.host = ""
        components.path = path.hasPrefix("/") ? path : "/\(path)"

        guard let url = components.url else {
            return false
        }

        return await handle(url)
    }

    // MARK: - URL Handling

    /// Handle incoming URL
    public func handle(_ url: URL) async -> Bool {
        isProcessing = true
        defer { isProcessing = false }

        guard let link = parse(url) else {
            logger.warning("Failed to parse URL: \(url.absoluteString)")
            return false
        }

        logger.info("Handling deep link: \(link.path)")

        // Track analytics
        AnalyticsManager.shared.track("deep_link_opened", properties: [
            "path": link.path,
            "source": link.source.rawValue
        ])

        // Find matching route
        for route in routes {
            if let match = route.match(link) {
                let enrichedLink = DeepLink(
                    url: link.url,
                    source: link.source,
                    path: link.path,
                    parameters: match,
                    queryParameters: link.queryParameters
                )

                if await route.handler(enrichedLink) {
                    lastHandledLink = enrichedLink
                    return true
                }
            }
        }

        // Try wildcard handler
        if let handler = wildcardHandler, await handler(link) {
            lastHandledLink = link
            return true
        }

        logger.warning("No handler found for path: \(link.path)")
        return false
    }

    /// Handle universal link (associated domain)
    public func handleUniversalLink(_ url: URL) async -> Bool {
        guard url.host == Self.universalLinkDomain || url.host == "www.\(Self.universalLinkDomain)" else {
            return false
        }

        // Convert to deep link
        var components = URLComponents()
        components.scheme = Self.urlScheme
        components.host = ""
        components.path = url.path
        components.queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems

        guard let deepLinkURL = components.url else {
            return false
        }

        return await handle(deepLinkURL)
    }

    /// Handle user activity (Handoff, Spotlight, etc.)
    public func handleUserActivity(_ activity: NSUserActivity) async -> Bool {
        // Handle universal link from user activity
        if activity.activityType == NSUserActivityTypeBrowsingWeb,
           let url = activity.webpageURL
        {
            return await handleUniversalLink(url)
        }

        // Handle Spotlight result
        if activity.activityType == "com.thea.app.spotlight" {
            if let identifier = activity.userInfo?["identifier"] as? String,
               let type = activity.userInfo?["type"] as? String
            {
                var components = URLComponents()
                components.scheme = Self.urlScheme
                components.path = "/spotlight/\(type)/\(identifier)"

                if let url = components.url {
                    return await handle(url)
                }
            }
        }

        // Handle Handoff
        if activity.activityType.hasPrefix("com.thea.app.") {
            let action = activity.activityType.replacingOccurrences(of: "com.thea.app.", with: "")

            var components = URLComponents()
            components.scheme = Self.urlScheme
            components.path = "/\(action)"

            // Add user info as query parameters
            if let userInfo = activity.userInfo {
                components.queryItems = userInfo.compactMap { key, value in
                    guard let key = key as? String else { return nil }
                    return URLQueryItem(name: key, value: String(describing: value))
                }
            }

            if let url = components.url {
                return await handle(url)
            }
        }

        return false
    }

    // MARK: - URL Parsing

    private func parse(_ url: URL) -> DeepLink? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }

        let source: DeepLinkSource = if url.scheme == Self.urlScheme {
            .urlScheme
        } else if url.host == Self.universalLinkDomain || url.host == "www.\(Self.universalLinkDomain)" {
            .universalLink
        } else {
            .other
        }

        var path = components.path
        if path.hasPrefix("/") {
            path = String(path.dropFirst())
        }

        let queryParameters = components.queryItems?.reduce(into: [String: String]()) { result, item in
            result[item.name] = item.value ?? ""
        } ?? [:]

        return DeepLink(
            url: url,
            source: source,
            path: path,
            parameters: [:],
            queryParameters: queryParameters
        )
    }

    // MARK: - URL Generation

    /// Generate deep link URL
    public func generateURL(for path: String, parameters: [String: String]? = nil) -> URL? {
        var components = URLComponents()
        components.scheme = Self.urlScheme
        components.host = ""
        components.path = path.hasPrefix("/") ? path : "/\(path)"

        if let params = parameters, !params.isEmpty {
            components.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        }

        return components.url
    }

    /// Generate universal link URL
    public func generateUniversalLink(for path: String, parameters: [String: String]? = nil) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = Self.universalLinkDomain
        components.path = path.hasPrefix("/") ? path : "/\(path)"

        if let params = parameters, !params.isEmpty {
            components.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        }

        return components.url
    }

    // MARK: - Pending Links

    /// Store a pending link (for handling after app is ready)
    public func storePendingLink(_ url: URL) {
        if let link = parse(url) {
            pendingLink = link
            logger.info("Stored pending link: \(link.path)")
        }
    }

    /// Process pending link
    public func processPendingLink() async {
        if let link = pendingLink {
            pendingLink = nil
            _ = await handle(link.url)
        }
    }

    // MARK: - Quick Links

    /// Generate conversation link
    public func conversationLink(id: String) -> URL? {
        generateURL(for: "conversation/\(id)")
    }

    /// Generate agent link
    public func agentLink(id: String) -> URL? {
        generateURL(for: "agent/\(id)")
    }

    /// Generate quick ask link
    public func quickAskLink(query: String) -> URL? {
        generateURL(for: "ask", parameters: ["q": query])
    }

    /// Generate search link
    public func searchLink(query: String) -> URL? {
        generateURL(for: "search", parameters: ["q": query])
    }

    /// Generate share text link
    public func shareTextLink(text: String) -> URL? {
        generateURL(for: "share", parameters: ["text": text])
    }
}

// MARK: - Types

public struct DeepLink: Sendable {
    public let url: URL
    public let source: DeepLinkSource
    public let path: String
    public let parameters: [String: String]
    public let queryParameters: [String: String]

    public var pathComponents: [String] {
        path.components(separatedBy: "/").filter { !$0.isEmpty }
    }
}

public enum DeepLinkSource: String, Sendable {
    case urlScheme
    case universalLink
    case spotlight
    case handoff
    case widget
    case notification
    case shortcut
    case other
}

// MARK: - Route

private struct DeepLinkRoute {
    // periphery:ignore - Reserved: pattern property reserved for future feature activation
    let pattern: String
    let handler: (DeepLink) async -> Bool

    private let patternComponents: [PatternComponent]

    init(pattern: String, handler: @escaping (DeepLink) async -> Bool) {
        self.pattern = pattern
        self.handler = handler
        patternComponents = pattern.components(separatedBy: "/").map { component in
            if component.hasPrefix(":") {
                .parameter(String(component.dropFirst()))
            } else if component == "*" {
                .wildcard
            } else {
                .literal(component)
            }
        }
    }

    func match(_ link: DeepLink) -> [String: String]? {
        let pathComponents = link.pathComponents

        // Check component count (unless pattern has wildcard)
        let hasWildcard = patternComponents.contains { if case .wildcard = $0 { return true }; return false }
        if !hasWildcard, pathComponents.count != patternComponents.count {
            return nil
        }

        var parameters: [String: String] = [:]

        for (index, patternComponent) in patternComponents.enumerated() {
            guard index < pathComponents.count else {
                if case .wildcard = patternComponent {
                    return parameters
                }
                return nil
            }

            let pathComponent = pathComponents[index]

            switch patternComponent {
            case let .literal(value):
                if value != pathComponent {
                    return nil
                }
            case let .parameter(name):
                parameters[name] = pathComponent
            case .wildcard:
                // Match rest of path
                return parameters
            }
        }

        return parameters
    }

    private enum PatternComponent {
        case literal(String)
        case parameter(String)
        case wildcard
    }
}

// MARK: - Notifications

public extension Notification.Name {
    static let deepLinkNavigate = Notification.Name("thea.deepLink.navigate")
    static let deepLinkOAuthCallback = Notification.Name("thea.deepLink.oauthCallback")
}

// MARK: - URL Extension

public extension URL {
    /// Check if URL is a Thea deep link
    var isTheaDeepLink: Bool {
        scheme == DeepLinkRouter.urlScheme ||
            host == DeepLinkRouter.universalLinkDomain ||
            host == "www.\(DeepLinkRouter.universalLinkDomain)"
    }
}
