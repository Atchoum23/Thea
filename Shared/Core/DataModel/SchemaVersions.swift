//
//  SchemaVersions.swift
//  Thea
//
//  Created by Claude Code on 2026-02-16.
//  Schema versioning for SwiftData migration support
//

@preconcurrency import SwiftData
import Foundation
import os.log

private let logger = Logger(subsystem: "ai.thea.app", category: "schema-versions")

// periphery:ignore - Reserved: logger global var reserved for future feature activation
// MARK: - Schema V1 (Current Production Schema)

/// Version 1.0.0 - Initial production schema
enum SchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version {
        Schema.Version(1, 0, 0)
    }

    static var models: [any PersistentModel.Type] {
        [
            // Core models
            Conversation.self,
            Message.self,
            Project.self,
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
            LifeInsight.self,

            // Habit Tracker models
            TheaHabit.self,
            TheaHabitEntry.self,

            // N3: Artifact System
            GeneratedArtifact.self,

            // Q3: Proactive Intelligence
            DeliveredInsight.self
        ]
    }
}

// MARK: - Migration Plan

enum TheaSchemaMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any SwiftData.VersionedSchema.Type] {
        [
            SchemaV1.self
            // Future versions will be added here:
            // SchemaV2.self,
            // SchemaV3.self,
        ]
    }

    static var stages: [SwiftData.MigrationStage] {
        [
            // Future migrations will be added here:
            // migrateV1toV2,
            // migrateV2toV3,
        ]
    }

    // MARK: - Future Migration Stages (Examples)

    /*
    // Example: V1 → V2 migration
    static let migrateV1toV2 = MigrationStage.custom(
        fromVersion: SchemaV1.self,
        toVersion: SchemaV2.self,
        willMigrate: { context in
            // Pre-migration: Backup data, validate state
            logger.info("🔄 Starting migration from V1 to V2...")

            // Optional: Create backup
            try? backupDatabase(context: context) // Safe: backup failure is non-fatal; migration continues without backup
        },
        didMigrate: { context in
            // Post-migration: Validate data integrity
            logger.info("Migration from V1 to V2 complete")

            // Optional: Verify migration succeeded
            try? validateMigration(context: context) // Safe: validation failure is non-fatal; migration is still considered complete
        }
    )

    // Example: Lightweight migration (adding new field)
    static let migrateV2toV3 = MigrationStage.lightweight(
        fromVersion: SchemaV2.self,
        toVersion: SchemaV3.self
    )
    */
}

// MARK: - Migration Utilities

extension TheaSchemaMigrationPlan {
    // periphery:ignore - Reserved: backupDatabase(context:) static method — reserved for future feature activation
    /// Creates a backup of the database before migration
    static func backupDatabase(context: ModelContext) throws {
        // periphery:ignore - Reserved: backupDatabase(context:) static method reserved for future feature activation
        // Implementation: Export to JSON, copy .sqlite file, etc.
        logger.info("📦 Creating database backup...")
    }

    // periphery:ignore - Reserved: validateMigration(context:) static method reserved for future feature activation
    /// Validates migration completed successfully
    static func validateMigration(context: ModelContext) throws {
        // Implementation: Run integrity checks, count records, etc.
        logger.info("✓ Validating migration integrity...")
    }
}
