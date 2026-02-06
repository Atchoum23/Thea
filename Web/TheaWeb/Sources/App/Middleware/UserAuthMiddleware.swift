// UserAuthMiddleware.swift
// TheaWeb - User authentication middleware

import Vapor
import Fluent

/// Middleware that authenticates users via bearer token or API key
struct UserAuthMiddleware: AsyncMiddleware {
    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        // Try API key first
        if let apiKey = request.headers.first(name: "X-API-Key") {
            if let user = try await authenticateAPIKey(apiKey, on: request.db) {
                request.auth.login(user)
                return try await next.respond(to: request)
            }
        }

        // Try bearer token
        if let bearerToken = request.headers.bearerAuthorization?.token {
            if let user = try await authenticateBearerToken(bearerToken, on: request.db) {
                request.auth.login(user)
                return try await next.respond(to: request)
            }
        }

        throw Abort(.unauthorized, reason: "Authentication required")
    }

    private func authenticateBearerToken(_ token: String, on db: Database) async throws -> User? {
        let tokenHash = SHA256.hash(data: Data(token.utf8)).hexString

        guard let session = try await Session.query(on: db)
            .filter(\.$tokenHash == tokenHash)
            .filter(\.$isValid == true)
            .with(\.$user)
            .first() else {
            return nil
        }

        // Check expiration
        guard !session.isExpired else {
            session.isValid = false
            try await session.save(on: db)
            return nil
        }

        // Check if user is active
        guard session.user.isActive else {
            return nil
        }

        return session.user
    }

    private func authenticateAPIKey(_ key: String, on db: Database) async throws -> User? {
        let keyHash = SHA256.hash(data: Data(key.utf8)).hexString

        guard let apiKey = try await APIKey.query(on: db)
            .filter(\.$keyHash == keyHash)
            .filter(\.$isActive == true)
            .with(\.$user)
            .first() else {
            return nil
        }

        // Check expiration
        if apiKey.isExpired {
            return nil
        }

        // Check if user is active
        guard apiKey.user.isActive else {
            return nil
        }

        // Update last used timestamp
        apiKey.lastUsedAt = Date()
        try? await apiKey.save(on: db)

        return apiKey.user
    }
}

// MARK: - Optional Authentication

/// Middleware that optionally authenticates users (doesn't require auth)
struct OptionalUserAuthMiddleware: AsyncMiddleware {
    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        // Try to authenticate, but don't fail if not authenticated
        if let bearerToken = request.headers.bearerAuthorization?.token {
            let tokenHash = SHA256.hash(data: Data(bearerToken.utf8)).hexString

            if let session = try await Session.query(on: request.db)
                .filter(\.$tokenHash == tokenHash)
                .filter(\.$isValid == true)
                .with(\.$user)
                .first(),
               !session.isExpired,
               session.user.isActive {
                request.auth.login(session.user)
            }
        }

        return try await next.respond(to: request)
    }
}
