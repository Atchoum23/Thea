// XAPIService.swift
// Thea — AAH3: X (Twitter) v2 API Intelligence Service
//
// Fetches social context from X v2 API using OAuth 2.0 PKCE.
// Bearer token (app-only) and user access token stored in Keychain.
// All network calls use URLSession; no third-party SDK required.
//
// OAuth 2.0 PKCE flow:
//   1. generatePKCE() → (verifier, challenge)
//   2. buildAuthorizationURL() → redirect user to X auth page
//   3. handleCallback(code:) → exchange code for tokens
//   4. Tokens stored in Keychain; refreshed automatically

import CryptoKit
import Foundation
import OSLog
import Security

// MARK: - XAPIService

/// X v2 API service with OAuth 2.0 PKCE authentication.
/// Provides social context (recent posts, timeline) for Thea intelligence.
@MainActor
public final class XAPIService: ObservableObject {
    public static let shared = XAPIService()

    private let logger = Logger(subsystem: "ai.thea.app", category: "XAPIService")

    // MARK: - Published State

    @Published public private(set) var isAuthenticated = false
    @Published public private(set) var currentUserID: String?
    @Published public private(set) var currentUsername: String?
    @Published public private(set) var recentPosts: [XPost] = []
    @Published public private(set) var lastError: XAPIError?
    @Published public private(set) var isFetching = false

    // MARK: - Configuration

    /// App-only bearer token for public-data endpoints (set in Settings).
    /// Stored in Keychain under key `thea.x.bearerToken`.
    public var appBearerToken: String? {
        get { loadFromKeychain(key: "thea.x.bearerToken").flatMap { String(data: $0, encoding: .utf8) } }
        set {
            if let value = newValue, let data = value.data(using: .utf8) {
                saveToKeychain(data, key: "thea.x.bearerToken")
            } else {
                deleteFromKeychain(key: "thea.x.bearerToken")
            }
        }
    }

    /// Client ID from X Developer Portal.
    public var clientID: String = ""

    /// Redirect URI registered in X Developer Portal.
    public var redirectURI: String = "thea://oauth/x/callback"

    // MARK: - Private State

    private var accessToken: String? {
        get { loadFromKeychain(key: "thea.x.accessToken").flatMap { String(data: $0, encoding: .utf8) } }
        set {
            if let value = newValue, let data = value.data(using: .utf8) {
                saveToKeychain(data, key: "thea.x.accessToken")
            } else {
                deleteFromKeychain(key: "thea.x.accessToken")
            }
        }
    }

    private var refreshToken: String? {
        get { loadFromKeychain(key: "thea.x.refreshToken").flatMap { String(data: $0, encoding: .utf8) } }
        set {
            if let value = newValue, let data = value.data(using: .utf8) {
                saveToKeychain(data, key: "thea.x.refreshToken")
            } else {
                deleteFromKeychain(key: "thea.x.refreshToken")
            }
        }
    }

    /// Ephemeral PKCE verifier — only lives for the duration of an auth flow.
    private var pendingCodeVerifier: String?
    private var pendingState: String?

    private let session = URLSession.shared
    private let baseURL = "https://api.twitter.com/2"
    private let authURL = "https://twitter.com/i/oauth2/authorize"
    private let tokenURL = "https://api.twitter.com/2/oauth2/token"

    // MARK: - Init

    private init() {
        isAuthenticated = accessToken != nil
    }

    // MARK: - PKCE Authorization Flow

