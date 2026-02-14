// TheaClipTypesTests.swift
// Tests for TheaClip clipboard model types and logic

import Testing
import Foundation
import CryptoKit

// MARK: - Test Doubles

private enum TestClipContentType: String, Codable, Sendable, CaseIterable {
    case text, richText, html, url, image, file, color
}

private struct TestClipEntry: Identifiable, Sendable {
    let id: UUID
    var contentTypeRaw: String
    var textContent: String?
    var imageData: Data?
    var fileNames: [String]
    var sourceApp: String?
    var isPinned: Bool
    var isFavorite: Bool
    var usageCount: Int
    let createdAt: Date
    var tags: [String]

    var contentType: TestClipContentType {
        get { TestClipContentType(rawValue: contentTypeRaw) ?? .text }
        set { contentTypeRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        contentType: TestClipContentType = .text,
        textContent: String? = nil,
        imageData: Data? = nil,
        fileNames: [String] = [],
        sourceApp: String? = nil,
        isPinned: Bool = false,
        isFavorite: Bool = false,
        usageCount: Int = 0,
        createdAt: Date = Date(),
        tags: [String] = []
    ) {
        self.id = id
        self.contentTypeRaw = contentType.rawValue
        self.textContent = textContent
        self.imageData = imageData
        self.fileNames = fileNames
        self.sourceApp = sourceApp
        self.isPinned = isPinned
        self.isFavorite = isFavorite
        self.usageCount = usageCount
        self.createdAt = createdAt
        self.tags = tags
    }

    /// SHA256 content hash for deduplication — mirrors production logic
    static func contentHash(text: String?, imageData: Data?, fileNames: [String]) -> String {
        var hasher = SHA256()
        if let text { hasher.update(data: Data(text.utf8)) }
        if let data = imageData { hasher.update(data: data) }
        for name in fileNames { hasher.update(data: Data(name.utf8)) }
        return hasher.finalize().compactMap { String(format: "%02x", $0) }.joined()
    }
}

private struct TestClipPinboard: Identifiable, Sendable {
    let id: UUID
    var name: String
    var icon: String
    var entries: [UUID]
    let createdAt: Date

    init(id: UUID = UUID(), name: String, icon: String = "pin.fill",
         entries: [UUID] = [], createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.icon = icon
        self.entries = entries
        self.createdAt = createdAt
    }
}

// MARK: - Tests: Content Type Enum

@Suite("ClipContentType")
struct ClipContentTypeTests {
    @Test("All 7 content types exist")
    func allCases() {
        #expect(TestClipContentType.allCases.count == 7)
    }

    @Test("All have unique raw values")
    func uniqueRawValues() {
        let rawValues = TestClipContentType.allCases.map(\.rawValue)
        #expect(Set(rawValues).count == rawValues.count)
    }

    @Test("Codable roundtrip for all types")
    func codableRoundtrip() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for type in TestClipContentType.allCases {
            let data = try encoder.encode(type)
            let decoded = try decoder.decode(TestClipContentType.self, from: data)
            #expect(decoded == type)
        }
    }

    @Test("Invalid raw value returns nil")
    func invalidRawValue() {
        #expect(TestClipContentType(rawValue: "invalid") == nil)
        #expect(TestClipContentType(rawValue: "") == nil)
    }

    @Test("Content type conversion with valid raw")
    func validConversion() {
        let entry = TestClipEntry(contentType: .url, textContent: "https://example.com")
        #expect(entry.contentType == .url)
        #expect(entry.contentTypeRaw == "url")
    }

    @Test("Content type defaults to text for unknown raw")
    func unknownDefaultsToText() {
        var entry = TestClipEntry()
        entry.contentTypeRaw = "unknownFormat"
        #expect(entry.contentType == .text)
    }
}

// MARK: - Tests: Clip Entry

