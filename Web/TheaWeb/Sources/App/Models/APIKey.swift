// APIKey.swift
// TheaWeb - API key model for programmatic access

import Fluent
import Vapor

/// API key for programmatic access to Thea
// @unchecked Sendable: Fluent Model — thread safety managed by database layer
final class APIKey: Model, Content, @unchecked Sendable {
    static let schema = "api_keys"

    @ID(key: .id)
    var id: UUID?

    /// Reference to the user
    @Parent(key: "user_id")
    var user: User

    /// Key name for identification
    @Field(key: "name")
    var name: String

    /// API key hash (never store plain text)
    @Field(key: "key_hash")
    var keyHash: String

    /// Key prefix for display (first 8 chars)
    @Field(key: "key_prefix")
    var keyPrefix: String

    /// Creation timestamp
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    /// Last used timestamp
    @OptionalField(key: "last_used_at")
    var lastUsedAt: Date?

    /// Expiration date (optional)
    @OptionalField(key: "expires_at")
    var expiresAt: Date?

    /// Whether key is active
    @Field(key: "is_active")
    var isActive: Bool

    /// Rate limit override (requests per minute)
    @OptionalField(key: "rate_limit")
    var rateLimit: Int?

    /// Allowed scopes
    @Field(key: "scopes")
    var scopes: [String]

    init() {}

    init(
        id: UUID? = nil,
        userID: UUID,
        name: String,
        keyHash: String,
        keyPrefix: String,
        expiresAt: Date? = nil,
        isActive: Bool = true,
        rateLimit: Int? = nil,
        scopes: [String] = ["read", "write"]
    ) {
        self.id = id
        self.$user.id = userID
        self.name = name
        self.keyHash = keyHash
        self.keyPrefix = keyPrefix
        self.expiresAt = expiresAt
        self.isActive = isActive
        self.rateLimit = rateLimit
        self.scopes = scopes
    }

    /// Check if key is expired
    var isExpired: Bool {
        guard let expiresAt = expiresAt else { return false }
        return Date() > expiresAt
    }
}

/// Migration to create API keys table
struct CreateAPIKey: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("api_keys")
            .id()
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("name", .string, .required)
            .field("key_hash", .string, .required)
            .field("key_prefix", .string, .required)
            .field("created_at", .datetime)
            .field("last_used_at", .datetime)
            .field("expires_at", .datetime)
            .field("is_active", .bool, .required)
            .field("rate_limit", .int)
            .field("scopes", .array(of: .string), .required)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("api_keys").delete()
    }
}
