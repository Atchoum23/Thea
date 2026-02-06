// routes.swift
// TheaWeb - API route definitions

import Vapor

/// Registers all application routes
func routes(_ app: Application) throws {
    // MARK: - Health Check

    app.get("health") { _ async -> HealthResponse in
        HealthResponse(
            status: "healthy",
            version: "1.0.0",
            timestamp: Date()
        )
    }

    // MARK: - API v1

    let api = app.grouped("api", "v1")

    // Authentication routes
    try api.register(collection: AuthController())

    // Chat/conversation routes (protected)
    let protected = api.grouped(UserAuthMiddleware())
    try protected.register(collection: ChatController())

    // MARK: - Static Files (for local development)

    // In production, static files are served by CDN
    if app.environment != .production {
        app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
    }
}

// MARK: - Response Types

struct HealthResponse: Content {
    let status: String
    let version: String
    let timestamp: Date
}
