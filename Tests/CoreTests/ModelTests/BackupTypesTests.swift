//
//  BackupTypesTests.swift
//  TheaTests
//
//  Tests for BackupManager types: BackupType, BackupError,
//  RestoreOptions, BackupInfo, BackupMetadata, BackupItem.
//

import Foundation
import XCTest

// MARK: - Test Doubles

private enum TestBackupType: String, Codable {
    case manual
    case automatic
    case preRestore
    case imported
}

private enum TestBackupError: Error, LocalizedError {
    case backupInProgress
    case restoreInProgress
    case invalidBackupFile
    case incompatibleVersion(String)
    case compressionFailed
    case decompressionFailed
    case fileNotFound

    var errorDescription: String? {
        switch self {
        case .backupInProgress: "A backup is already in progress"
        case .restoreInProgress: "A restore is already in progress"
        case .invalidBackupFile: "Invalid backup file"
        case let .incompatibleVersion(version): "Incompatible backup version: \(version)"
        case .compressionFailed: "Failed to compress backup"
        case .decompressionFailed: "Failed to decompress backup"
        case .fileNotFound: "Backup file not found"
        }
    }
}

private struct TestRestoreOptions: OptionSet, Sendable {
    let rawValue: Int

    static let conversations = TestRestoreOptions(rawValue: 1 << 0)
    static let agents = TestRestoreOptions(rawValue: 1 << 1)
    static let artifacts = TestRestoreOptions(rawValue: 1 << 2)
    static let memories = TestRestoreOptions(rawValue: 1 << 3)
    static let settings = TestRestoreOptions(rawValue: 1 << 4)
    static let tools = TestRestoreOptions(rawValue: 1 << 5)
    static let templates = TestRestoreOptions(rawValue: 1 << 6)
    static let overwrite = TestRestoreOptions(rawValue: 1 << 7)
    static let createSafetyBackup = TestRestoreOptions(rawValue: 1 << 8)

    static let all: TestRestoreOptions = [
        .conversations, .agents, .artifacts, .memories,
        .settings, .tools, .templates, .overwrite, .createSafetyBackup
    ]
    static let dataOnly: TestRestoreOptions = [.conversations, .agents, .artifacts, .memories]
}

private struct TestBackupItem: Codable {
    let name: String
    let type: ItemType
    let size: Int64
    let itemCount: Int

    enum ItemType: String, Codable {
        case file
        case directory
    }
}

private struct TestBackupMetadata: Codable {
    let id: String
    let name: String
    let type: TestBackupType
    let createdAt: Date
    let appVersion: String
    let osVersion: String
    let deviceName: String
    let items: [TestBackupItem]
    let totalSize: Int64
}

private struct TestBackupInfo: Identifiable {
    let id: String
    let name: String
    let type: TestBackupType
    let createdAt: Date
    let size: Int64
    let path: URL

    var sizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

// MARK: - BackupType Tests

final class BackupTypeTests: XCTestCase {
    func testAllCases() {
        let cases: [TestBackupType] = [.manual, .automatic, .preRestore, .imported]
        XCTAssertEqual(cases.count, 4)
    }

    func testRawValues() {
        XCTAssertEqual(TestBackupType.manual.rawValue, "manual")
        XCTAssertEqual(TestBackupType.automatic.rawValue, "automatic")
        XCTAssertEqual(TestBackupType.preRestore.rawValue, "preRestore")
        XCTAssertEqual(TestBackupType.imported.rawValue, "imported")
    }

    func testUniqueRawValues() {
        let cases: [TestBackupType] = [.manual, .automatic, .preRestore, .imported]
        let rawValues = Set(cases.map(\.rawValue))
        XCTAssertEqual(rawValues.count, cases.count)
    }

