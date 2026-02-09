import Foundation

// MARK: - Trakt Service for tvOS
// Ported from thea-tizen with improvements

/// Trakt API configuration
enum TraktConfig {
    static let baseURL = "https://api.trakt.tv"
    static let authURL = "https://trakt.tv/oauth/authorize"
    static let tokenURL = "https://api.trakt.tv/oauth/token"
    static let redirectURI = "thea://trakt/callback"
}

// MARK: - Models

struct TraktShow: Codable, Identifiable, Sendable {
    let ids: TraktIDs
    let title: String
    var year: Int?
    var overview: String?
    var runtime: Int?
    var certification: String?
    var network: String?
    var country: String?
    var trailer: String?
    var homepage: String?
    var status: String?
    var rating: Double?
    var votes: Int?
    var genres: [String]?
    var airedEpisodes: Int?

    var id: String { ids.slug ?? ids.trakt?.description ?? UUID().uuidString }

    enum CodingKeys: String, CodingKey {
        case ids, title, year, overview, runtime, certification
        case network, country, trailer, homepage, status, rating, votes, genres
        case airedEpisodes = "aired_episodes"
    }
}

struct TraktMovie: Codable, Identifiable, Sendable {
    let ids: TraktIDs
    let title: String
    var year: Int?
    var tagline: String?
    var overview: String?
    var released: String?
    var runtime: Int?
    var certification: String?
    var trailer: String?
    var homepage: String?
    var rating: Double?
    var votes: Int?
    var genres: [String]?

    var id: String { ids.slug ?? ids.trakt?.description ?? UUID().uuidString }
}

struct TraktIDs: Codable, Sendable {
    var trakt: Int?
    var slug: String?
    var imdb: String?
    var tmdb: Int?
    var tvdb: Int?
}

struct TraktEpisode: Codable, Identifiable, Sendable {
    let season: Int
    let number: Int
    let title: String?
    var overview: String?
    var rating: Double?
    var votes: Int?
    var firstAired: Date?
    var runtime: Int?
    let ids: TraktIDs

    var id: String { "\(season)x\(number)" }

    enum CodingKeys: String, CodingKey {
        case season, number, title, overview, rating, votes, runtime, ids
        case firstAired = "first_aired"
    }
}

struct TraktCalendarEntry: Codable, Identifiable, Sendable {
    let firstAired: Date
    let episode: TraktEpisode
    let show: TraktShow

    var id: String { "\(show.id)-\(episode.id)" }

    enum CodingKeys: String, CodingKey {
        case firstAired = "first_aired"
        case episode, show
    }
}

struct TraktWatchlistItem: Codable, Identifiable, Sendable {
    let rank: Int
    let listedAt: Date
    let type: String
    var show: TraktShow?
    var movie: TraktMovie?

    var id: String { "\(type)-\(show?.id ?? movie?.id ?? UUID().uuidString)" }

    enum CodingKeys: String, CodingKey {
        case rank, type, show, movie
        case listedAt = "listed_at"
    }
}

struct TraktProgress: Codable, Sendable {
    let aired: Int
    let completed: Int
    let lastWatchedAt: Date?
    let nextEpisode: TraktEpisode?
    let lastEpisode: TraktEpisode?

    var percentComplete: Double {
        guard aired > 0 else { return 0 }
        return Double(completed) / Double(aired) * 100
    }

    enum CodingKeys: String, CodingKey {
        case aired, completed
        case lastWatchedAt = "last_watched_at"
        case nextEpisode = "next_episode"
        case lastEpisode = "last_episode"
    }
}

struct TraktUpNextItem: Identifiable, Sendable {
    let show: TraktShow
    let nextEpisode: TraktEpisode
    let progress: TraktProgress
    let posterURL: URL?

    var id: String { "\(show.id)-\(nextEpisode.id)" }
}

// MARK: - Authentication

struct TraktTokens: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let createdAt: Int
    let tokenType: String
    let scope: String

    var isExpired: Bool {
        let expirationDate = Date(timeIntervalSince1970: TimeInterval(createdAt + expiresIn))
        return Date() >= expirationDate
    }

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case createdAt = "created_at"
        case tokenType = "token_type"
        case scope
    }
}

// MARK: - Trakt Service

@MainActor
final class TraktService: ObservableObject {
    static let shared = TraktService()

