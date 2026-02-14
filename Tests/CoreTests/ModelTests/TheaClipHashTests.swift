@preconcurrency import SwiftData
@testable import TheaModels
import XCTest

/// Tests for TheaClipModels: content hashing, content type management,
/// pinboard relationships, sensitive data handling, and deduplication.
@MainActor
final class TheaClipHashTests: XCTestCase {
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!

    override func setUp() async throws {
        let schema = Schema([TheaClipEntry.self, TheaClipPinboard.self, TheaClipPinboardEntry.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        modelContainer = try ModelContainer(for: schema, configurations: [config])
        modelContext = ModelContext(modelContainer)
    }

    override func tearDown() async throws {
        modelContainer = nil
        modelContext = nil
    }

    // MARK: - Content Hash — Deduplication

    func testContentHashDeterministic() {
        let hash1 = TheaClipEntry.contentHash(text: "hello", imageData: nil, fileNames: [])
        let hash2 = TheaClipEntry.contentHash(text: "hello", imageData: nil, fileNames: [])
        XCTAssertEqual(hash1, hash2, "Same input should produce same hash")
    }

    func testContentHashDifferentText() {
        let hash1 = TheaClipEntry.contentHash(text: "hello", imageData: nil, fileNames: [])
        let hash2 = TheaClipEntry.contentHash(text: "world", imageData: nil, fileNames: [])
        XCTAssertNotEqual(hash1, hash2, "Different text should produce different hash")
    }

    func testContentHashNilText() {
        let hash1 = TheaClipEntry.contentHash(text: nil, imageData: nil, fileNames: [])
        let hash2 = TheaClipEntry.contentHash(text: "", imageData: nil, fileNames: [])
        // nil text vs empty text should differ because nil doesn't add to hasher
        XCTAssertNotEqual(hash1, hash2)
    }

    func testContentHashWithImageData() {
        let data = Data([0xDE, 0xAD, 0xBE, 0xEF])
        let hash1 = TheaClipEntry.contentHash(text: nil, imageData: data, fileNames: [])
        let hash2 = TheaClipEntry.contentHash(text: nil, imageData: nil, fileNames: [])
        XCTAssertNotEqual(hash1, hash2)
    }

    func testContentHashWithFileNames() {
        let hash1 = TheaClipEntry.contentHash(text: nil, imageData: nil, fileNames: ["a.txt"])
        let hash2 = TheaClipEntry.contentHash(text: nil, imageData: nil, fileNames: ["b.txt"])
        XCTAssertNotEqual(hash1, hash2)
    }

    func testContentHashMultipleFileNames() {
        let hash1 = TheaClipEntry.contentHash(text: nil, imageData: nil, fileNames: ["a.txt", "b.txt"])
        let hash2 = TheaClipEntry.contentHash(text: nil, imageData: nil, fileNames: ["a.txt"])
        XCTAssertNotEqual(hash1, hash2)
    }

    func testContentHashIs64CharHex() {
        let hash = TheaClipEntry.contentHash(text: "test", imageData: nil, fileNames: [])
        XCTAssertEqual(hash.count, 64, "SHA256 hex should be 64 characters")
        XCTAssertTrue(hash.allSatisfy { $0.isHexDigit })
    }

    func testContentHashCombinesAllInputs() {
        let hash1 = TheaClipEntry.contentHash(
            text: "hello",
            imageData: Data([1, 2]),
            fileNames: ["file.txt"]
        )
        let hash2 = TheaClipEntry.contentHash(
            text: "hello",
            imageData: Data([1, 2]),
            fileNames: ["file.txt"]
        )
        XCTAssertEqual(hash1, hash2)

        let hash3 = TheaClipEntry.contentHash(
            text: "hello",
            imageData: Data([1, 3]),
            fileNames: ["file.txt"]
        )
        XCTAssertNotEqual(hash1, hash3)
    }

    // MARK: - Content Type

    func testContentTypeFromRawValue() {
        let allTypes: [TheaClipContentType] = [.text, .richText, .html, .url, .image, .file, .color]
        XCTAssertEqual(allTypes.count, 7)
    }

    func testContentTypeCodable() throws {
        for contentType in TheaClipContentType.allCases {
            let data = try JSONEncoder().encode(contentType)
            let decoded = try JSONDecoder().decode(TheaClipContentType.self, from: data)
            XCTAssertEqual(decoded, contentType)
        }
    }

    func testContentTypeComputedProperty() {
        let entry = TheaClipEntry(contentType: .url, urlString: "https://example.com")
        XCTAssertEqual(entry.contentType, .url)
        entry.contentType = .text
        XCTAssertEqual(entry.contentType, .text)
        XCTAssertEqual(entry.contentTypeRaw, "text")
    }

    func testInvalidContentTypeDefaultsToText() {
        let entry = TheaClipEntry()
        entry.contentTypeRaw = "invalid"
        XCTAssertEqual(entry.contentType, .text)
    }

    // MARK: - Clip Entry Defaults

    func testClipEntryDefaults() {
        let entry = TheaClipEntry()
        XCTAssertEqual(entry.contentType, .text)
        XCTAssertNil(entry.textContent)
        XCTAssertNil(entry.htmlContent)
        XCTAssertNil(entry.urlString)
        XCTAssertNil(entry.imageData)
        XCTAssertTrue(entry.fileNames.isEmpty)
        XCTAssertTrue(entry.filePaths.isEmpty)
        XCTAssertNil(entry.sourceAppBundleID)
        XCTAssertNil(entry.sourceAppName)
        XCTAssertEqual(entry.characterCount, 0)
        XCTAssertEqual(entry.byteCount, 0)
        XCTAssertEqual(entry.accessCount, 0)
        XCTAssertFalse(entry.isPinned)
        XCTAssertFalse(entry.isFavorite)
        XCTAssertFalse(entry.isSensitive)
        XCTAssertNil(entry.sensitiveExpiresAt)
        XCTAssertTrue(entry.tags.isEmpty)
    }

    // MARK: - Sensitive Data

    func testSensitiveEntryWithExpiration() {
        let expiry = Date(timeIntervalSinceNow: 3600)
        let entry = TheaClipEntry(
            contentType: .text,
            textContent: "sk-secret-key-123",
            isSensitive: true,
            sensitiveExpiresAt: expiry
        )
        XCTAssertTrue(entry.isSensitive)
        XCTAssertNotNil(entry.sensitiveExpiresAt)
    }

    func testSensitiveEntryNotExpiredYet() {
        let future = Date(timeIntervalSinceNow: 3600)
        let entry = TheaClipEntry(
            isSensitive: true,
            sensitiveExpiresAt: future
        )
        XCTAssertTrue(entry.sensitiveExpiresAt! > Date())
    }

    // MARK: - Pinboard

    func testPinboardDefaults() {
        let board = TheaClipPinboard(name: "My Board")
        XCTAssertEqual(board.name, "My Board")
        XCTAssertEqual(board.icon, "pin.fill")
        XCTAssertEqual(board.colorHex, "#F5A623")
        XCTAssertEqual(board.sortOrder, 0)
        XCTAssertTrue(board.entries.isEmpty)
    }

    func testPinboardCustomValues() {
        let board = TheaClipPinboard(
            name: "Work",
            icon: "briefcase.fill",
            colorHex: "#FF0000",
            sortOrder: 3
        )
        XCTAssertEqual(board.icon, "briefcase.fill")
        XCTAssertEqual(board.colorHex, "#FF0000")
        XCTAssertEqual(board.sortOrder, 3)
    }

    // MARK: - Pinboard Entry (Junction)

    func testPinboardEntryDefaults() {
        let entry = TheaClipPinboardEntry()
        XCTAssertEqual(entry.sortOrder, 0)
        XCTAssertNil(entry.note)
        XCTAssertNil(entry.clipEntry)
        XCTAssertNil(entry.pinboard)
    }

    func testPinboardEntryWithNote() {
        let entry = TheaClipPinboardEntry(note: "Important code snippet")
        XCTAssertEqual(entry.note, "Important code snippet")
    }

    // MARK: - Persistence

    func testClipEntryPersists() throws {
        let entry = TheaClipEntry(
            contentType: .text,
            textContent: "Hello world",
            characterCount: 11,
            tags: ["test"]
        )
        modelContext.insert(entry)
        try modelContext.save()

        let fetched = try modelContext.fetch(FetchDescriptor<TheaClipEntry>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched[0].textContent, "Hello world")
        XCTAssertEqual(fetched[0].tags, ["test"])
    }

    func testPinboardWithEntries() throws {
        let board = TheaClipPinboard(name: "Test Board")
        modelContext.insert(board)

        let clip = TheaClipEntry(contentType: .text, textContent: "Clip")
        modelContext.insert(clip)

        let junction = TheaClipPinboardEntry(
            note: "Pinned",
            clipEntry: clip,
            pinboard: board
        )
        modelContext.insert(junction)
        board.entries.append(junction)
        clip.pinboardEntries.append(junction)

        try modelContext.save()

        let boards = try modelContext.fetch(FetchDescriptor<TheaClipPinboard>())
        XCTAssertEqual(boards.count, 1)
        XCTAssertEqual(boards[0].entries.count, 1)
    }

    // MARK: - Access Tracking

    func testAccessCountIncrement() {
        let entry = TheaClipEntry(contentType: .text, textContent: "Test")
        XCTAssertEqual(entry.accessCount, 0)
        entry.accessCount += 1
        entry.lastAccessedAt = Date()
        XCTAssertEqual(entry.accessCount, 1)
    }

    // MARK: - Source App Tracking

    func testSourceAppTracking() {
        let entry = TheaClipEntry(
            contentType: .text,
            textContent: "Copied text",
            sourceAppBundleID: "com.apple.Safari",
            sourceAppName: "Safari"
        )
        XCTAssertEqual(entry.sourceAppBundleID, "com.apple.Safari")
        XCTAssertEqual(entry.sourceAppName, "Safari")
    }
}
