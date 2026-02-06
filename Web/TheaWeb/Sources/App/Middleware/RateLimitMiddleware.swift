// RateLimitMiddleware.swift
// TheaWeb - Rate limiting middleware for API protection

import Vapor

/// Rate limiting middleware using sliding window algorithm
/// Uses in-memory storage for development, Redis for production
struct RateLimitMiddleware: AsyncMiddleware {
    let requestsPerMinute: Int
    let windowSeconds: Int

    init(requestsPerMinute: Int = 100, windowSeconds: Int = 60) {
        self.requestsPerMinute = requestsPerMinute
        self.windowSeconds = windowSeconds
    }

    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        // Get client identifier (IP or API key)
        let clientId = getClientIdentifier(from: request)

        // Check rate limit
        let allowed = try await checkRateLimit(
            clientId: clientId,
            request: request
        )

        guard allowed else {
            throw Abort(.tooManyRequests, reason: "Rate limit exceeded. Please try again later.")
        }

        // Continue to next middleware/handler
        let response = try await next.respond(to: request)

        // Add rate limit headers
        response.headers.add(name: "X-RateLimit-Limit", value: "\(requestsPerMinute)")
        response.headers.add(name: "X-RateLimit-Remaining", value: "\(max(0, requestsPerMinute - 1))")
        response.headers.add(name: "X-RateLimit-Reset", value: "\(Int(Date().timeIntervalSince1970) + windowSeconds)")

        return response
    }

    private func getClientIdentifier(from request: Request) -> String {
        // Prefer API key if present
        if let apiKey = request.headers.first(name: "X-API-Key") {
            return "apikey:\(apiKey.prefix(16))"
        }

        // Use bearer token if present
        if let token = request.headers.bearerAuthorization?.token {
            return "token:\(token.prefix(16))"
        }

        // Fall back to IP address
        return "ip:\(request.remoteAddress?.ipAddress ?? "unknown")"
    }

    private func checkRateLimit(clientId: String, request: Request) async throws -> Bool {
        // Try Redis first (production)
        if let redis = request.redis {
            return try await checkRedisRateLimit(clientId: clientId, redis: redis)
        }

        // Fall back to in-memory (development)
        return await InMemoryRateLimiter.shared.checkLimit(
            clientId: clientId,
            limit: requestsPerMinute,
            windowSeconds: windowSeconds
        )
    }

    private func checkRedisRateLimit(clientId: String, redis: Request.Redis) async throws -> Bool {
        let key = "ratelimit:\(clientId)"
        let now = Int(Date().timeIntervalSince1970)

        // Sliding window using Redis sorted set
        // Remove old entries outside window
        _ = try? await redis.zremrangebyscore(
            from: RedisKey(key),
            withMinimumScoreOf: .inclusive(.init(integerLiteral: 0)),
            andMaximumScoreOf: .inclusive(.init(integerLiteral: now - windowSeconds))
        ).get()

        // Count current entries
        let count = try await redis.zcard(of: RedisKey(key)).get()

        if count >= requestsPerMinute {
            return false
        }

        // Add current request
        _ = try? await redis.zadd(
            [(element: RESPValue(from: UUID().uuidString), score: Double(now))],
            to: RedisKey(key)
        ).get()

        // Set expiry on the key
        _ = try? await redis.expire(RedisKey(key), after: .seconds(Int64(windowSeconds * 2))).get()

        return true
    }
}

// MARK: - In-Memory Rate Limiter (Development)

actor InMemoryRateLimiter {
    static let shared = InMemoryRateLimiter()

    private var requests: [String: [Date]] = [:]
    private let cleanupInterval: TimeInterval = 300 // 5 minutes

    private init() {
        Task {
            await periodicCleanup()
        }
    }

    func checkLimit(clientId: String, limit: Int, windowSeconds: Int) -> Bool {
        let now = Date()
        let windowStart = now.addingTimeInterval(-Double(windowSeconds))

        // Get and filter requests within window
        var clientRequests = requests[clientId] ?? []
        clientRequests = clientRequests.filter { $0 > windowStart }

        // Check limit
        if clientRequests.count >= limit {
            return false
        }

        // Add current request
        clientRequests.append(now)
        requests[clientId] = clientRequests

        return true
    }

    private func periodicCleanup() async {
        while true {
            try? await Task.sleep(for: .seconds(cleanupInterval))

            let cutoff = Date().addingTimeInterval(-600) // 10 minutes
            for (clientId, timestamps) in requests {
                let filtered = timestamps.filter { $0 > cutoff }
                if filtered.isEmpty {
                    requests.removeValue(forKey: clientId)
                } else {
                    requests[clientId] = filtered
                }
            }
        }
    }
}
