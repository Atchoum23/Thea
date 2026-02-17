// Session.swift
// TheaWeb - User session model

import Fluent
import Vapor

/// Session model for tracking authenticated sessions
// @unchecked Sendable: Fluent Model — thread safety managed by database layer
final class Session: Model, Content, @unchecked Sendable {
    static let schema = "sessions"

    @ID(key: .id)
    var id: UUID?

    /// Reference to the user
    @Parent(key: "user_id")
    var user: User

    /// Session token (hashed)
    @Field(key: "token_hash")
    var tokenHash: String

    /// Session creation time
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    /// Session expiration time
    @Field(key: "expires_at")
    var expiresAt: Date

    /// Client information
    @OptionalField(key: "user_agent")
    var userAgent: String?

    /// IP address (hashed for privacy)
    @OptionalField(key: "ip_hash")
    var ipHash: String?

    /// Whether session is still valid
    @Field(key: "is_valid")
    var isValid: Bool

    init() {}

    init(
        id: UUID? = nil,
        userID: UUID,
        tokenHash: String,
        expiresAt: Date,
        userAgent: String? = nil,
        ipHash: String? = nil,
        isValid: Bool = true
    ) {
        self.id = id
        self.$user.id = userID
        self.tokenHash = tokenHash
        self.expiresAt = expiresAt
        self.userAgent = userAgent
        self.ipHash = ipHash
        self.isValid = isValid
    }

    /// Check if session is expired
    var isExpired: Bool {
        Date() > expiresAt
    }
}

/// Migration to create sessions table
struct CreateSession: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("sessions")
            .id()
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("token_hash", .string, .required)
            .field("created_at", .datetime)
            .field("expires_at", .datetime, .required)
            .field("user_agent", .string)
            .field("ip_hash", .string)
            .field("is_valid", .bool, .required)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("sessions").delete()
    }
}
