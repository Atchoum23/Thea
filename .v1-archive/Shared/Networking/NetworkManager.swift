// NetworkManager.swift
// Comprehensive networking layer with retry, caching, and monitoring

import Combine
import Foundation
import Network
import OSLog

// MARK: - Network Manager

/// Centralized networking layer with advanced features
@MainActor
public final class NetworkManager: ObservableObject {
    public static let shared = NetworkManager()

    private let logger = Logger(subsystem: "com.thea.app", category: "Network")

    // MARK: - URLSession

    private var defaultSession: URLSession
    private var backgroundSession: URLSession
    private let sessionDelegate = NetworkSessionDelegate()

    // MARK: - Published State

    @Published public private(set) var isConnected = true
    @Published public private(set) var connectionType: ConnectionType = .unknown
    @Published public private(set) var isExpensive = false
    @Published public private(set) var isConstrained = false
    @Published public private(set) var activeRequests: [UUID: RequestInfo] = [:]
    @Published public private(set) var requestHistory: [RequestRecord] = []

    // MARK: - Network Monitor

    private let networkMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.thea.network.monitor")

    // MARK: - Configuration

    private var configuration = NetworkConfiguration()
    private var interceptors: [RequestInterceptor] = []
    private var responseInterceptors: [ResponseInterceptor] = []

    // MARK: - Cache

    private let cache = URLCache(
        memoryCapacity: 50 * 1024 * 1024, // 50 MB
        diskCapacity: 200 * 1024 * 1024, // 200 MB
        diskPath: "thea_network_cache"
    )

    // MARK: - Rate Limiting

    private var rateLimiters: [String: NetworkRateLimiter] = [:]
    private var requestQueue: [QueuedRequest] = []

    // MARK: - Initialization

    private init() {
        // Configure default session
        let defaultConfig = URLSessionConfiguration.default
        defaultConfig.urlCache = cache
        defaultConfig.requestCachePolicy = .useProtocolCachePolicy
        defaultConfig.timeoutIntervalForRequest = 30
        defaultConfig.timeoutIntervalForResource = 300
        defaultConfig.waitsForConnectivity = true
        defaultConfig.httpAdditionalHeaders = [
            "User-Agent": "Thea/1.0",
            "Accept": "application/json",
            "Accept-Language": Locale.current.language.languageCode?.identifier ?? "en"
        ]

        defaultSession = URLSession(configuration: defaultConfig, delegate: sessionDelegate, delegateQueue: nil)

        // Configure background session
        let backgroundConfig = URLSessionConfiguration.background(withIdentifier: "com.thea.network.background")
        backgroundConfig.sessionSendsLaunchEvents = true
        backgroundConfig.isDiscretionary = false

        backgroundSession = URLSession(configuration: backgroundConfig, delegate: sessionDelegate, delegateQueue: nil)

        setupNetworkMonitor()
        setupDefaultInterceptors()
    }

    // MARK: - Network Monitoring

