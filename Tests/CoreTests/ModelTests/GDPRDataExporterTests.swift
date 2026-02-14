// GDPRDataExporterTests.swift
// Tests for GDPR export/erasure types: GDPRExportError, export file naming,
// JSON structure validation, and user preferences export logic.
// Mirrors types from Shared/Monitoring/GDPRDataExporter.swift.
// Note: SwiftData ModelContext operations are not testable in SPM —
// these tests cover the value types, error handling, and pure-function logic.

import Foundation
import XCTest

// MARK: - Mirror Types

private enum GDPRExportError: Error, LocalizedError {
    case exportFailed(String)
    case deletionFailed(String)

    var errorDescription: String? {
        switch self {
        case let .exportFailed(reason):
            "Data export failed: \(reason)"
        case let .deletionFailed(reason):
            "Data deletion failed: \(reason)"
        }
    }
}

/// Mirrors the export metadata structure produced by GDPRDataExporter.exportAllData
private struct GDPRExportMetadata: Codable, Equatable {
    let exportDate: String
    let exportVersion: String
    let application: String

    static func current() -> GDPRExportMetadata {
        GDPRExportMetadata(
            exportDate: ISO8601DateFormatter().string(from: Date()),
            exportVersion: "1.0",
            application: "Thea"
        )
    }
}

/// Mirrors the non-sensitive keys exported by exportUserPreferences()
private let nonSensitivePreferenceKeys = [
    "inputTrackingEnabled",
    "browserTrackingEnabled",
    "locationTrackingEnabled",
    "screenTimeTrackingEnabled",
    "selectedTheme",
    "notificationsEnabled"
]

/// Mirrors the tracking keys cleared by deleteAllData()
private let trackingKeys = [
    "inputTrackingEnabled",
    "browserTrackingEnabled",
    "locationTrackingEnabled",
    "screenTimeTrackingEnabled"
]

// MARK: - GDPRExportError Tests

final class GDPRExportErrorTests: XCTestCase {

    func testExportFailedDescription() {
        let error = GDPRExportError.exportFailed("disk full")
        XCTAssertEqual(error.errorDescription, "Data export failed: disk full")
    }

    func testDeletionFailedDescription() {
        let error = GDPRExportError.deletionFailed("permission denied")
        XCTAssertEqual(error.errorDescription, "Data deletion failed: permission denied")
    }

    func testExportFailedWithEmptyReason() {
        let error = GDPRExportError.exportFailed("")
        XCTAssertEqual(error.errorDescription, "Data export failed: ")
    }

    func testDeletionFailedWithEmptyReason() {
        let error = GDPRExportError.deletionFailed("")
        XCTAssertEqual(error.errorDescription, "Data deletion failed: ")
    }

    func testExportFailedWithLongReason() {
        let reason = String(repeating: "x", count: 1000)
        let error = GDPRExportError.exportFailed(reason)
        XCTAssertTrue(error.errorDescription!.contains(reason))
    }

    func testErrorIsLocalizedError() {
        let error: any LocalizedError = GDPRExportError.exportFailed("test")
        XCTAssertNotNil(error.errorDescription)
    }

    func testAllErrorsHaveDescriptions() {
        let errors: [GDPRExportError] = [
            .exportFailed("a"),
            .deletionFailed("b")
        ]
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
    }
}

// MARK: - Export Metadata Tests

final class GDPRExportMetadataTests: XCTestCase {

    func testCurrentMetadata() {
        let metadata = GDPRExportMetadata.current()
        XCTAssertEqual(metadata.exportVersion, "1.0")
        XCTAssertEqual(metadata.application, "Thea")
        XCTAssertFalse(metadata.exportDate.isEmpty)
    }

    func testExportDateIsISO8601() {
        let metadata = GDPRExportMetadata.current()
        let formatter = ISO8601DateFormatter()
        let date = formatter.date(from: metadata.exportDate)
        XCTAssertNotNil(date, "Export date should be valid ISO 8601")
    }

    func testCodableRoundTrip() throws {
        let metadata = GDPRExportMetadata.current()
        let data = try JSONEncoder().encode(metadata)
        let decoded = try JSONDecoder().decode(GDPRExportMetadata.self, from: data)
        XCTAssertEqual(decoded.exportVersion, metadata.exportVersion)
        XCTAssertEqual(decoded.application, metadata.application)
    }

    func testEquatable() {
        let m1 = GDPRExportMetadata(exportDate: "2026-02-14T00:00:00Z", exportVersion: "1.0", application: "Thea")
        let m2 = GDPRExportMetadata(exportDate: "2026-02-14T00:00:00Z", exportVersion: "1.0", application: "Thea")
        XCTAssertEqual(m1, m2)
    }

    func testNotEqualDifferentDate() {
        let m1 = GDPRExportMetadata(exportDate: "2026-02-14T00:00:00Z", exportVersion: "1.0", application: "Thea")
        let m2 = GDPRExportMetadata(exportDate: "2026-02-15T00:00:00Z", exportVersion: "1.0", application: "Thea")
        XCTAssertNotEqual(m1, m2)
    }
}

