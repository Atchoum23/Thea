@preconcurrency import SwiftData
import SwiftUI

/// Factory for creating ModelContainer with graceful error handling and fallback options
@MainActor
final class ModelContainerFactory {
    static let shared = ModelContainerFactory()

    private(set) var container: ModelContainer?
    private(set) var isInMemoryFallback = false

    private init() {}

    /// Creates a ModelContainer with the application schema
    /// - Returns: A configured ModelContainer
    /// - Throws: ModelContainerError if both persistent and in-memory initialization fail
    func createContainer() throws -> ModelContainer {
        // Use TheaSchemaMigrationPlan so SwiftData migrates data in-place
        // rather than deleting the store on schema changes. This preserves
        // all user data across app updates. Matches macOS TheamacOSApp init.
        let schema = TheaSchemaMigrationPlan.currentSchema

        let configuration = ModelConfiguration(
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )

        do {
            let container = try ModelContainer(
                for: schema,
                migrationPlan: TheaSchemaMigrationPlan.self,
                configurations: [configuration]
            )
            self.container = container
            isInMemoryFallback = false
            return container
        } catch {
            // Log error for debugging
            print("⚠️ ModelContainer initialization failed: \(error.localizedDescription)")
            print("   Error details: \(error)")

            // Attempt in-memory fallback
            return try createInMemoryFallback(schema: schema)
        }
    }

    /// Creates an in-memory ModelContainer as a fallback
    private func createInMemoryFallback(schema: Schema) throws -> ModelContainer {
        print("🔄 Attempting in-memory fallback...")

        let memoryConfig = ModelConfiguration(
            isStoredInMemoryOnly: true
        )

        do {
            let fallbackContainer = try ModelContainer(
                for: schema,
                migrationPlan: TheaSchemaMigrationPlan.self,
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
    static let modelContainerFallback = Notification.Name("modelContainerFallback")
}