@Suite("ClipEntry Model")
struct ClipEntryTests {
    @Test("Default creation")
    func defaultCreation() {
        let entry = TestClipEntry()
        #expect(entry.contentType == .text)
        #expect(entry.textContent == nil)
        #expect(entry.imageData == nil)
        #expect(entry.fileNames.isEmpty)
        #expect(entry.sourceApp == nil)
        #expect(entry.isPinned == false)
        #expect(entry.isFavorite == false)
        #expect(entry.usageCount == 0)
        #expect(entry.tags.isEmpty)
    }

    @Test("Full creation with all properties")
    func fullCreation() {
        let entry = TestClipEntry(
            contentType: .richText,
            textContent: "Hello **world**",
            sourceApp: "Safari",
            isPinned: true,
            isFavorite: true,
            usageCount: 5,
            tags: ["important", "work"]
        )
        #expect(entry.contentType == .richText)
        #expect(entry.textContent == "Hello **world**")
        #expect(entry.sourceApp == "Safari")
        #expect(entry.isPinned)
        #expect(entry.isFavorite)
        #expect(entry.usageCount == 5)
        #expect(entry.tags.count == 2)
    }

    @Test("Entry is Identifiable")
    func identifiable() {
        let entry1 = TestClipEntry()
        let entry2 = TestClipEntry()
        #expect(entry1.id != entry2.id)
    }

    @Test("Mutable content type via setter")
    func mutableContentType() {
        var entry = TestClipEntry(contentType: .text)
        #expect(entry.contentType == .text)
        entry.contentType = .html
        #expect(entry.contentType == .html)
        #expect(entry.contentTypeRaw == "html")
    }
}

// MARK: - Tests: Content Hashing

@Suite("Content Hash — SHA256")
struct ClipContentHashTests {
    @Test("Text content produces deterministic hash")
    func deterministicHash() {
        let hash1 = TestClipEntry.contentHash(text: "hello", imageData: nil, fileNames: [])
        let hash2 = TestClipEntry.contentHash(text: "hello", imageData: nil, fileNames: [])
        #expect(hash1 == hash2)
    }

    @Test("Different text produces different hash")
    func differentTextDifferentHash() {
        let hash1 = TestClipEntry.contentHash(text: "hello", imageData: nil, fileNames: [])
        let hash2 = TestClipEntry.contentHash(text: "world", imageData: nil, fileNames: [])
        #expect(hash1 != hash2)
    }

    @Test("Image data affects hash")
    func imageDataAffectsHash() {
        let hash1 = TestClipEntry.contentHash(text: nil, imageData: Data([1, 2, 3]), fileNames: [])
        let hash2 = TestClipEntry.contentHash(text: nil, imageData: Data([4, 5, 6]), fileNames: [])
        #expect(hash1 != hash2)
    }

    @Test("File names affect hash")
    func fileNamesAffectHash() {
        let hash1 = TestClipEntry.contentHash(text: nil, imageData: nil, fileNames: ["a.txt"])
        let hash2 = TestClipEntry.contentHash(text: nil, imageData: nil, fileNames: ["b.txt"])
        #expect(hash1 != hash2)
    }

    @Test("All nil/empty produces valid hash")
    func emptyInput() {
        let hash = TestClipEntry.contentHash(text: nil, imageData: nil, fileNames: [])
        #expect(!hash.isEmpty)
        #expect(hash.count == 64) // SHA256 hex = 64 chars
    }

    @Test("Hash is exactly 64 hex characters")
    func hashLength() {
        let hash = TestClipEntry.contentHash(text: "test content", imageData: nil, fileNames: [])
        #expect(hash.count == 64)
        #expect(hash.allSatisfy { $0.isHexDigit })
    }

    @Test("Combined inputs produce consistent hash")
    func combinedInputs() {
        let text = "Hello"
        let data = Data("image".utf8)
        let files = ["doc.pdf", "photo.png"]

        let hash1 = TestClipEntry.contentHash(text: text, imageData: data, fileNames: files)
        let hash2 = TestClipEntry.contentHash(text: text, imageData: data, fileNames: files)
        #expect(hash1 == hash2)
    }