    private func setupNetworkMonitor() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.updateNetworkStatus(path)
            }
        }
        networkMonitor.start(queue: monitorQueue)
    }

    private func updateNetworkStatus(_ path: NWPath) {
        isConnected = path.status == .satisfied
        isExpensive = path.isExpensive
        isConstrained = path.isConstrained

        if path.usesInterfaceType(.wifi) {
            connectionType = .wifi
        } else if path.usesInterfaceType(.cellular) {
            connectionType = .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            connectionType = .ethernet
        } else {
            connectionType = .unknown
        }

        logger.info("Network status: \(self.isConnected ? "connected" : "disconnected"), type: \(self.connectionType.rawValue)")
    }

    // MARK: - Interceptors

    private func setupDefaultInterceptors() {
        // Add authentication interceptor
        addInterceptor(AuthenticationInterceptor())

        // Add logging interceptor
        addInterceptor(LoggingInterceptor())

        // Add response logging
        addResponseInterceptor(ResponseLoggingInterceptor())
    }

    /// Add request interceptor
    public func addInterceptor(_ interceptor: RequestInterceptor) {
        interceptors.append(interceptor)
    }

    /// Add response interceptor
    public func addResponseInterceptor(_ interceptor: ResponseInterceptor) {
        responseInterceptors.append(interceptor)
    }

    // MARK: - Request Methods

    /// Perform a GET request
    public func get<T: Decodable>(
        _ url: URL,
        headers: [String: String]? = nil,
        cachePolicy: CachePolicy = .default,
        retryPolicy: NetworkRetryPolicy = .default
    ) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        headers?.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        return try await performRequest(request, cachePolicy: cachePolicy, retryPolicy: retryPolicy)
    }

    /// Perform a POST request
    public func post<T: Decodable>(
        _ url: URL,
        body: some Encodable,
        headers: [String: String]? = nil,
        retryPolicy: NetworkRetryPolicy = .default
    ) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        headers?.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        return try await performRequest(request, cachePolicy: .noCache, retryPolicy: retryPolicy)
    }

    /// Perform a PUT request
    public func put<T: Decodable>(
        _ url: URL,
        body: some Encodable,
        headers: [String: String]? = nil
    ) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        headers?.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        return try await performRequest(request, cachePolicy: .noCache, retryPolicy: .default)
    }

    /// Perform a DELETE request
    public func delete<T: Decodable>(
        _ url: URL,
        headers: [String: String]? = nil
    ) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        headers?.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        return try await performRequest(request, cachePolicy: .noCache, retryPolicy: .default)
    }

    /// Perform a PATCH request
    public func patch<T: Decodable>(
        _ url: URL,
        body: some Encodable,
        headers: [String: String]? = nil
    ) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        headers?.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        return try await performRequest(request, cachePolicy: .noCache, retryPolicy: .default)
    }

    /// Upload file
    public func upload(
        _ url: URL,
        fileURL: URL,
        headers: [String: String]? = nil,
        progressHandler _: ((Double) -> Void)? = nil
    ) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        headers?.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        let requestId = UUID()
        activeRequests[requestId] = RequestInfo(url: url, method: "UPLOAD", startTime: Date())

        defer { activeRequests.removeValue(forKey: requestId) }

        let (data, response) = try await defaultSession.upload(for: request, fromFile: fileURL)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            throw NetworkError.httpError(httpResponse.statusCode, data)
        }

        return data
    }

    /// Download file
    public func download(
        _ url: URL,
        to destinationURL: URL,
        headers: [String: String]? = nil,
        progressHandler _: ((Double) -> Void)? = nil
    ) async throws {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        headers?.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        let requestId = UUID()
        activeRequests[requestId] = RequestInfo(url: url, method: "DOWNLOAD", startTime: Date())

        defer { activeRequests.removeValue(forKey: requestId) }

        let (tempURL, response) = try await defaultSession.download(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            throw NetworkError.httpError(httpResponse.statusCode, nil)
        }

        try FileManager.default.moveItem(at: tempURL, to: destinationURL)
    }

    // MARK: - Core Request Execution

    private func performRequest<T: Decodable>(
        _ request: URLRequest,
        cachePolicy: CachePolicy,
        retryPolicy: NetworkRetryPolicy
    ) async throws -> T {
        var modifiedRequest = request

        // Apply interceptors
        for interceptor in interceptors {
            modifiedRequest = await interceptor.intercept(modifiedRequest)
        }

        // Check cache
        if cachePolicy != .noCache, let cached = getCachedResponse(for: modifiedRequest) {
            return try JSONDecoder().decode(T.self, from: cached)
        }

        // Check rate limiting
        if let host = modifiedRequest.url?.host {
            try await waitForRateLimit(host: host)
        }

        // Perform request with retry
        var lastError: Error?
        var attempt = 0

        while attempt <= retryPolicy.maxRetries {
            do {
                let requestId = UUID()
                activeRequests[requestId] = RequestInfo(
                    url: modifiedRequest.url!,
                    method: modifiedRequest.httpMethod ?? "GET",
                    startTime: Date()
                )

                let (data, response) = try await defaultSession.data(for: modifiedRequest)

                activeRequests.removeValue(forKey: requestId)

                // Apply response interceptors
                var processedData = data
                for interceptor in responseInterceptors {
                    processedData = await interceptor.intercept(processedData, response: response)
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NetworkError.invalidResponse
                }

                // Record request
                recordRequest(request: modifiedRequest, response: httpResponse, data: processedData)

                // Handle response
                guard (200 ... 299).contains(httpResponse.statusCode) else {
                    if httpResponse.statusCode == 429 {
                        // Rate limited - wait and retry
                        let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After").flatMap { Double($0) } ?? 60
                        try await Task.sleep(nanoseconds: UInt64(retryAfter * 1_000_000_000))
                        attempt += 1
                        continue
                    }
                    throw NetworkError.httpError(httpResponse.statusCode, processedData)
                }

                // Cache if appropriate
                if cachePolicy == .cacheResponse || cachePolicy == .default {
                    cacheResponse(data: processedData, for: modifiedRequest, response: httpResponse)
                }

                return try JSONDecoder().decode(T.self, from: processedData)

            } catch {
                lastError = error
                attempt += 1

                if attempt <= retryPolicy.maxRetries, shouldRetry(error: error, policy: retryPolicy) {
                    let delay = retryPolicy.delay(for: attempt)
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    logger.info("Retrying request (attempt \(attempt)/\(retryPolicy.maxRetries))")
                }
            }
        }

        throw lastError ?? NetworkError.unknown
    }

    // MARK: - Caching

    private func getCachedResponse(for request: URLRequest) -> Data? {
        if let cachedResponse = cache.cachedResponse(for: request) {
            return cachedResponse.data
        }
        return nil
    }

    private func cacheResponse(data: Data, for request: URLRequest, response: HTTPURLResponse) {
        let cachedResponse = CachedURLResponse(response: response, data: data)
        cache.storeCachedResponse(cachedResponse, for: request)
    }

    /// Clear all cached responses
    public func clearCache() {
        cache.removeAllCachedResponses()
        logger.info("Network cache cleared")
    }

    // MARK: - Rate Limiting

    private func waitForRateLimit(host: String) async throws {
        if let limiter = rateLimiters[host] {
            try await limiter.acquire()
        }
    }

    /// Configure rate limiting for a host
    public func setRateLimit(for host: String, requestsPerSecond: Double) {
        rateLimiters[host] = NetworkRateLimiter(requestsPerSecond: requestsPerSecond)
    }

    // MARK: - Retry Logic

    private func shouldRetry(error: Error, policy: NetworkRetryPolicy) -> Bool {
        if let networkError = error as? NetworkError {
            switch networkError {
            case let .httpError(code, _):
                return policy.retryableCodes.contains(code)
            case .timeout, .noConnection:
                return true
            default:
                return false
            }
        }

        if let urlError = error as? URLError {
            return [.timedOut, .networkConnectionLost, .notConnectedToInternet].contains(urlError.code)
        }

        return false
    }

    // MARK: - Request Recording

    private func recordRequest(request: URLRequest, response: HTTPURLResponse, data: Data) {
        let record = RequestRecord(
            url: request.url?.absoluteString ?? "",
            method: request.httpMethod ?? "GET",
            statusCode: response.statusCode,
            responseSize: data.count,
            timestamp: Date()
        )

        requestHistory.append(record)

        // Keep last 100 records
        if requestHistory.count > 100 {
            requestHistory.removeFirst()
        }
    }

    // MARK: - Streaming

    /// Stream response data
    public func stream(_ url: URL, headers: [String: String]? = nil) -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream { continuation in
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            headers?.forEach { request.setValue($1, forHTTPHeaderField: $0) }

            let task = defaultSession.dataTask(with: request)

            sessionDelegate.addStreamHandler(for: task) { data in
                continuation.yield(data)
            } completion: { error in
                if let error {
                    continuation.finish(throwing: error)
                } else {
                    continuation.finish()
                }
            }

            task.resume()

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    // MARK: - WebSocket

    /// Create WebSocket connection
    public func webSocket(url: URL) -> WebSocketConnection {
        let task = defaultSession.webSocketTask(with: url)
        return WebSocketConnection(task: task)
    }

    // MARK: - Configuration

    /// Update network configuration
    public func configure(_ config: NetworkConfiguration) {
        configuration = config

        if let timeout = config.timeout {
            let newConfig = URLSessionConfiguration.default
            newConfig.timeoutIntervalForRequest = timeout
            defaultSession = URLSession(configuration: newConfig, delegate: sessionDelegate, delegateQueue: nil)
        }
    }
}