    /// Generates a PKCE pair and returns the authorization URL for the user to visit.
    /// - Returns: Authorization URL or nil if clientID is not configured.
    public func buildAuthorizationURL(scopes: [String] = ["tweet.read", "users.read", "offline.access"]) -> URL? {
        guard !clientID.isEmpty else {
            logger.error("XAPIService: clientID not configured")
            return nil
        }

        let (verifier, challenge) = generatePKCE()
        let state = generateState()
        pendingCodeVerifier = verifier
        pendingState = state

        var components = URLComponents(string: authURL)
        components?.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "scope", value: scopes.joined(separator: " ")),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
        ]

        return components?.url
    }

    /// Exchanges the authorization code from the callback for an access + refresh token pair.
    /// Call this from your app's URL handler when X redirects back to `redirectURI`.
    public func handleCallback(url: URL) async throws {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value,
              let returnedState = components.queryItems?.first(where: { $0.name == "state" })?.value
        else {
            throw XAPIError.invalidCallbackURL
        }

        guard returnedState == pendingState else {
            throw XAPIError.stateMismatch
        }

        guard let verifier = pendingCodeVerifier else {
            throw XAPIError.missingCodeVerifier
        }

        pendingState = nil
        pendingCodeVerifier = nil

        let tokens = try await exchangeCodeForTokens(code: code, verifier: verifier)
        accessToken = tokens.accessToken
        refreshToken = tokens.refreshToken
        isAuthenticated = true
        logger.info("XAPIService: OAuth2 PKCE exchange successful")

        // Fetch current user immediately
        try await refreshCurrentUser()
    }

    /// Refreshes the access token using the stored refresh token.
    public func refreshAccessToken() async throws {
        guard let refresh = refreshToken, !refresh.isEmpty else {
            throw XAPIError.notAuthenticated
        }

        var request = URLRequest(url: URL(string: tokenURL)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "grant_type": "refresh_token",
            "refresh_token": refresh,
            "client_id": clientID,
        ]
        request.httpBody = body
            .map { "\($0.key)=\(percentEncode($0.value))" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, response) = try await session.data(for: request)
        try validateHTTPResponse(response, data: data)

        let tokenResponse = try JSONDecoder().decode(XTokenResponse.self, from: data)
        accessToken = tokenResponse.accessToken
        if let newRefresh = tokenResponse.refreshToken {
            refreshToken = newRefresh
        }
        logger.info("XAPIService: access token refreshed")
    }

    /// Revokes stored tokens and clears authentication state.
    public func signOut() {
        accessToken = nil
        refreshToken = nil
        isAuthenticated = false
        currentUserID = nil
        currentUsername = nil
        recentPosts = []
        logger.info("XAPIService: signed out")
    }

    // MARK: - API Calls

    /// Fetches the authenticated user's profile.
    @discardableResult
    public func refreshCurrentUser() async throws -> XUser {
        let user = try await get("/users/me", params: ["user.fields": "id,name,username,profile_image_url,public_metrics"],
                                 requiresUserToken: true, responseType: XUserResponse.self).data
        currentUserID = user.id
        currentUsername = user.username
        return user
    }

    /// Fetches recent posts by the authenticated user (up to `maxResults`).
    @discardableResult
    public func fetchRecentPosts(maxResults: Int = 20) async throws -> [XPost] {
        guard let userID = currentUserID else {
            try await refreshCurrentUser()
            guard let uid = currentUserID else { throw XAPIError.notAuthenticated }
            return try await fetchRecentPosts(maxResults: maxResults)
                .map { _ in [] }
                .first ?? (try await _fetchUserTimeline(userID: uid, maxResults: maxResults))
        }
        return try await _fetchUserTimeline(userID: userID, maxResults: maxResults)
    }

    private func _fetchUserTimeline(userID: String, maxResults: Int) async throws -> [XPost] {
        isFetching = true
        defer { isFetching = false }

        let posts = try await get(
            "/users/\(userID)/tweets",
            params: [
                "max_results": "\(min(max(5, maxResults), 100))",
                "tweet.fields": "id,text,created_at,public_metrics,context_annotations",
            ],
            requiresUserToken: true,
            responseType: XPostsResponse.self
        ).data ?? []

        recentPosts = posts
        return posts
    }

    /// Searches recent tweets (public, uses app bearer token).
    public func searchRecentTweets(query: String, maxResults: Int = 10) async throws -> [XPost] {
        let safeQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !safeQuery.isEmpty else { return [] }

        return try await get(
            "/tweets/search/recent",
            params: [
                "query": safeQuery,
                "max_results": "\(min(max(10, maxResults), 100))",
                "tweet.fields": "id,text,created_at,public_metrics",
            ],
            requiresUserToken: false,
            responseType: XPostsResponse.self
        ).data ?? []
    }

    // MARK: - Generic HTTP Helper

    private func get<T: Decodable>(
        _ path: String,
        params: [String: String],
        requiresUserToken: Bool,
        responseType: T.Type
    ) async throws -> T {
        guard var components = URLComponents(string: baseURL + path) else {
            throw XAPIError.invalidURL(baseURL + path)
        }
        components.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }

        guard let url = components.url else { throw XAPIError.invalidURL(baseURL + path) }
        var request = URLRequest(url: url)

        if requiresUserToken {
            guard let token = accessToken else { throw XAPIError.notAuthenticated }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else {
            guard let bearer = appBearerToken else { throw XAPIError.noBearerToken }
            request.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: request)
        try validateHTTPResponse(response, data: data)
        return try JSONDecoder().decode(T.self, from: data)
    }

    // MARK: - Token Exchange

    private func exchangeCodeForTokens(code: String, verifier: String) async throws -> XTokenResponse {
        var request = URLRequest(url: URL(string: tokenURL)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": redirectURI,
            "code_verifier": verifier,
            "client_id": clientID,
        ]
        request.httpBody = body
            .map { "\($0.key)=\(percentEncode($0.value))" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, response) = try await session.data(for: request)
        try validateHTTPResponse(response, data: data)
        return try JSONDecoder().decode(XTokenResponse.self, from: data)
    }

    // MARK: - PKCE Helpers

    private func generatePKCE() -> (verifier: String, challenge: String) {
        var buffer = [UInt8](repeating: 0, count: 64)
        _ = SecRandomCopyBytes(kSecRandomDefault, buffer.count, &buffer)
        let verifier = Data(buffer).base64URLEncoded()

        let challengeData = Data(SHA256.hash(data: Data(verifier.utf8)))
        let challenge = challengeData.base64URLEncoded()

        return (verifier, challenge)
    }

    private func generateState() -> String {
        var buffer = [UInt8](repeating: 0, count: 16)
        _ = SecRandomCopyBytes(kSecRandomDefault, buffer.count, &buffer)
        return Data(buffer).base64URLEncoded()
    }

    private func percentEncode(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? value
    }

    private func validateHTTPResponse(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200 ..< 300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            logger.error("XAPIService HTTP \(http.statusCode): \(body)")
            throw XAPIError.httpError(statusCode: http.statusCode, body: body)
        }
    }

    // MARK: - Keychain Helpers

    private func saveToKeychain(_ data: Data, key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: "ai.thea.social.x",
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked,
        ]
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            logger.error("XAPIService: Keychain save failed for \(key), OSStatus=\(status)")
        }
    }

    private func loadFromKeychain(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: "ai.thea.social.x",
            kSecReturnData as String: true,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    private func deleteFromKeychain(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: "ai.thea.social.x",
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Data Extension (Base64 URL)

private extension Data {
    /// Base64URL encoding without padding (RFC 4648 §5).
    func base64URLEncoded() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

private extension CharacterSet {
    static let urlQueryValueAllowed: CharacterSet = {
        var set = CharacterSet.urlQueryAllowed
        set.remove(charactersIn: "&+=")
        return set
    }()
}

// MARK: - Response Types

private struct XTokenResponse: Decodable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int?
    let tokenType: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
    }
}

private struct XUserResponse: Decodable {
    let data: XUser
}

private struct XPostsResponse: Decodable {
    let data: [XPost]?
}

// MARK: - Public Model Types

public struct XUser: Decodable, Sendable {
    public let id: String
    public let name: String
    public let username: String
    public let profileImageURL: String?
    public let publicMetrics: XUserMetrics?

    enum CodingKeys: String, CodingKey {
        case id, name, username
        case profileImageURL = "profile_image_url"
        case publicMetrics = "public_metrics"
    }
}

public struct XUserMetrics: Decodable, Sendable {
    public let followersCount: Int
    public let followingCount: Int
    public let tweetCount: Int

    enum CodingKeys: String, CodingKey {
        case followersCount = "followers_count"
        case followingCount = "following_count"
        case tweetCount = "tweet_count"
    }
}

public struct XPost: Decodable, Identifiable, Sendable {
    public let id: String
    public let text: String
    public let createdAt: String?
    public let publicMetrics: XPostMetrics?

    enum CodingKeys: String, CodingKey {
        case id, text
        case createdAt = "created_at"
        case publicMetrics = "public_metrics"
    }
}

public struct XPostMetrics: Decodable, Sendable {
    public let retweetCount: Int
    public let likeCount: Int
    public let replyCount: Int

    enum CodingKeys: String, CodingKey {
        case retweetCount = "retweet_count"
        case likeCount = "like_count"
        case replyCount = "reply_count"
    }
}

// MARK: - Errors

public enum XAPIError: Error, LocalizedError, Sendable {
    case invalidCallbackURL
    case stateMismatch
    case missingCodeVerifier
    case notAuthenticated
    case noBearerToken
    case invalidURL(String)
    case httpError(statusCode: Int, body: String)
    case decodingError(String)

    public var errorDescription: String? {
        switch self {
        case .invalidCallbackURL: "Invalid OAuth callback URL from X."
        case .stateMismatch: "OAuth state parameter mismatch — possible CSRF attack."
        case .missingCodeVerifier: "Missing PKCE code verifier — start a new authorization flow."
        case .notAuthenticated: "Not authenticated with X. Complete OAuth2 PKCE flow first."
        case .noBearerToken: "No app bearer token configured. Set XAPIService.shared.appBearerToken."
        case let .invalidURL(url): "Invalid API URL: \(url)"
        case let .httpError(code, body): "X API HTTP \(code): \(body.prefix(200))"
        case let .decodingError(msg): "Failed to decode X API response: \(msg)"
        }
    }
}
