@preconcurrency import SwiftData
@testable import TheaModels
import XCTest

@MainActor
final class TheaClipModelsTests: XCTestCase {
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!

    override func setUp() async throws {
        let schema = Schema([
            TheaClipEntry.self,
            TheaClipPinboard.self,
            TheaClipPinboardEntry.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        modelContainer = try ModelContainer(for: schema, configurations: [config])
        modelContext = ModelContext(modelContainer)
    }

    override func tearDown() async throws {
        await MainActor.run {
            modelContainer = nil
            modelContext = nil
        }
    }

    // MARK: - TheaClipEntry Creation

    func testEntryDefaultValues() {
        let entry = TheaClipEntry()

        XCTAssertNotNil(entry.id)
        XCTAssertEqual(entry.contentType, .text)
        XCTAssertEqual(entry.contentTypeRaw, "text")
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
        XCTAssertEqual(entry.previewText, "")
        XCTAssertNil(entry.aiSummary)
        XCTAssertNil(entry.aiCategory)
        XCTAssertTrue(entry.pinboardEntries.isEmpty)
    }

    func testEntryWithTextContent() {
        let entry = TheaClipEntry(
            contentType: .text,
            textContent: "Hello, World!",
            sourceAppBundleID: "com.apple.Terminal",
            sourceAppName: "Terminal",
            characterCount: 13,
            byteCount: 13,
            previewText: "Hello, World!"
        )

        XCTAssertEqual(entry.contentType, .text)
        XCTAssertEqual(entry.textContent, "Hello, World!")
        XCTAssertEqual(entry.sourceAppBundleID, "com.apple.Terminal")
        XCTAssertEqual(entry.sourceAppName, "Terminal")
        XCTAssertEqual(entry.characterCount, 13)
        XCTAssertEqual(entry.byteCount, 13)
        XCTAssertEqual(entry.previewText, "Hello, World!")
    }

    func testEntryWithURLContent() {
        let entry = TheaClipEntry(
            contentType: .url,
            urlString: "https://example.com",
            previewText: "https://example.com"
        )

        XCTAssertEqual(entry.contentType, .url)
        XCTAssertEqual(entry.urlString, "https://example.com")
    }

    func testEntryWithImageContent() {
        let imageData = Data([0x89, 0x50, 0x4E, 0x47]) // PNG header bytes
        let entry = TheaClipEntry(
            contentType: .image,
            imageData: imageData,
            originalImageHash: "abc123",
            byteCount: 4
        )

        XCTAssertEqual(entry.contentType, .image)
        XCTAssertEqual(entry.imageData, imageData)
        XCTAssertEqual(entry.originalImageHash, "abc123")
        XCTAssertEqual(entry.byteCount, 4)
    }

    func testEntryWithFileContent() {
        let entry = TheaClipEntry(
            contentType: .file,
            fileNames: ["report.pdf", "data.csv"],
            filePaths: ["/Users/test/report.pdf", "/Users/test/data.csv"]
        )

        XCTAssertEqual(entry.contentType, .file)
        XCTAssertEqual(entry.fileNames.count, 2)
        XCTAssertEqual(entry.filePaths.count, 2)
        XCTAssertEqual(entry.fileNames[0], "report.pdf")
    }

    func testEntrySensitiveContent() {
        let expiry = Date().addingTimeInterval(3600)
        let entry = TheaClipEntry(
            contentType: .text,
            textContent: "password123",
            isSensitive: true,
            sensitiveExpiresAt: expiry
        )

        XCTAssertTrue(entry.isSensitive)
        XCTAssertEqual(entry.sensitiveExpiresAt, expiry)
    }

    func testEntryWithTags() {
        let entry = TheaClipEntry(
            tags: ["code", "swift", "important"]
        )

        XCTAssertEqual(entry.tags.count, 3)
        XCTAssertTrue(entry.tags.contains("swift"))
    }

    // MARK: - ContentType Computed Property

    func testContentTypeGetterSetter() {
        let entry = TheaClipEntry(contentType: .text)
        XCTAssertEqual(entry.contentType, .text)
        XCTAssertEqual(entry.contentTypeRaw, "text")

        entry.contentType = .richText
        XCTAssertEqual(entry.contentType, .richText)
        XCTAssertEqual(entry.contentTypeRaw, "richText")

        entry.contentType = .html
        XCTAssertEqual(entry.contentTypeRaw, "html")

        entry.contentType = .url
        XCTAssertEqual(entry.contentTypeRaw, "url")

        entry.contentType = .image
        XCTAssertEqual(entry.contentTypeRaw, "image")

        entry.contentType = .file
        XCTAssertEqual(entry.contentTypeRaw, "file")

        entry.contentType = .color
        XCTAssertEqual(entry.contentTypeRaw, "color")
    }

    func testContentTypeInvalidRawValueFallback() {
        let entry = TheaClipEntry()
        entry.contentTypeRaw = "invalidType"
        XCTAssertEqual(entry.contentType, .text, "Invalid raw value should fall back to .text")
    }

    func testContentTypeAllCases() {
        let allTypes: [TheaClipContentType] = [.text, .richText, .html, .url, .image, .file, .color]
        XCTAssertEqual(TheaClipContentType.allCases.count, 7)
        for type in allTypes {
            XCTAssertTrue(TheaClipContentType.allCases.contains(type))
        }
    }

    // MARK: - Content Hash

    func testContentHashWithText() {
        let hash1 = TheaClipEntry.contentHash(text: "Hello", imageData: nil, fileNames: [])
        let hash2 = TheaClipEntry.contentHash(text: "Hello", imageData: nil, fileNames: [])
        XCTAssertEqual(hash1, hash2, "Same text should produce same hash")
        XCTAssertEqual(hash1.count, 64, "SHA256 hex string should be 64 chars")
    }

    func testContentHashDifferentText() {
        let hash1 = TheaClipEntry.contentHash(text: "Hello", imageData: nil, fileNames: [])
        let hash2 = TheaClipEntry.contentHash(text: "World", imageData: nil, fileNames: [])
        XCTAssertNotEqual(hash1, hash2, "Different text should produce different hash")
    }

    func testContentHashWithImageData() {
        let data1 = Data([0x01, 0x02, 0x03])
        let data2 = Data([0x04, 0x05, 0x06])

        let hash1 = TheaClipEntry.contentHash(text: nil, imageData: data1, fileNames: [])
        let hash2 = TheaClipEntry.contentHash(text: nil, imageData: data2, fileNames: [])
        XCTAssertNotEqual(hash1, hash2)
    }

    func testContentHashWithFileNames() {
        let hash1 = TheaClipEntry.contentHash(text: nil, imageData: nil, fileNames: ["a.txt"])
        let hash2 = TheaClipEntry.contentHash(text: nil, imageData: nil, fileNames: ["b.txt"])
        XCTAssertNotEqual(hash1, hash2)
    }

    func testContentHashCombined() {
        let data = Data([0xFF])
        let hash1 = TheaClipEntry.contentHash(text: "Hello", imageData: data, fileNames: ["f.txt"])
        let hash2 = TheaClipEntry.contentHash(text: "Hello", imageData: data, fileNames: ["f.txt"])
        XCTAssertEqual(hash1, hash2, "Same combined content should produce same hash")

        let hash3 = TheaClipEntry.contentHash(text: "Hello", imageData: data, fileNames: ["g.txt"])
        XCTAssertNotEqual(hash1, hash3, "Different file name should produce different hash")
    }

    func testContentHashEmptyInputs() {
        let hash = TheaClipEntry.contentHash(text: nil, imageData: nil, fileNames: [])
        XCTAssertEqual(hash.count, 64, "Empty inputs should still produce valid SHA256")
    }

    // MARK: - Entry Persistence

    func testEntryPersistence() throws {
        let entry = TheaClipEntry(
            contentType: .text,
            textContent: "Persisted text",
            characterCount: 14,
            isPinned: true,
            tags: ["test"]
        )
        modelContext.insert(entry)
        try modelContext.save()

        let descriptor = FetchDescriptor<TheaClipEntry>()
        let fetched = try modelContext.fetch(descriptor)

        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.textContent, "Persisted text")
        XCTAssertEqual(fetched.first?.characterCount, 14)
        XCTAssertTrue(fetched.first?.isPinned ?? false)
        XCTAssertEqual(fetched.first?.tags, ["test"])
    }

    func testEntryUniqueID() throws {
        let id = UUID()
        let entry1 = TheaClipEntry(id: id, textContent: "First")
        modelContext.insert(entry1)
        try modelContext.save()

        let entry2 = TheaClipEntry(id: id, textContent: "Second")
        modelContext.insert(entry2)

        // Inserting duplicate UUID should cause a merge or error
        do {
            try modelContext.save()
            // If save succeeds, there should still be only one entry
            let descriptor = FetchDescriptor<TheaClipEntry>()
            let fetched = try modelContext.fetch(descriptor)
            XCTAssertEqual(fetched.count, 1)
        } catch {
            // Duplicate key error is acceptable behavior
            XCTAssertTrue(true)
        }
    }

    // MARK: - TheaClipPinboard

    func testPinboardCreation() {
        let pinboard = TheaClipPinboard(name: "Work Notes")

        XCTAssertNotNil(pinboard.id)
        XCTAssertEqual(pinboard.name, "Work Notes")
        XCTAssertEqual(pinboard.icon, "pin.fill")
        XCTAssertEqual(pinboard.colorHex, "#F5A623")
        XCTAssertEqual(pinboard.sortOrder, 0)
        XCTAssertTrue(pinboard.entries.isEmpty)
    }

    func testPinboardCustomValues() {
        let pinboard = TheaClipPinboard(
            name: "Design",
            icon: "paintbrush",
            colorHex: "#FF0000",
            sortOrder: 5
        )

        XCTAssertEqual(pinboard.name, "Design")
        XCTAssertEqual(pinboard.icon, "paintbrush")
        XCTAssertEqual(pinboard.colorHex, "#FF0000")
        XCTAssertEqual(pinboard.sortOrder, 5)
    }

    func testPinboardPersistence() throws {
        let pinboard = TheaClipPinboard(name: "Saved Items")
        modelContext.insert(pinboard)
        try modelContext.save()

        let descriptor = FetchDescriptor<TheaClipPinboard>()
        let fetched = try modelContext.fetch(descriptor)

        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.name, "Saved Items")
    }

