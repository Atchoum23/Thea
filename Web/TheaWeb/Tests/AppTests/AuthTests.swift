// AuthTests.swift
// TheaWeb - Authentication tests

import XCTest
import XCTVapor
@testable import App

final class AuthTests: XCTestCase {
    var app: Application!

    override func setUp() async throws {
        app = try await Application.make(.testing)
        try await configure(app)
    }

    override func tearDown() async throws {
        try await app.asyncShutdown()
    }

    // MARK: - Health Check

    func testHealthEndpoint() async throws {
        try await app.test(.GET, "health") { res async in
            XCTAssertEqual(res.status, .ok)

            do {
                let health = try res.content.decode(HealthResponse.self)
                XCTAssertEqual(health.status, "healthy")
                XCTAssertEqual(health.version, "1.0.0")
            } catch {
                XCTFail("Failed to decode health response: \(error)")
            }
        }
    }

    // MARK: - Rate Limiting

    func testRateLimitHeaders() async throws {
        try await app.test(.GET, "health") { res async in
            XCTAssertNotNil(res.headers.first(name: "X-RateLimit-Limit"))
            XCTAssertNotNil(res.headers.first(name: "X-RateLimit-Remaining"))
            XCTAssertNotNil(res.headers.first(name: "X-RateLimit-Reset"))
        }
    }

    // MARK: - Security Headers

    func testSecurityHeaders() async throws {
        try await app.test(.GET, "health") { res async in
            XCTAssertEqual(res.headers.first(name: "X-Frame-Options"), "DENY")
            XCTAssertEqual(res.headers.first(name: "X-Content-Type-Options"), "nosniff")
            XCTAssertNotNil(res.headers.first(name: "Referrer-Policy"))
        }
    }

    // MARK: - Authentication Required

    func testProtectedRouteRequiresAuth() async throws {
        try await app.test(.GET, "api/v1/auth/me") { res async in
            XCTAssertEqual(res.status, .unauthorized)
        }
    }

    func testChatRequiresAuth() async throws {
        try await app.test(.POST, "api/v1/chat/message") { res async in
            XCTAssertEqual(res.status, .unauthorized)
        }
    }

    // MARK: - CORS

    func testCORSHeaders() async throws {
        try await app.test(.OPTIONS, "api/v1/auth/me", headers: [
            "Origin": "https://theathe.app",
            "Access-Control-Request-Method": "GET"
        ]) { res async in
            XCTAssertNotNil(res.headers.first(name: "Access-Control-Allow-Origin"))
            XCTAssertNotNil(res.headers.first(name: "Access-Control-Allow-Methods"))
        }
    }
}
