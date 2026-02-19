// PrivacyPolicies.swift
// Thea — Built-in Privacy Policy Implementations
//
// Each policy defines what data may leave the device for a specific channel type.

import Foundation

// MARK: - Cloud API Policy

/// Standard policy for cloud AI providers (Anthropic, OpenAI, Google, etc.)
/// Allows conversation context but redacts obvious PII and credentials.
struct CloudAPIPolicy: PrivacyPolicy {
    let name = "Cloud API"
    let strictnessLevel: StrictnessLevel = .standard
    let allowPII = false
    let allowFilePaths = false
    // periphery:ignore - Reserved: allowCodeSnippets property — reserved for future feature activation
    let allowCodeSnippets = true
    // periphery:ignore - Reserved: allowHealthData property — reserved for future feature activation
    let allowHealthData = false
    // periphery:ignore - Reserved: allowFinancialData property — reserved for future feature activation
    let allowFinancialData = false
    let blockedKeywords: Set<String> = []
    let allowedTopics: Set<String>? = nil
    let maxContentLength = 0 // Unlimited — provider handles limits
}

// MARK: - Messaging Policy

/// Policy for outbound messages via OpenClaw (WhatsApp, Telegram, etc.)
/// No PII, but can reference tasks and calendar items by title.
struct MessagingPolicy: PrivacyPolicy {
    let name = "Messaging"
    let strictnessLevel: StrictnessLevel = .strict
    // periphery:ignore - Reserved: allowCodeSnippets property reserved for future feature activation
    // periphery:ignore - Reserved: allowHealthData property reserved for future feature activation
    // periphery:ignore - Reserved: allowFinancialData property reserved for future feature activation
    let allowPII = false
    let allowFilePaths = false
    // periphery:ignore - Reserved: allowCodeSnippets property — reserved for future feature activation
    let allowCodeSnippets = false
    // periphery:ignore - Reserved: allowHealthData property — reserved for future feature activation
    let allowHealthData = false
    // periphery:ignore - Reserved: allowFinancialData property — reserved for future feature activation
    let allowFinancialData = false
    let blockedKeywords: Set<String> = [
        "password", "secret", "api key", "token",
        "credit card", "bank account", "social security"
    ]
    let allowedTopics: Set<String>? = nil
    let maxContentLength = 4096
}

// MARK: - MCP Policy

// periphery:ignore - Reserved: allowCodeSnippets property reserved for future feature activation

// periphery:ignore - Reserved: allowHealthData property reserved for future feature activation

// periphery:ignore - Reserved: allowFinancialData property reserved for future feature activation

/// Policy for MCP tool responses (Claude Desktop calling Thea tools).
/// Strict — filter sensitive local data from tool responses.
struct MCPPolicy: PrivacyPolicy {
    let name = "MCP"
    let strictnessLevel: StrictnessLevel = .strict
    let allowPII = false
    let allowFilePaths = true // MCP tools often return file info
    let allowCodeSnippets = true
    let allowHealthData = false
    let allowFinancialData = false
    let blockedKeywords: Set<String> = [
        "password", "secret key", "private key"
    ]
    let allowedTopics: Set<String>? = nil
    let maxContentLength = 0
}

// periphery:ignore - Reserved: allowCodeSnippets property reserved for future feature activation

// periphery:ignore - Reserved: allowHealthData property reserved for future feature activation

// periphery:ignore - Reserved: allowFinancialData property reserved for future feature activation

// MARK: - Web API Policy

/// Policy for HTTP responses from TheaWeb / Vapor endpoints.
struct WebAPIPolicy: PrivacyPolicy {
    let name = "Web API"
    let strictnessLevel: StrictnessLevel = .standard
    let allowPII = false
    let allowFilePaths = false
    let allowCodeSnippets = true
    let allowHealthData = false
    let allowFinancialData = false
    let blockedKeywords: Set<String> = []
    let allowedTopics: Set<String>? = nil
    let maxContentLength = 0
// periphery:ignore - Reserved: allowCodeSnippets property reserved for future feature activation
// periphery:ignore - Reserved: allowHealthData property reserved for future feature activation
// periphery:ignore - Reserved: allowFinancialData property reserved for future feature activation
}

// MARK: - Moltbook Policy

/// Paranoid policy for Moltbook agent — only public development topics.
/// No personal data whatsoever. Only approved dev discussion topics.
struct MoltbookPolicy: PrivacyPolicy {
    let name = "Moltbook"
    let strictnessLevel: StrictnessLevel = .paranoid
    let allowPII = false
    let allowFilePaths = false
    // periphery:ignore - Reserved: allowCodeSnippets property — reserved for future feature activation
    let allowCodeSnippets = false
    // periphery:ignore - Reserved: allowHealthData property — reserved for future feature activation
    let allowHealthData = false
    // periphery:ignore - Reserved: allowFinancialData property — reserved for future feature activation
    let allowFinancialData = false
    // periphery:ignore - Reserved: allowCodeSnippets property reserved for future feature activation
    // periphery:ignore - Reserved: allowHealthData property reserved for future feature activation
    // periphery:ignore - Reserved: allowFinancialData property reserved for future feature activation
    let blockedKeywords: Set<String> = [
        "password", "secret", "api key", "token", "credential",
        "credit card", "bank", "social security", "ssn",
        "address", "phone number", "email",
        "health", "medical", "diagnosis", "prescription",
        "salary", "income", "debt"
    ]
    let allowedTopics: Set<String>? = [
        "swift", "ios", "macos", "watchos", "tvos",
        "swiftui", "uikit", "appkit", "combine", "async/await",
        "mlx", "coreml", "machine learning", "ai", "llm",
        "architecture", "design patterns", "testing",
        "xcode", "spm", "cocoapods", "performance",
        "accessibility", "localization", "security",
        "networking", "database", "swiftdata", "cloudkit",
        "privacy", "open source", "documentation"
    ]
    let maxContentLength = 2048
}

// MARK: - Permissive Policy

/// Minimal filtering for fully trusted local channels.
// periphery:ignore - Reserved: PermissivePolicy type reserved for future feature activation
struct PermissivePolicy: PrivacyPolicy {
    let name = "Permissive"
    let strictnessLevel: StrictnessLevel = .permissive
    let allowPII = true
    let allowFilePaths = true
    let allowCodeSnippets = true
    let allowHealthData = true
    let allowFinancialData = true
    let blockedKeywords: Set<String> = []
    let allowedTopics: Set<String>? = nil
    let maxContentLength = 0
}
