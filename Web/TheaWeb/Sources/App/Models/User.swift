// User.swift
// TheaWeb - User model for authentication

import Fluent
import Vapor

/// User model for Sign in with Apple authentication
final class User: Model, Content, @unchecked Sendable {
    static let schema = "users"

    @ID(key: .id)
    var id: UUID?

    /// Apple user identifier (sub claim from JWT)
    @Field(key: "apple_user_id")
    var appleUserId: String

    /// User's email (may be private relay)
    @OptionalField(key: "email")
    var email: String?

    /// User's full name (only provided on first sign-in)
    @OptionalField(key: "full_name")
    var fullName: String?

    /// Account creation date
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    /// Last login date
    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    /// User's subscription tier
    @Enum(key: "subscription_tier")
    var subscriptionTier: SubscriptionTier

    /// Whether the account is active
    @Field(key: "is_active")
    var isActive: Bool

    init() {}

    init(
        id: UUID? = nil,
        appleUserId: String,
        email: String? = nil,
        fullName: String? = nil,
        subscriptionTier: SubscriptionTier = .free,
        isActive: Bool = true
    ) {
        self.id = id
        self.appleUserId = appleUserId
        self.email = email
        self.fullName = fullName
        self.subscriptionTier = subscriptionTier
        self.isActive = isActive
    }
}

/// Subscription tiers for Thea
enum SubscriptionTier: String, Codable {
    case free
    case pro
    case team
}

/// Migration to create users table
struct CreateUser: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("users")
            .id()
            .field("apple_user_id", .string, .required)
            .field("email", .string)
            .field("full_name", .string)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .field("subscription_tier", .string, .required)
            .field("is_active", .bool, .required)
            .unique(on: "apple_user_id")
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("users").delete()
    }
}
