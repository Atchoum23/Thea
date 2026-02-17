// NetworkManagerTypes.swift
// Supporting types for NetworkManager

import Foundation
import OSLog

// MARK: - Session Delegate

// @unchecked Sendable: URLSession serializes all delegate callbacks on its internal queue
class NetworkSessionDelegate: NSObject, URLSessionDelegate, URLSessionDataDelegate, URLSessionDownloadDelegate, @unchecked Sendable {
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

// @unchecked Sendable: URLSessionWebSocketTask wrapper — task is thread-safe, isConnected set from delegate
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

/// Intercepts outgoing URL requests before they are sent, allowing header injection or request modification.
public protocol RequestInterceptor: Sendable {
    func intercept(_ request: URLRequest) async -> URLRequest
}

/// Intercepts incoming response data before it reaches the caller, allowing transformation or logging.
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

actor NetworkRateLimiter {
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
                try await Task.sleep(for: .seconds(delay))
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

struct QueuedRequest {
    let request: URLRequest
    let priority: Int
    let completion: (Result<Data, Error>) -> Void
}
