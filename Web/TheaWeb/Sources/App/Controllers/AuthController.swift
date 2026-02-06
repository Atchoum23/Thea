// AuthController.swift
// TheaWeb - Authentication controller with Sign in with Apple

import Vapor
import Fluent
import JWT

/// Controller for authentication endpoints
struct AuthController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let auth = routes.grouped("auth")

        auth.post("apple", use: signInWithApple)
        auth.post("refresh", use: refreshToken)
        auth.post("logout", use: logout)

        // Protected routes
        let protected = auth.grouped(UserAuthMiddleware())
        protected.get("me", use: getCurrentUser)
        protected.delete("account", use: deleteAccount)
    }

    // MARK: - Sign in with Apple

    /// Handle Sign in with Apple callback
    @Sendable
    func signInWithApple(req: Request) async throws -> AuthResponse {
        let input = try req.content.decode(AppleSignInRequest.self)

        // Verify the identity token with Apple
        let appleToken = try await req.jwt.apple.verify(
            input.identityToken,
            applicationIdentifier: Environment.get("APPLE_CLIENT_ID") ?? ""
        )

        // Find or create user
        let user: User
        if let existingUser = try await User.query(on: req.db)
            .filter(\.$appleUserId == appleToken.subject.value)
            .first() {
            user = existingUser
        } else {
            // Create new user
            user = User(
                appleUserId: appleToken.subject.value,
                email: appleToken.email,
                fullName: input.fullName
            )
            try await user.save(on: req.db)
            req.logger.info("New user created: \(user.id?.uuidString ?? "unknown")")
        }

        // Generate session token
        let token = generateSecureToken()
        let tokenHash = SHA256.hash(data: Data(token.utf8)).hexString

        // Create session
        let session = Session(
            userID: user.id!,
            tokenHash: tokenHash,
            expiresAt: Date().addingTimeInterval(30 * 24 * 60 * 60), // 30 days
            userAgent: req.headers.first(name: .userAgent),
            ipHash: hashIP(req.remoteAddress?.ipAddress)
        )
        try await session.save(on: req.db)

        return AuthResponse(
            token: token,
            user: UserDTO(from: user),
            expiresAt: session.expiresAt
        )
    }

    /// Refresh an existing session
    @Sendable
    func refreshToken(req: Request) async throws -> AuthResponse {
        guard let bearerToken = req.headers.bearerAuthorization?.token else {
            throw Abort(.unauthorized, reason: "Missing authorization token")
        }

        let tokenHash = SHA256.hash(data: Data(bearerToken.utf8)).hexString

        guard let session = try await Session.query(on: req.db)
            .filter(\.$tokenHash == tokenHash)
            .filter(\.$isValid == true)
            .with(\.$user)
            .first(),
            !session.isExpired else {
            throw Abort(.unauthorized, reason: "Invalid or expired session")
        }

        // Invalidate old session
        session.isValid = false
        try await session.save(on: req.db)

        // Create new session
        let newToken = generateSecureToken()
        let newTokenHash = SHA256.hash(data: Data(newToken.utf8)).hexString

        let newSession = Session(
            userID: session.user.id!,
            tokenHash: newTokenHash,
            expiresAt: Date().addingTimeInterval(30 * 24 * 60 * 60),
            userAgent: req.headers.first(name: .userAgent),
            ipHash: hashIP(req.remoteAddress?.ipAddress)
        )
        try await newSession.save(on: req.db)

        return AuthResponse(
            token: newToken,
            user: UserDTO(from: session.user),
            expiresAt: newSession.expiresAt
        )
    }

    /// Logout and invalidate session
    @Sendable
    func logout(req: Request) async throws -> HTTPStatus {
        guard let bearerToken = req.headers.bearerAuthorization?.token else {
            throw Abort(.unauthorized)
        }

        let tokenHash = SHA256.hash(data: Data(bearerToken.utf8)).hexString

        if let session = try await Session.query(on: req.db)
            .filter(\.$tokenHash == tokenHash)
            .first() {
            session.isValid = false
            try await session.save(on: req.db)
        }

        return .ok
    }

    /// Get current authenticated user
    @Sendable
    func getCurrentUser(req: Request) async throws -> UserDTO {
        let user = try req.auth.require(User.self)
        return UserDTO(from: user)
    }

    /// Delete user account (GDPR compliance)
    @Sendable
    func deleteAccount(req: Request) async throws -> HTTPStatus {
        let user = try req.auth.require(User.self)

        // Invalidate all sessions
        try await Session.query(on: req.db)
            .filter(\.$user.$id == user.id!)
            .set(\.$isValid, to: false)
            .update()

        // Delete API keys
        try await APIKey.query(on: req.db)
            .filter(\.$user.$id == user.id!)
            .delete()

        // Soft delete user (or hard delete based on policy)
        user.isActive = false
        try await user.save(on: req.db)

        req.logger.info("User account deleted: \(user.id?.uuidString ?? "unknown")")
        return .ok
    }

    // MARK: - Helpers

    private func generateSecureToken() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64EncodedString()
    }

    private func hashIP(_ ip: String?) -> String? {
        guard let ip = ip else { return nil }
        return SHA256.hash(data: Data(ip.utf8)).hexString
    }
}

// MARK: - Request/Response Types

struct AppleSignInRequest: Content {
    let identityToken: String
    let authorizationCode: String?
    let fullName: String?
}

struct AuthResponse: Content {
    let token: String
    let user: UserDTO
    let expiresAt: Date
}

struct UserDTO: Content {
    let id: UUID
    let email: String?
    let fullName: String?
    let subscriptionTier: SubscriptionTier
    let createdAt: Date?

    init(from user: User) {
        self.id = user.id ?? UUID()
        self.email = user.email
        self.fullName = user.fullName
        self.subscriptionTier = user.subscriptionTier
        self.createdAt = user.createdAt
    }
}

// MARK: - SHA256 Extension

extension SHA256.Digest {
    var hexString: String {
        self.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Authenticatable Conformance

extension User: Authenticatable {}
