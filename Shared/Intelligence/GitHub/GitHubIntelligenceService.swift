// GitHubIntelligenceService.swift
// Thea — AAG3: Cloud Storage + GitHub Intelligence
//
// GitHub REST v3 integration using Personal Access Token auth.
// URLSession only — no SPM packages.
//
// Required scopes: notifications, repo (for PRs)
// Token stored in Keychain: SettingsManager.getAPIKey(for: "github")
//
// Wire into: PersonalParameters.snapshot() for morning briefing context.

import Foundation
import OSLog

// MARK: - GitHub Types

struct GitHubNotification: Sendable {
    let id: String // periphery:ignore - Reserved: Wave 10 service — wired in future integration phase
    let title: String // periphery:ignore - Reserved: Wave 10 service — wired in future integration phase
    let type: String      // "PullRequest", "Issue", "Release", etc. // periphery:ignore - Reserved: Wave 10 service — wired in future integration phase
    let repoName: String // periphery:ignore - Reserved: Wave 10 service — wired in future integration phase
    let updatedAt: Date? // periphery:ignore - Reserved: Wave 10 service — wired in future integration phase
}

struct GitHubPullRequest: Sendable {
    let id: Int // periphery:ignore - Reserved: Wave 10 service — wired in future integration phase
    let number: Int // periphery:ignore - Reserved: Wave 10 service — wired in future integration phase
    let title: String // periphery:ignore - Reserved: Wave 10 service — wired in future integration phase
    let repoName: String // periphery:ignore - Reserved: Wave 10 service — wired in future integration phase
    let state: String // periphery:ignore - Reserved: Wave 10 service — wired in future integration phase
    let updatedAt: Date? // periphery:ignore - Reserved: Wave 10 service — wired in future integration phase
    let htmlURL: String // periphery:ignore - Reserved: Wave 10 service — wired in future integration phase
}

// MARK: - GitHubIntelligenceService