// MARK: - Session Delegate

private class NetworkSessionDelegate: NSObject, URLSessionDelegate, URLSessionDataDelegate, URLSessionDownloadDelegate, @unchecked Sendable {
    private var streamHandlers: [URLSessionTask: (onData: (Data) -> Void, onComplete: (Error?) -> Void)] = [:]

    func addStreamHandler(for task: URLSessionTask, onData: @escaping (Data) -> Void, completion: @escaping (Error?) -> Void) {
        streamHandlers[task] = (onData, completion)
    }

    func urlSession(_: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        streamHandlers[dataTask]?.onData(data)
    }

    func urlSession(_: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        streamHandlers[task]?.onComplete(error)
        streamHandlers.removeValue(forKey: task)
    }

    func urlSession(_: URLSession, downloadTask _: URLSessionDownloadTask, didFinishDownloadingTo _: URL) {
        // Handle download completion
    }

    func urlSession(_: URLSession, downloadTask _: URLSessionDownloadTask, didWriteData _: Int64, totalBytesWritten _: Int64, totalBytesExpectedToWrite _: Int64) {
        // Report progress
    }
}

// MARK: - WebSocket Connection

public final class WebSocketConnection: ObservableObject, @unchecked Sendable {
    private let task: URLSessionWebSocketTask
    @Published public private(set) var isConnected = false

