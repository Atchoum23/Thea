// configure.swift
// TheaWeb - Application configuration

import Vapor
import Fluent
import FluentSQLiteDriver
import JWT
import Redis

/// Configures the Vapor application
func configure(_ app: Application) async throws {
    // MARK: - Database Configuration

    // Use SQLite for development, PostgreSQL for production
    if app.environment == .production {
        // Production: Use PostgreSQL via environment variable
        // DATABASE_URL should be set in the environment
        guard let databaseURL = Environment.get("DATABASE_URL") else {
            app.logger.warning("DATABASE_URL not set, falling back to SQLite")
            app.databases.use(.sqlite(.file("thea.sqlite")), as: .sqlite)
            return
        }
        // PostgreSQL configuration would go here
        app.logger.info("Using production database")
    } else {
        // Development: Use SQLite file
        app.databases.use(.sqlite(.file("thea_dev.sqlite")), as: .sqlite)
    }

    // MARK: - Migrations

    app.migrations.add(CreateUser())
    app.migrations.add(CreateSession())
    app.migrations.add(CreateAPIKey())
    try await app.autoMigrate()

    // MARK: - JWT Configuration (Sign in with Apple)

    // Apple's public keys for JWT verification
    // These are fetched from https://appleid.apple.com/auth/keys
    if let appleTeamId = Environment.get("APPLE_TEAM_ID"),
       let appleClientId = Environment.get("APPLE_CLIENT_ID") {
        app.jwt.apple.applicationIdentifier = appleClientId
        app.logger.info("Sign in with Apple configured for team: \(appleTeamId)")
    } else {
        app.logger.warning("APPLE_TEAM_ID and APPLE_CLIENT_ID not set - Sign in with Apple disabled")
    }

    // MARK: - Redis Configuration (Rate Limiting & Sessions)

    if let redisURL = Environment.get("REDIS_URL") {
        app.redis.configuration = try RedisConfiguration(url: redisURL)
        app.logger.info("Redis configured for rate limiting")
    }

    // MARK: - Middleware

    // CORS for frontend access
    let corsConfiguration = CORSMiddleware.Configuration(
        allowedOrigin: .any(["https://theathe.app", "http://localhost:3000"]),
        allowedMethods: [.GET, .POST, .PUT, .DELETE, .OPTIONS],
        allowedHeaders: [.accept, .authorization, .contentType, .origin, .xRequestedWith]
    )
    app.middleware.use(CORSMiddleware(configuration: corsConfiguration))

    // Rate limiting
    app.middleware.use(RateLimitMiddleware(requestsPerMinute: 100))

    // Security headers
    app.middleware.use(SecurityHeadersMiddleware())

    // Error handling
    app.middleware.use(ErrorMiddleware.default(environment: app.environment))

    // MARK: - Routes

    try routes(app)

    app.logger.info("TheaWeb configured successfully")
}