actor GitHubIntelligenceService {
    static let shared = GitHubIntelligenceService()

    private let logger = Logger(subsystem: "ai.thea.app", category: "GitHubIntelligenceService")
    private let baseURL = "https://api.github.com"
    private let isoFormatter = ISO8601DateFormatter()

    // MARK: - Notifications

    /// Fetch unread notifications.
    /// - Parameter token: GitHub PAT with `notifications` scope.
    func fetchNotifications(token: String) async throws -> [GitHubNotification] {
        let url = URL(string: "\(baseURL)/notifications?all=false&participating=false&per_page=50")!
        let data = try await get(url: url, token: token)

        guard let items = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw GitHubError.parseError
        }

        return items.compactMap { item in
            let subject = item["subject"] as? [String: Any] ?? [:]
            let repo = item["repository"] as? [String: Any] ?? [:]
            let updatedAt = (item["updated_at"] as? String).flatMap { isoFormatter.date(from: $0) }
            return GitHubNotification(
                id: item["id"] as? String ?? UUID().uuidString,
                title: subject["title"] as? String ?? "Untitled",
                type: subject["type"] as? String ?? "Unknown",
                repoName: repo["full_name"] as? String ?? "",
                updatedAt: updatedAt
            )
        }
    }

    /// Convenience: fetch notifications using stored PAT.
    func fetchNotifications() async throws -> [GitHubNotification] { // periphery:ignore - Reserved: Wave 10 service — wired in future integration phase
        let token = try await requireToken()
        return try await fetchNotifications(token: token)
    }

    // MARK: - Pull Requests

    /// Fetch open PRs authored by username.
    /// - Parameters:
    ///   - token: GitHub PAT with `repo` scope.
    ///   - username: GitHub username.
    func fetchMyPRs(token: String, username: String) async throws -> [GitHubPullRequest] {
        let encoded = username.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? username
        let urlStr = "\(baseURL)/search/issues?q=is:pr+author:\(encoded)+state:open&per_page=50"
        let url = URL(string: urlStr)!
        let data = try await get(url: url, token: token)

        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let items = json["items"] as? [[String: Any]]
        else {
            throw GitHubError.parseError
        }

        return items.map { item in
            let repoURL = item["repository_url"] as? String ?? ""
            let repoName = repoURL.components(separatedBy: "/repos/").last ?? repoURL
            let updatedAt = (item["updated_at"] as? String).flatMap { isoFormatter.date(from: $0) }
            return GitHubPullRequest(
                id: item["id"] as? Int ?? 0,
                number: item["number"] as? Int ?? 0,
                title: item["title"] as? String ?? "Untitled",
                repoName: repoName,
                state: item["state"] as? String ?? "open",
                updatedAt: updatedAt,
                htmlURL: item["html_url"] as? String ?? ""
            )
        }
    }

    /// Convenience: fetch open PRs using stored PAT and stored username.
    func fetchMyPRs() async throws -> [GitHubPullRequest] { // periphery:ignore - Reserved: Wave 10 service — wired in future integration phase
        let token = try await requireToken()
        let username = await MainActor.run { SettingsManager.shared.getAPIKey(for: "github_username") } ?? ""
        guard !username.isEmpty else { throw GitHubError.missingUsername }
        return try await fetchMyPRs(token: token, username: username)
    }

    // MARK: - Morning Briefing

    /// Generate a one-line morning briefing string for PersonalParameters.snapshot().
    /// Example: "GitHub: 5 notifications, 3 open PRs"
    func morningBriefing(token: String, username: String) async -> String {
        async let notificationsResult = fetchNotifications(token: token)
        async let prsResult = fetchMyPRs(token: token, username: username)

        let notifications = (try? await notificationsResult) ?? []
        let prs = (try? await prsResult) ?? []

        logger.info("GitHub morning briefing: \(notifications.count) notifications, \(prs.count) open PRs")
        return "GitHub: \(notifications.count) notification\(notifications.count == 1 ? "" : "s"), \(prs.count) open PR\(prs.count == 1 ? "" : "s")"
    }

    /// Convenience: morning briefing using stored credentials.
    func morningBriefing() async -> String {
        guard let token = try? await requireToken() else {
            return "GitHub: not configured"
        }
        let username = await MainActor.run { SettingsManager.shared.getAPIKey(for: "github_username") } ?? ""
        guard !username.isEmpty else { return "GitHub: username not configured" }
        return await morningBriefing(token: token, username: username)
    }

    // MARK: - Repository Metadata

    /// Fetch basic metadata for a repo (stars, open issues, last push).
    func fetchRepoInfo(token: String, owner: String, repo: String) async throws -> [String: Any] { // periphery:ignore - Reserved: Wave 10 service — wired in future integration phase
        let url = URL(string: "\(baseURL)/repos/\(owner)/\(repo)")!
        let data = try await get(url: url, token: token)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw GitHubError.parseError
        }
        return json
    }

    // MARK: - Private HTTP

    private func get(url: URL, token: String) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.timeoutInterval = 20

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw GitHubError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            logger.error("GitHub API HTTP \(http.statusCode) for \(url.path)")
            throw GitHubError.httpError(http.statusCode)
        }
        return data
    }

    private func requireToken() async throws -> String {
        guard let token = await MainActor.run(resultType: String?.self, body: { SettingsManager.shared.getAPIKey(for: "github") }),
              !token.isEmpty else {
            throw GitHubError.missingToken
        }
        return token
    }

    // MARK: - Errors

    enum GitHubError: Error, LocalizedError {
        case missingToken
        case missingUsername
        case invalidResponse
        case httpError(Int)
        case parseError

        var errorDescription: String? {
            switch self {
            case .missingToken:       return "GitHub PAT not configured (key: 'github')"
            case .missingUsername:    return "GitHub username not configured (key: 'github_username')"
            case .invalidResponse:    return "Invalid response from GitHub API"
            case .httpError(let c):   return "GitHub API returned HTTP \(c)"
            case .parseError:         return "Failed to parse GitHub API response"
            }
        }
    }
}