    init(task: URLSessionWebSocketTask) {
        self.task = task
    }

    public func connect() {
        task.resume()
        isConnected = true
        receiveMessage()
    }

    public func disconnect() {
        task.cancel(with: .goingAway, reason: nil)
        isConnected = false
    }

    public func send(_ message: String) async throws {
        try await task.send(.string(message))
    }

    public func send(_ data: Data) async throws {
        try await task.send(.data(data))
    }

    public func receive() -> AsyncThrowingStream<WebSocketMessage, Error> {
        AsyncThrowingStream { continuation in
            Task {
                while isConnected {
                    do {
                        let message = try await task.receive()
                        switch message {
                        case let .string(text):
                            continuation.yield(.text(text))
                        case let .data(data):
                            continuation.yield(.data(data))
                        @unknown default:
                            break
                        }
                    } catch {
                        continuation.finish(throwing: error)
                        break
                    }
                }
                continuation.finish()
            }
        }
    }

    private func receiveMessage() {
        task.receive { [weak self] _ in
            guard self?.isConnected == true else { return }
            self?.receiveMessage()
        }
    }
}

// MARK: - Interceptors

public protocol RequestInterceptor: Sendable {
    func intercept(_ request: URLRequest) async -> URLRequest
}

public protocol ResponseInterceptor: Sendable {
    func intercept(_ data: Data, response: URLResponse) async -> Data
}