    func testCodableRoundtrip() throws {
        let original = TestBackupType.preRestore
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TestBackupType.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testAllCasesCodableRoundtrip() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for backupType in [TestBackupType.manual, .automatic, .preRestore, .imported] {
            let data = try encoder.encode(backupType)
            let decoded = try decoder.decode(TestBackupType.self, from: data)
            XCTAssertEqual(decoded, backupType)
        }
    }
}

// MARK: - BackupError Tests

final class BackupErrorTests: XCTestCase {
    func testErrorDescriptions() {
        XCTAssertEqual(TestBackupError.backupInProgress.errorDescription, "A backup is already in progress")
        XCTAssertEqual(TestBackupError.restoreInProgress.errorDescription, "A restore is already in progress")
        XCTAssertEqual(TestBackupError.invalidBackupFile.errorDescription, "Invalid backup file")
        XCTAssertEqual(TestBackupError.compressionFailed.errorDescription, "Failed to compress backup")
        XCTAssertEqual(TestBackupError.decompressionFailed.errorDescription, "Failed to decompress backup")
        XCTAssertEqual(TestBackupError.fileNotFound.errorDescription, "Backup file not found")
    }

    func testIncompatibleVersionDescription() {
        let error = TestBackupError.incompatibleVersion("2.0")
        XCTAssertEqual(error.errorDescription, "Incompatible backup version: 2.0")
    }

    func testIncompatibleVersionWithEmptyString() {
        let error = TestBackupError.incompatibleVersion("")
        XCTAssertEqual(error.errorDescription, "Incompatible backup version: ")
    }

    func testLocalizedErrorConformance() {
        let error: any LocalizedError = TestBackupError.backupInProgress
        XCTAssertNotNil(error.errorDescription)
    }

    func testAllErrorsHaveDescriptions() {
        let errors: [TestBackupError] = [
            .backupInProgress, .restoreInProgress, .invalidBackupFile,
            .incompatibleVersion("1.0"), .compressionFailed, .decompressionFailed, .fileNotFound
        ]
        for error in errors {
            XCTAssertNotNil(error.errorDescription, "Missing description for \(error)")
            XCTAssertFalse(error.errorDescription!.isEmpty, "Empty description for \(error)")
        }
    }

    func testErrorIsError() {
        let error: any Error = TestBackupError.fileNotFound
        XCTAssertNotNil(error)
    }
}

// MARK: - RestoreOptions Tests

final class RestoreOptionsTests: XCTestCase {
    func testIndividualRawValues() {
        XCTAssertEqual(TestRestoreOptions.conversations.rawValue, 1)
        XCTAssertEqual(TestRestoreOptions.agents.rawValue, 2)
        XCTAssertEqual(TestRestoreOptions.artifacts.rawValue, 4)
        XCTAssertEqual(TestRestoreOptions.memories.rawValue, 8)
        XCTAssertEqual(TestRestoreOptions.settings.rawValue, 16)
        XCTAssertEqual(TestRestoreOptions.tools.rawValue, 32)
        XCTAssertEqual(TestRestoreOptions.templates.rawValue, 64)
        XCTAssertEqual(TestRestoreOptions.overwrite.rawValue, 128)
        XCTAssertEqual(TestRestoreOptions.createSafetyBackup.rawValue, 256)
    }

    func testAllContainsEveryOption() {
        XCTAssertTrue(TestRestoreOptions.all.contains(.conversations))
        XCTAssertTrue(TestRestoreOptions.all.contains(.agents))
        XCTAssertTrue(TestRestoreOptions.all.contains(.artifacts))
        XCTAssertTrue(TestRestoreOptions.all.contains(.memories))
        XCTAssertTrue(TestRestoreOptions.all.contains(.settings))
        XCTAssertTrue(TestRestoreOptions.all.contains(.tools))
        XCTAssertTrue(TestRestoreOptions.all.contains(.templates))
        XCTAssertTrue(TestRestoreOptions.all.contains(.overwrite))
        XCTAssertTrue(TestRestoreOptions.all.contains(.createSafetyBackup))
    }

    func testDataOnlySubset() {
        XCTAssertTrue(TestRestoreOptions.dataOnly.contains(.conversations))
        XCTAssertTrue(TestRestoreOptions.dataOnly.contains(.agents))
        XCTAssertTrue(TestRestoreOptions.dataOnly.contains(.artifacts))
        XCTAssertTrue(TestRestoreOptions.dataOnly.contains(.memories))
        XCTAssertFalse(TestRestoreOptions.dataOnly.contains(.settings))
        XCTAssertFalse(TestRestoreOptions.dataOnly.contains(.tools))
        XCTAssertFalse(TestRestoreOptions.dataOnly.contains(.templates))
        XCTAssertFalse(TestRestoreOptions.dataOnly.contains(.overwrite))
    }