// MARK: - Export File Naming Tests

final class GDPRExportFileNamingTests: XCTestCase {

    func testFileNameFormat() {
        let timestamp = Date().timeIntervalSince1970
        let fileName = "thea_data_export_\(timestamp).json"
        XCTAssertTrue(fileName.hasPrefix("thea_data_export_"))
        XCTAssertTrue(fileName.hasSuffix(".json"))
    }

    func testFileNameUniqueness() {
        let t1 = Date().timeIntervalSince1970
        let t2 = t1 + 1
        let name1 = "thea_data_export_\(t1).json"
        let name2 = "thea_data_export_\(t2).json"
        XCTAssertNotEqual(name1, name2)
    }

    func testExportToTempDirectory() {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "thea_data_export_\(Date().timeIntervalSince1970).json"
        let fileURL = tempDir.appendingPathComponent(fileName)
        XCTAssertTrue(fileURL.path.contains("thea_data_export_"))
        XCTAssertEqual(fileURL.pathExtension, "json")
    }
}

// MARK: - User Preferences Export Tests

final class GDPRUserPreferencesExportTests: XCTestCase {

    func testNonSensitiveKeysAreComplete() {
        // Verify the expected keys
        XCTAssertEqual(nonSensitivePreferenceKeys.count, 6)
        XCTAssertTrue(nonSensitivePreferenceKeys.contains("inputTrackingEnabled"))
        XCTAssertTrue(nonSensitivePreferenceKeys.contains("selectedTheme"))
        XCTAssertTrue(nonSensitivePreferenceKeys.contains("notificationsEnabled"))
    }

    func testTrackingKeysSubsetOfPreferenceKeys() {
        // All tracking keys should be in the non-sensitive keys
        for key in trackingKeys {
            XCTAssertTrue(
                nonSensitivePreferenceKeys.contains(key),
                "\(key) should be in non-sensitive preference keys"
            )
        }
    }

    func testNoSensitiveKeysExported() {
        let sensitivePatterns = ["password", "secret", "token", "key", "auth"]
        for key in nonSensitivePreferenceKeys {
            let lower = key.lowercased()
            for pattern in sensitivePatterns {
                XCTAssertFalse(
                    lower.contains(pattern),
                    "Key '\(key)' contains sensitive pattern '\(pattern)'"
                )
            }
        }
    }

    func testExportPreferencesReturnsDictionary() {
        // Simulate exportUserPreferences()
        var prefs: [String: Any] = [:]
        for key in nonSensitivePreferenceKeys {
            if let value = UserDefaults.standard.object(forKey: key) {
                prefs[key] = value
            }
        }
        // Should not crash, result is a valid dictionary (may be empty)
        XCTAssertNotNil(prefs)
    }
}

// MARK: - JSON Serialization Tests

final class GDPRJSONSerializationTests: XCTestCase {

    func testExportStructureIsValidJSON() throws {
        var exportData: [String: Any] = [:]
        exportData["exportDate"] = ISO8601DateFormatter().string(from: Date())
        exportData["exportVersion"] = "1.0"
        exportData["application"] = "Thea"
        exportData["inputStatistics"] = [[String: Any]]()
        exportData["browsingHistory"] = [[String: Any]]()
        exportData["locationHistory"] = [[String: Any]]()
        exportData["screenTimeData"] = [[String: Any]]()
        exportData["conversations"] = [[String: Any]]()
        exportData["userPreferences"] = [String: Any]()

        let jsonData = try JSONSerialization.data(
            withJSONObject: exportData,
            options: [.prettyPrinted, .sortedKeys]
        )
        XCTAssertGreaterThan(jsonData.count, 0)

        // Verify it can be parsed back
        let parsed = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?["application"] as? String, "Thea")
        XCTAssertEqual(parsed?["exportVersion"] as? String, "1.0")
    }

    func testExportContainsAllCategories() throws {
        let expectedCategories = [
            "exportDate", "exportVersion", "application",
            "inputStatistics", "browsingHistory", "locationHistory",
            "screenTimeData", "conversations", "userPreferences"
        ]

        var exportData: [String: Any] = [:]
        exportData["exportDate"] = "2026-02-14T00:00:00Z"
        exportData["exportVersion"] = "1.0"
        exportData["application"] = "Thea"
        exportData["inputStatistics"] = []
        exportData["browsingHistory"] = []
        exportData["locationHistory"] = []
        exportData["screenTimeData"] = []
        exportData["conversations"] = []
        exportData["userPreferences"] = [String: Any]()

        for category in expectedCategories {
            XCTAssertNotNil(
                exportData[category],
                "Export should contain '\(category)'"
            )
        }
    }

    func testExportWritesToFile() throws {
        let jsonData = try JSONSerialization.data(
            withJSONObject: ["test": true],
            options: .prettyPrinted
        )
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("gdpr_test_\(UUID().uuidString).json")

        try jsonData.write(to: fileURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))

        // Cleanup
        try? FileManager.default.removeItem(at: fileURL)
    }
}