public struct AuthenticationInterceptor: RequestInterceptor {
    public func intercept(_ request: URLRequest) async -> URLRequest {
        var modifiedRequest = request

        // Add auth token if available
        if let token = UserDefaults.standard.string(forKey: "authToken") {
            modifiedRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        return modifiedRequest
    }
}

public struct LoggingInterceptor: RequestInterceptor {
    private let logger = Logger(subsystem: "com.thea.app", category: "Network.Request")

    public func intercept(_ request: URLRequest) async -> URLRequest {
        logger.debug("→ \(request.httpMethod ?? "GET") \(request.url?.absoluteString ?? "")")
        return request
    }
}

public struct ResponseLoggingInterceptor: ResponseInterceptor {
    private let logger = Logger(subsystem: "com.thea.app", category: "Network.Response")

    public func intercept(_ data: Data, response: URLResponse) async -> Data {
        if let httpResponse = response as? HTTPURLResponse {
            logger.debug("← \(httpResponse.statusCode) \(response.url?.absoluteString ?? "") (\(data.count) bytes)")
        }
        return data
    }
}

// MARK: - Rate Limiter

private actor NetworkRateLimiter {
    private let requestsPerSecond: Double
    private var lastRequestTime: Date?

    init(requestsPerSecond: Double) {
        self.requestsPerSecond = requestsPerSecond
    }

    func acquire() async throws {
        if let lastTime = lastRequestTime {
            let minInterval = 1.0 / requestsPerSecond
            let elapsed = Date().timeIntervalSince(lastTime)
            if elapsed < minInterval {
                let delay = minInterval - elapsed
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
        lastRequestTime = Date()
    }
}

// MARK: - Types

public enum ConnectionType: String {
    case wifi
    case cellular
    case ethernet
    case unknown
}

public enum CachePolicy {
    case `default`
    case noCache
    case cacheResponse
    case cacheOnly
}

public struct NetworkRetryPolicy: Sendable {
    public let maxRetries: Int
    public let baseDelay: TimeInterval
    public let maxDelay: TimeInterval
    public let multiplier: Double
    public let retryableCodes: Set<Int>

    public static let `default` = NetworkRetryPolicy(
        maxRetries: 3,
        baseDelay: 1.0,
        maxDelay: 30.0,
        multiplier: 2.0,
        retryableCodes: [408, 429, 500, 502, 503, 504]
    )

    public static let none = NetworkRetryPolicy(
        maxRetries: 0,
        baseDelay: 0,
        maxDelay: 0,
        multiplier: 0,
        retryableCodes: []
    )

    public func delay(for attempt: Int) -> TimeInterval {
        let delay = baseDelay * pow(multiplier, Double(attempt - 1))
        return min(delay, maxDelay)
    }
}

public struct NetworkConfiguration {
    public var timeout: TimeInterval?
    public var cacheEnabled: Bool = true
    public var maxConcurrentRequests: Int = 10

    public init() {}
}

public struct RequestInfo {
    public let url: URL
    public let method: String
    public let startTime: Date
}

public struct RequestRecord: Identifiable {
    public let id = UUID()
    public let url: String
    public let method: String
    public let statusCode: Int
    public let responseSize: Int
    public let timestamp: Date
}

public enum WebSocketMessage {
    case text(String)
    case data(Data)
}

public enum NetworkError: Error, LocalizedError {
    case noConnection
    case timeout
    case invalidResponse
    case httpError(Int, Data?)
    case decodingError(Error)
    case unknown

    public var errorDescription: String? {
        switch self {
        case .noConnection: "No network connection"
        case .timeout: "Request timed out"
        case .invalidResponse: "Invalid response"
        case let .httpError(code, _): "HTTP error: \(code)"
        case let .decodingError(error): "Decoding error: \(error.localizedDescription)"
        case .unknown: "Unknown error"
        }
    }
}

// MARK: - Queued Request

private struct QueuedRequest {
    let request: URLRequest
    let priority: Int
    let completion: (Result<Data, Error>) -> Void
}