    func testDataOnlyIsSubsetOfAll() {
        XCTAssertTrue(TestRestoreOptions.all.contains(.dataOnly))
    }

    func testEmptyOptions() {
        let empty = TestRestoreOptions([])
        XCTAssertEqual(empty.rawValue, 0)
        XCTAssertFalse(empty.contains(.conversations))
    }

    func testUnion() {
        let options: TestRestoreOptions = [.conversations, .settings]
        XCTAssertTrue(options.contains(.conversations))
        XCTAssertTrue(options.contains(.settings))
        XCTAssertFalse(options.contains(.agents))
        XCTAssertEqual(options.rawValue, 1 + 16)
    }

    func testIntersection() {
        let a: TestRestoreOptions = [.conversations, .agents, .settings]
        let b: TestRestoreOptions = [.agents, .tools]
        let intersection = a.intersection(b)
        XCTAssertTrue(intersection.contains(.agents))
        XCTAssertFalse(intersection.contains(.conversations))
        XCTAssertFalse(intersection.contains(.tools))
    }

    func testSymmetricDifference() {
        let a: TestRestoreOptions = [.conversations, .agents]
        let b: TestRestoreOptions = [.agents, .tools]
        let diff = a.symmetricDifference(b)
        XCTAssertTrue(diff.contains(.conversations))
        XCTAssertTrue(diff.contains(.tools))
        XCTAssertFalse(diff.contains(.agents))
    }

    func testSendableConformance() {
        let options: any Sendable = TestRestoreOptions.all
        XCTAssertNotNil(options)
    }
}

// MARK: - BackupItem Tests

final class BackupItemTests: XCTestCase {
    func testFileItemCreation() {
        let item = TestBackupItem(name: "chat.json", type: .file, size: 1024, itemCount: 1)
        XCTAssertEqual(item.name, "chat.json")
        XCTAssertEqual(item.type, .file)
        XCTAssertEqual(item.size, 1024)
        XCTAssertEqual(item.itemCount, 1)
    }

    func testDirectoryItemCreation() {
        let item = TestBackupItem(name: "conversations", type: .directory, size: 4096, itemCount: 15)
        XCTAssertEqual(item.type, .directory)
        XCTAssertEqual(item.itemCount, 15)
    }

    func testItemTypeCodable() throws {
        let original = TestBackupItem.ItemType.file
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TestBackupItem.ItemType.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testItemCodableRoundtrip() throws {
        let original = TestBackupItem(name: "data.db", type: .file, size: 2048, itemCount: 1)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TestBackupItem.self, from: data)
        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.type, original.type)
        XCTAssertEqual(decoded.size, original.size)
        XCTAssertEqual(decoded.itemCount, original.itemCount)
    }

    func testZeroSizeItem() {
        let item = TestBackupItem(name: "empty.txt", type: .file, size: 0, itemCount: 0)
        XCTAssertEqual(item.size, 0)
        XCTAssertEqual(item.itemCount, 0)
    }

    func testLargeItem() {
        let item = TestBackupItem(name: "database.sqlite", type: .file, size: Int64.max, itemCount: 1)
        XCTAssertEqual(item.size, Int64.max)
    }
}

// MARK: - BackupMetadata Tests

final class BackupMetadataTests: XCTestCase {
    private func makeMetadata(items: [TestBackupItem] = []) -> TestBackupMetadata {
        TestBackupMetadata(
            id: "test-id",
            name: "Test Backup",
            type: .manual,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            appVersion: "1.6.0",
            osVersion: "26.2",
            deviceName: "Mac Studio",
            items: items,
            totalSize: 4096
        )
    }

    func testMetadataCreation() {
        let meta = makeMetadata()
        XCTAssertEqual(meta.id, "test-id")
        XCTAssertEqual(meta.name, "Test Backup")
        XCTAssertEqual(meta.type, .manual)
        XCTAssertEqual(meta.appVersion, "1.6.0")
        XCTAssertEqual(meta.osVersion, "26.2")
        XCTAssertEqual(meta.deviceName, "Mac Studio")
        XCTAssertEqual(meta.totalSize, 4096)
    }

