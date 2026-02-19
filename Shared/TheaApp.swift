@preconcurrency import SwiftData
import SwiftUI

// Note: @main is defined in platform-specific app files
// This file contains shared app configuration

enum TheaAppConfiguration {
    static let appName = "Thea"
    static let appVersion = "1.0.0"

    // Shared schema for all platforms
    static var sharedSchema: Schema {
        Schema([
            // Core models
            Conversation.self,
            Message.self,
            Project.self,
            AIProviderConfig.self,
            FinancialAccount.self,
            FinancialTransaction.self,
            IndexedFile.self,

            // Clipboard History models
            TheaClipEntry.self,
            TheaClipPinboard.self,
            TheaClipPinboardEntry.self,

            // Prompt Engineering models
            UserPromptPreference.self,
            CodeErrorRecord.self,
            CodeCorrection.self,
            PromptTemplate.self,
            CodeFewShotExample.self,

            // Window Management models
            WindowState.self,

            // Life Tracking models
            HealthSnapshot.self,
            DailyScreenTimeRecord.self,
            DailyInputStatistics.self,
            BrowsingRecord.self,
            LocationVisitRecord.self,
            LifeInsight.self
        ])
    }

    static func createModelContainer() throws -> ModelContainer {
        let modelConfiguration = ModelConfiguration(
            schema: sharedSchema,
            isStoredInMemoryOnly: false,
            allowsSave: true
        )

        return try ModelContainer(
            for: sharedSchema,
            configurations: [modelConfiguration]
        )
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let newConversation = Notification.Name("newConversation")
    static let newProject = Notification.Name("newProject")
    static let refreshData = Notification.Name("refreshData")
}
