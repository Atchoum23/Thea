@preconcurrency import SwiftData
import SwiftUI
import Security

/// Factory for creating ModelContainer with graceful error handling and fallback options
@MainActor
final class ModelContainerFactory {
    // periphery:ignore - Reserved: ModelContainerFactory type reserved for future feature activation
    static let shared = ModelContainerFactory()

    // periphery:ignore - Reserved: container property — reserved for future feature activation
    private(set) var container: ModelContainer?
    // periphery:ignore - Reserved: isInMemoryFallback property — reserved for future feature activation
    private(set) var isInMemoryFallback = false

    private init() {}

    /// Returns true if the running process has the iCloud container entitlement.
    /// CloudKit init throws NSException (not Swift Error) when this entitlement is absent —
    /// NSException bypasses Swift catch blocks and crashes. This guard lets us skip tier 1
    /// safely in unsigned / CI builds.
    nonisolated private static func hasCloudKitContainerEntitlement() -> Bool {
        var selfCode: SecCode?
        guard SecCodeCopySelf(SecCSFlags(), &selfCode) == errSecSuccess,
              let selfCode else { return false }
        var staticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(selfCode, SecCSFlags(), &staticCode) == errSecSuccess,
              let staticCode else { return false }
        var info: CFDictionary?
        let flags = SecCSFlags(rawValue: kSecCSSigningInformation)
        guard SecStaticCodeCopySigningInformation(staticCode, flags, &info) == errSecSuccess,
              let infoDict = info as? [String: Any] else { return false }
        guard let entitlements = infoDict["entitlements-dict"] as? [String: Any] else { return false }
        return entitlements["com.apple.developer.icloud-container-identifiers"] != nil
    }

    // periphery:ignore - Reserved: createContainer() instance method — reserved for future feature activation
    /// Creates a ModelContainer with the application schema and migration plan.
    /// Uses SchemaV1.models so the model list stays in sync with the versioned schema.
    ///
    /// Three-tier fallback strategy:
    ///   1. Persistent + CloudKit  — production (signed builds with entitlements)
    ///   2. Persistent, no CloudKit — CI / unsigned builds / no iCloud account (silent)
    ///   3. In-memory              — catastrophic failure (shows alert to user)
    ///
    /// - Returns: A configured ModelContainer
    /// - Throws: ModelContainerError if all three tiers fail
    func createContainer() throws -> ModelContainer {
        // Use SchemaV1.models to stay in sync with the versioned schema definition
        let schema = Schema(SchemaV1.models)

        // Tier 1: Persistent storage with CloudKit sync (production)
        // Guard: CloudKit init throws NSException when iCloud entitlement is absent.
        // NSException bypasses Swift catch — pre-check avoids crash in unsigned builds.
        if Self.hasCloudKitContainerEntitlement() {
            let cloudKitConfig = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .automatic
            )

            do {
                // Wire TheaSchemaMigrationPlan — SwiftData performs lightweight/custom
                // migration instead of deleting the store on version mismatch.
                let container = try ModelContainer(
                    for: schema,
                    migrationPlan: TheaSchemaMigrationPlan.self,
                    configurations: [cloudKitConfig]
                )
                self.container = container
                isInMemoryFallback = false
                return container
            } catch {
                print("⚠️ CloudKit ModelContainer failed (no iCloud account / network): \(error.localizedDescription)")
            }
        } else {
            print("ℹ️ No CloudKit entitlement — skipping tier 1 (unsigned / CI build)")
        }

        // Tier 2: Persistent storage without CloudKit (CI / unsigned builds)
        // Data persists between sessions; sync is simply disabled. No alert shown.
        let persistentConfig = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )

        do {
            let container = try ModelContainer(
                for: schema,
                migrationPlan: TheaSchemaMigrationPlan.self,
                configurations: [persistentConfig]
            )
            self.container = container
            isInMemoryFallback = false
            print("✅ Persistent (no CloudKit) ModelContainer initialized — sync disabled")
            return container
        } catch {
            print("⚠️ Persistent ModelContainer also failed: \(error.localizedDescription)")
        }

        // Tier 3: In-memory fallback — catastrophic, data won't survive restart
        return try createInMemoryFallback(schema: schema)
    }

    // periphery:ignore - Reserved: createInMemoryFallback(schema:) instance method — reserved for future feature activation
    /// Creates an in-memory ModelContainer as a fallback
    private func createInMemoryFallback(schema: Schema) throws -> ModelContainer {
        print("🔄 Attempting in-memory fallback...")

        let memoryConfig = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )

        do {
            let fallbackContainer = try ModelContainer(
                for: schema,
                configurations: [memoryConfig]
            )

            container = fallbackContainer
            isInMemoryFallback = true

            // Notify app that we're running in fallback mode
            NotificationCenter.default.post(
                name: .modelContainerFallback,
                object: nil,
                userInfo: ["reason": "Persistent storage initialization failed"]
            )

            print("✅ In-memory fallback successful - data will not persist between sessions")

            return fallbackContainer
        } catch {
            // Both persistent and in-memory failed - this is critical
            print("❌ CRITICAL: Both persistent and in-memory ModelContainer initialization failed")
            throw ModelContainerError.initializationFailed(
                persistentError: error,
                fallbackError: error
            )
        }
    }
}

/// Errors that can occur during ModelContainer initialization
enum ModelContainerError: LocalizedError {
    case initializationFailed(persistentError: Error, fallbackError: Error)

    var errorDescription: String? {
        switch self {
        case let .initializationFailed(persistentError, fallbackError):
            """
            Failed to initialize data storage.

            Persistent storage error: \(persistentError.localizedDescription)
            Fallback storage error: \(fallbackError.localizedDescription)

            Please restart the application. If the problem persists, contact support.
            """
        }
    }
}

/// Notification posted when ModelContainer falls back to in-memory storage
extension Notification.Name {
    // periphery:ignore - Reserved: modelContainerFallback static property reserved for future feature activation
    static let modelContainerFallback = Notification.Name("modelContainerFallback")
}