    // MARK: - TheaClipPinboardEntry

    func testPinboardEntryCreation() {
        let junction = TheaClipPinboardEntry()

        XCTAssertNotNil(junction.id)
        XCTAssertEqual(junction.sortOrder, 0)
        XCTAssertNil(junction.note)
        XCTAssertNil(junction.clipEntry)
        XCTAssertNil(junction.pinboard)
    }

    func testPinboardEntryWithNote() {
        let junction = TheaClipPinboardEntry(
            sortOrder: 3,
            note: "Important snippet"
        )

        XCTAssertEqual(junction.sortOrder, 3)
        XCTAssertEqual(junction.note, "Important snippet")
    }

    func testPinboardEntryRelationships() throws {
        let entry = TheaClipEntry(contentType: .text, textContent: "Clip content")
        let pinboard = TheaClipPinboard(name: "My Board")
        let junction = TheaClipPinboardEntry(
            clipEntry: entry,
            pinboard: pinboard
        )

        modelContext.insert(entry)
        modelContext.insert(pinboard)
        modelContext.insert(junction)
        try modelContext.save()

        let junctionDescriptor = FetchDescriptor<TheaClipPinboardEntry>()
        let fetched = try modelContext.fetch(junctionDescriptor)

        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.clipEntry?.textContent, "Clip content")
        XCTAssertEqual(fetched.first?.pinboard?.name, "My Board")
    }

    // MARK: - Entry Pin/Favorite Toggles

    func testEntryPinToggle() {
        let entry = TheaClipEntry()
        XCTAssertFalse(entry.isPinned)

        entry.isPinned = true
        XCTAssertTrue(entry.isPinned)

        entry.isPinned = false
        XCTAssertFalse(entry.isPinned)
    }

    func testEntryFavoriteToggle() {
        let entry = TheaClipEntry()
        XCTAssertFalse(entry.isFavorite)

        entry.isFavorite = true
        XCTAssertTrue(entry.isFavorite)
    }

    func testEntryAccessTracking() {
        let entry = TheaClipEntry(accessCount: 0)
        XCTAssertEqual(entry.accessCount, 0)

        entry.accessCount += 1
        XCTAssertEqual(entry.accessCount, 1)

        entry.lastAccessedAt = Date()
        XCTAssertNotNil(entry.lastAccessedAt)
    }
}