    @Test("Order of file names matters")
    func fileOrderMatters() {
        let hash1 = TestClipEntry.contentHash(text: nil, imageData: nil, fileNames: ["a.txt", "b.txt"])
        let hash2 = TestClipEntry.contentHash(text: nil, imageData: nil, fileNames: ["b.txt", "a.txt"])
        #expect(hash1 != hash2)
    }

    @Test("Text plus image differs from text alone")
    func textPlusImageDiffers() {
        let hash1 = TestClipEntry.contentHash(text: "hello", imageData: nil, fileNames: [])
        let hash2 = TestClipEntry.contentHash(text: "hello", imageData: Data("extra".utf8), fileNames: [])
        #expect(hash1 != hash2)
    }
}

// MARK: - Tests: Pinboard

@Suite("ClipPinboard")
struct ClipPinboardTests {
    @Test("Default creation")
    func defaultCreation() {
        let board = TestClipPinboard(name: "Work")
        #expect(board.name == "Work")
        #expect(board.icon == "pin.fill")
        #expect(board.entries.isEmpty)
    }

    @Test("Identifiable")
    func identifiable() {
        let board1 = TestClipPinboard(name: "A")
        let board2 = TestClipPinboard(name: "B")
        #expect(board1.id != board2.id)
    }

    @Test("Custom icon")
    func customIcon() {
        let board = TestClipPinboard(name: "Code", icon: "chevron.left.forwardslash.chevron.right")
        #expect(board.icon == "chevron.left.forwardslash.chevron.right")
    }

    @Test("Entries can be added")
    func addEntries() {
        var board = TestClipPinboard(name: "Favorites")
        let entryId = UUID()
        board.entries.append(entryId)
        #expect(board.entries.count == 1)
        #expect(board.entries.first == entryId)
    }

    @Test("Multiple entries")
    func multipleEntries() {
        let ids = (0..<5).map { _ in UUID() }
        var board = TestClipPinboard(name: "Many", entries: ids)
        #expect(board.entries.count == 5)

        let newId = UUID()
        board.entries.append(newId)
        #expect(board.entries.count == 6)
    }
}

// MARK: - Tests: Prompt Engineering Success Rate

/// Mirrors PromptTemplate.successRate from PromptEngineeringModels.swift
@Suite("Prompt Template Success Rate")
struct PromptTemplateSuccessRateTests {
    private func successRate(successes: Int, failures: Int) -> Float {
        let total = successes + failures
        return total > 0 ? Float(successes) / Float(total) : 0
    }

    @Test("Zero total returns 0")
    func zeroTotal() {
        #expect(successRate(successes: 0, failures: 0) == 0)
    }

    @Test("All successes returns 1.0")
    func allSuccesses() {
        #expect(successRate(successes: 10, failures: 0) == 1.0)
    }

    @Test("All failures returns 0")
    func allFailures() {
        #expect(successRate(successes: 0, failures: 10) == 0)
    }

    @Test("Mixed results calculate correctly")
    func mixedResults() {
        let rate = successRate(successes: 7, failures: 3)
        #expect(rate == Float(0.7))
    }

    @Test("50/50 returns 0.5")
    func fiftyFifty() {
        #expect(successRate(successes: 5, failures: 5) == 0.5)
    }

    @Test("Single success")
    func singleSuccess() {
        #expect(successRate(successes: 1, failures: 0) == 1.0)
    }

    @Test("Single failure")
    func singleFailure() {
        #expect(successRate(successes: 0, failures: 1) == 0)
    }

    @Test("Large numbers")
    func largeNumbers() {
        let rate = successRate(successes: 999, failures: 1)
        #expect(rate > 0.99)
        #expect(rate < 1.0)
    }
}