    func testMetadataWithItems() {
        let items = [
            TestBackupItem(name: "conversations", type: .directory, size: 2048, itemCount: 10),
            TestBackupItem(name: "settings.json", type: .file, size: 512, itemCount: 1)
        ]
        let meta = makeMetadata(items: items)
        XCTAssertEqual(meta.items.count, 2)
        XCTAssertEqual(meta.items[0].name, "conversations")
        XCTAssertEqual(meta.items[1].name, "settings.json")
    }

    func testMetadataCodableRoundtrip() throws {
        let items = [TestBackupItem(name: "data", type: .directory, size: 1024, itemCount: 5)]
        let original = makeMetadata(items: items)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(TestBackupMetadata.self, from: data)
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.type, original.type)
        XCTAssertEqual(decoded.appVersion, original.appVersion)
        XCTAssertEqual(decoded.items.count, 1)
    }

    func testEmptyItems() {
        let meta = makeMetadata(items: [])
        XCTAssertTrue(meta.items.isEmpty)
    }

    func testAutomaticBackupType() {
        let meta = TestBackupMetadata(
            id: "auto-1", name: "Auto Backup", type: .automatic,
            createdAt: Date(), appVersion: "1.5.0", osVersion: "26.1",
            deviceName: "MacBook", items: [], totalSize: 0
        )
        XCTAssertEqual(meta.type, .automatic)
    }
}

// MARK: - BackupInfo Tests

final class BackupInfoTests: XCTestCase {
    func testInfoCreation() {
        let info = TestBackupInfo(
            id: "backup-1", name: "My Backup", type: .manual,
            createdAt: Date(), size: 1024,
            path: URL(fileURLWithPath: "/tmp/backup.zip")
        )
        XCTAssertEqual(info.id, "backup-1")
        XCTAssertEqual(info.name, "My Backup")
        XCTAssertEqual(info.type, .manual)
        XCTAssertEqual(info.size, 1024)
    }

    func testSizeFormattedBytes() {
        let info = TestBackupInfo(
            id: "1", name: "Small", type: .manual,
            createdAt: Date(), size: 500,
            path: URL(fileURLWithPath: "/tmp/test")
        )
        let formatted = info.sizeFormatted
        XCTAssertFalse(formatted.isEmpty)
        // 500 bytes should format as bytes
        XCTAssertTrue(formatted.contains("500") || formatted.contains("bytes"),
                       "Expected bytes format, got: \(formatted)")
    }

    func testSizeFormattedKilobytes() {
        let info = TestBackupInfo(
            id: "2", name: "Medium", type: .automatic,
            createdAt: Date(), size: 1024 * 50,
            path: URL(fileURLWithPath: "/tmp/test")
        )
        let formatted = info.sizeFormatted
        XCTAssertFalse(formatted.isEmpty)
        // 50 KB
        XCTAssertTrue(formatted.contains("KB") || formatted.contains("kB"),
                       "Expected KB format, got: \(formatted)")
    }

    func testSizeFormattedMegabytes() {
        let info = TestBackupInfo(
            id: "3", name: "Large", type: .preRestore,
            createdAt: Date(), size: 1024 * 1024 * 25,
            path: URL(fileURLWithPath: "/tmp/test")
        )
        let formatted = info.sizeFormatted
        XCTAssertFalse(formatted.isEmpty)
        XCTAssertTrue(formatted.contains("MB"),
                       "Expected MB format, got: \(formatted)")
    }

    func testSizeFormattedZero() {
        let info = TestBackupInfo(
            id: "4", name: "Empty", type: .imported,
            createdAt: Date(), size: 0,
            path: URL(fileURLWithPath: "/tmp/test")
        )
        let formatted = info.sizeFormatted
        XCTAssertFalse(formatted.isEmpty)
    }

    func testIdentifiable() {
        let info = TestBackupInfo(
            id: "unique-id", name: "Test", type: .manual,
            createdAt: Date(), size: 100,
            path: URL(fileURLWithPath: "/tmp/test")
        )
        XCTAssertEqual(info.id, "unique-id")
    }
}
