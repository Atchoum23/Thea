@testable import TheaModels
import XCTest

/// Tests for IndexedFile — file system indexing model with path-derived file types.
final class IndexedFileTests: XCTestCase {

    // MARK: - Creation

    func testBasicCreation() {
        let file = IndexedFile(
            path: "/Users/test/Documents/report.pdf",
            name: "report.pdf",
            size: 1_048_576
        )
        XCTAssertEqual(file.path, "/Users/test/Documents/report.pdf")
        XCTAssertEqual(file.name, "report.pdf")
        XCTAssertEqual(file.size, 1_048_576)
    }

    func testDefaults() {
        let file = IndexedFile(path: "/test.txt", name: "test.txt", size: 100)
        XCTAssertTrue(file.isIndexed)
        XCTAssertNil(file.contentHash)
    }

    func testCustomID() {
        let id = UUID()
        let file = IndexedFile(id: id, path: "/a.txt", name: "a.txt", size: 0)
        XCTAssertEqual(file.id, id)
    }

    func testUniqueIDs() {
        let f1 = IndexedFile(path: "/a.txt", name: "a.txt", size: 0)
        let f2 = IndexedFile(path: "/a.txt", name: "a.txt", size: 0)
        XCTAssertNotEqual(f1.id, f2.id)
    }

    // MARK: - File Type Derivation

    func testFileTypeFromPath() {
        let file = IndexedFile(path: "/code/main.swift", name: "main.swift", size: 500)
        XCTAssertEqual(file.fileType, "swift")
    }

    func testFileTypeExtensions() {
        let cases: [(String, String)] = [
            ("/doc.pdf", "pdf"),
            ("/image.png", "png"),
            ("/data.json", "json"),
            ("/page.html", "html"),
            ("/archive.zip", "zip"),
            ("/script.py", "py"),
            ("/code.swift", "swift"),
            ("/readme.md", "md")
        ]
        for (path, expectedType) in cases {
            let file = IndexedFile(path: path, name: URL(fileURLWithPath: path).lastPathComponent, size: 0)
            XCTAssertEqual(file.fileType, expectedType, "Path \(path) should have type \(expectedType)")
        }
    }

    func testFileTypeNoExtension() {
        let file = IndexedFile(path: "/usr/bin/swift", name: "swift", size: 0)
        XCTAssertEqual(file.fileType, "", "File without extension should have empty fileType")
    }

    func testFileTypeIgnoresParameter() {
        // The fileType parameter is discarded; actual type comes from path
        let file = IndexedFile(path: "/code/app.js", name: "app.js", size: 0, fileType: "python")
        XCTAssertEqual(file.fileType, "js", "Should derive from path, not parameter")
    }

    func testFileTypeHiddenFile() {
        // Hidden files (dot-prefixed, no extension) have empty pathExtension
        let file = IndexedFile(path: "/home/.gitignore", name: ".gitignore", size: 50)
        XCTAssertEqual(file.fileType, "", "Hidden dotfiles have no path extension")
    }

    func testFileTypeDoubleExtension() {
        let file = IndexedFile(path: "/data/archive.tar.gz", name: "archive.tar.gz", size: 1000)
        XCTAssertEqual(file.fileType, "gz", "Should use last extension")
    }

    // MARK: - Size

    func testZeroSize() {
        let file = IndexedFile(path: "/empty.txt", name: "empty.txt", size: 0)
        XCTAssertEqual(file.size, 0)
    }

    func testLargeFileSize() {
        let fourGB: Int64 = 4 * 1_073_741_824
        let file = IndexedFile(path: "/big.iso", name: "big.iso", size: fourGB)
        XCTAssertEqual(file.size, fourGB)
    }

    // MARK: - Content Hash

    func testContentHashNil() {
        let file = IndexedFile(path: "/a.txt", name: "a.txt", size: 0)
        XCTAssertNil(file.contentHash)
    }

    func testContentHashProvided() {
        let hash = "sha256:abcdef1234567890"
        let file = IndexedFile(path: "/a.txt", name: "a.txt", size: 100, contentHash: hash)
        XCTAssertEqual(file.contentHash, hash)
    }

    func testContentHashMutation() {
        let file = IndexedFile(path: "/a.txt", name: "a.txt", size: 100)
        XCTAssertNil(file.contentHash)
        file.contentHash = "md5:abc123"
        XCTAssertEqual(file.contentHash, "md5:abc123")
    }

    // MARK: - Indexed State

    func testIsIndexedDefault() {
        let file = IndexedFile(path: "/a.txt", name: "a.txt", size: 0)
        XCTAssertTrue(file.isIndexed)
    }

    func testIsIndexedFalse() {
        let file = IndexedFile(path: "/a.txt", name: "a.txt", size: 0, isIndexed: false)
        XCTAssertFalse(file.isIndexed)
    }

    func testIsIndexedMutation() {
        let file = IndexedFile(path: "/a.txt", name: "a.txt", size: 0)
        file.isIndexed = false
        XCTAssertFalse(file.isIndexed)
    }

    // MARK: - Dates

    func testCustomDates() {
        let indexed = Date(timeIntervalSince1970: 1_700_000_000)
        let modified = Date(timeIntervalSince1970: 1_699_000_000)
        let file = IndexedFile(
            path: "/a.txt", name: "a.txt", size: 0,
            indexedAt: indexed, lastModified: modified
        )
        XCTAssertEqual(file.indexedAt, indexed)
        XCTAssertEqual(file.lastModified, modified)
        XCTAssertGreaterThan(file.indexedAt, file.lastModified, "Indexed after last modified")
    }

    // MARK: - Identifiable

    func testIdentifiable() {
        let file = IndexedFile(path: "/a.txt", name: "a.txt", size: 0)
        let id: UUID = file.id // Should compile due to Identifiable conformance
        XCTAssertNotNil(id)
    }
}