    @Published private(set) var isAuthenticated = false
    @Published private(set) var isLoading = false
    @Published private(set) var upNext: [TraktUpNextItem] = []
    @Published private(set) var calendar: [TraktCalendarEntry] = []
    @Published private(set) var watchlist: [TraktWatchlistItem] = []
    @Published var error: String?

    private var tokens: TraktTokens?
    private var clientID: String?
    private var clientSecret: String?

    private let tokenStorageKey = "TraktTokens"
    private let credentialsKey = "TraktCredentials"

    private init() {
        loadCredentials()
        loadTokens()
    }

    // MARK: - Configuration

    func configure(clientID: String, clientSecret: String) {
        self.clientID = clientID
        self.clientSecret = clientSecret
        saveCredentials()
    }

    var isConfigured: Bool {
        clientID != nil && clientSecret != nil
    }

    // MARK: - Authentication

    func getAuthorizationURL() -> URL? {
        guard let clientID else { return nil }

        var components = URLComponents(string: TraktConfig.authURL)
        components?.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: TraktConfig.redirectURI)
        ]
        return components?.url
    }

    func handleCallback(code: String) async throws {
        guard let clientID, let clientSecret else {
            throw TraktError.notConfigured
        }

        let body: [String: String] = [
            "code": code,
            "client_id": clientID,
            "client_secret": clientSecret,
            "redirect_uri": TraktConfig.redirectURI,
            "grant_type": "authorization_code"
        ]

        let tokens: TraktTokens = try await post(endpoint: "/oauth/token", body: body, authenticated: false)
        self.tokens = tokens
        self.isAuthenticated = true
        saveTokens()
    }

    func refreshTokenIfNeeded() async throws {
        guard let tokens, tokens.isExpired else { return }
        guard let clientID, let clientSecret else {
            throw TraktError.notConfigured
        }

        let body: [String: String] = [
            "refresh_token": tokens.refreshToken,
            "client_id": clientID,
            "client_secret": clientSecret,
            "redirect_uri": TraktConfig.redirectURI,
            "grant_type": "refresh_token"
        ]

        let newTokens: TraktTokens = try await post(endpoint: "/oauth/token", body: body, authenticated: false)
        self.tokens = newTokens
        saveTokens()
    }

    func logout() {
        tokens = nil
        isAuthenticated = false
        upNext = []
        calendar = []
        watchlist = []
        UserDefaults.standard.removeObject(forKey: tokenStorageKey)
    }

    // MARK: - Data Fetching

    func refreshAll() async {
        guard isAuthenticated else { return }

        isLoading = true
        error = nil

        do {
            try await refreshTokenIfNeeded()

            async let upNextTask = fetchUpNext()
            async let calendarTask = fetchCalendar()
            async let watchlistTask = fetchWatchlist()

            let (upNextResult, calendarResult, watchlistResult) = await (
                try upNextTask,
                try calendarTask,
                try watchlistTask
            )

            upNext = upNextResult
            calendar = calendarResult
            watchlist = watchlistResult
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func fetchUpNext() async throws -> [TraktUpNextItem] {
        // Get shows with progress
        let shows: [TraktShow] = try await get(endpoint: "/users/me/watched/shows?extended=noseasons")

        var items: [TraktUpNextItem] = []

        for show in shows.prefix(20) { // Limit to 20 for performance
            guard let traktID = show.ids.trakt else { continue }

            do {
                let progress: TraktProgress = try await get(
                    endpoint: "/shows/\(traktID)/progress/watched?hidden=false&specials=false"
                )

                if let nextEp = progress.nextEpisode, progress.completed < progress.aired {
                    let posterURL = show.ids.tmdb.flatMap { tmdbID in
                        URL(string: "https://image.tmdb.org/t/p/w300/\(tmdbID).jpg")
                    }

                    items.append(TraktUpNextItem(
                        show: show,
                        nextEpisode: nextEp,
                        progress: progress,
                        posterURL: posterURL
                    ))
                }
            } catch {
                // Skip shows that fail to load progress
                continue
            }
        }

        return items.sorted { ($0.progress.lastWatchedAt ?? .distantPast) > ($1.progress.lastWatchedAt ?? .distantPast) }
    }

    func fetchCalendar(days: Int = 14) async throws -> [TraktCalendarEntry] {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        let startDate = formatter.string(from: Date())

        let entries: [TraktCalendarEntry] = try await get(
            endpoint: "/calendars/my/shows/\(startDate)/\(days)"
        )

        return entries.sorted { $0.firstAired < $1.firstAired }
    }

    func fetchWatchlist() async throws -> [TraktWatchlistItem] {
        let items: [TraktWatchlistItem] = try await get(endpoint: "/users/me/watchlist?extended=full")
        return items.sorted { $0.rank < $1.rank }
    }

    // MARK: - Scrobbling

    /// Empty response struct for fire-and-forget API calls
    private struct EmptyResponse: Decodable {}

    func startWatching(show: TraktShow, episode: TraktEpisode, progress: Double = 0) async throws {
        let body: [String: Any] = [
            "show": ["ids": ["trakt": show.ids.trakt]],
            "episode": ["season": episode.season, "number": episode.number],
            "progress": progress
        ]

        let _: EmptyResponse = try await post(endpoint: "/scrobble/start", body: body, authenticated: true)
    }

    func stopWatching(show: TraktShow, episode: TraktEpisode, progress: Double) async throws {
        let body: [String: Any] = [
            "show": ["ids": ["trakt": show.ids.trakt]],
            "episode": ["season": episode.season, "number": episode.number],
            "progress": progress
        ]

        let _: EmptyResponse = try await post(endpoint: "/scrobble/stop", body: body, authenticated: true)
    }

    // MARK: - Network

    private func get<T: Decodable>(endpoint: String) async throws -> T {
        guard let clientID else { throw TraktError.notConfigured }

        guard let url = URL(string: TraktConfig.baseURL + endpoint) else {
            throw TraktError.invalidURL(endpoint)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2", forHTTPHeaderField: "trakt-api-version")
        request.setValue(clientID, forHTTPHeaderField: "trakt-api-key")

        if let tokens {
            request.setValue("Bearer \(tokens.accessToken)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TraktError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw TraktError.httpError(httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
    }

    private func post<T: Decodable>(endpoint: String, body: Any, authenticated: Bool) async throws -> T {
        guard let url = URL(string: TraktConfig.baseURL + endpoint) else {
            throw TraktError.invalidURL(endpoint)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let clientID {
            request.setValue("2", forHTTPHeaderField: "trakt-api-version")
            request.setValue(clientID, forHTTPHeaderField: "trakt-api-key")
        }

        if authenticated, let tokens {
            request.setValue("Bearer \(tokens.accessToken)", forHTTPHeaderField: "Authorization")
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TraktError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw TraktError.httpError(httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
    }

    // MARK: - Persistence

    private func loadCredentials() {
        guard let data = UserDefaults.standard.data(forKey: credentialsKey),
              let creds = try? JSONDecoder().decode([String: String].self, from: data) else { return }
        clientID = creds["clientID"]
        clientSecret = creds["clientSecret"]
    }

    private func saveCredentials() {
        guard let clientID, let clientSecret else { return }
        let creds = ["clientID": clientID, "clientSecret": clientSecret]
        if let data = try? JSONEncoder().encode(creds) {
            UserDefaults.standard.set(data, forKey: credentialsKey)
        }
    }

    private func loadTokens() {
        guard let data = UserDefaults.standard.data(forKey: tokenStorageKey),
              let tokens = try? JSONDecoder().decode(TraktTokens.self, from: data) else { return }
        self.tokens = tokens
        self.isAuthenticated = !tokens.isExpired
    }

    private func saveTokens() {
        guard let tokens, let data = try? JSONEncoder().encode(tokens) else { return }
        UserDefaults.standard.set(data, forKey: tokenStorageKey)
    }
}

// MARK: - Errors

enum TraktError: LocalizedError {
    case notConfigured
    case invalidResponse
    case invalidURL(String)
    case httpError(Int)
    case decodingError

    var errorDescription: String? {
        switch self {
        case .notConfigured: "Trakt is not configured"
        case .invalidResponse: "Invalid response from server"
        case .invalidURL(let endpoint): "Invalid URL for endpoint: \(endpoint)"
        case .httpError(let code): "HTTP error: \(code)"
        case .decodingError: "Failed to decode response"
        }
    }
}
