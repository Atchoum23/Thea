import Foundation
import XCTest

// MARK: - Mirrored Types (standalone, no module imports)

private enum PathSecurityError: Error, Equatable {
    case pathTraversalAttempt(requested: String, resolved: String, allowed: String)
    case nullByteInjection(path: String)
    case suspiciousPattern(path: String, pattern: String)
}

/// Pure-function mirror of ProjectPathManager.validatePath. No FS access.
private enum PathValidator {
    static let suspiciousPatterns = ["...", "//", "\\\\", "\n", "\r", "%00", "%2e%2e", "%2f", "%5c"]

    static func validate(_ relativePath: String, basePath: String) throws -> String {
        guard !relativePath.contains("\0") else {
            throw PathSecurityError.nullByteInjection(path: relativePath)
        }
        for pattern in suspiciousPatterns {
            if relativePath.lowercased().contains(pattern) {
                throw PathSecurityError.suspiciousPattern(path: relativePath, pattern: pattern)
            }
        }
        let cleanRelative = relativePath.hasPrefix("/") ? String(relativePath.dropFirst()) : relativePath
        let fullPath = (basePath as NSString).appendingPathComponent(cleanRelative)
        let resolvedPath = (fullPath as NSString).standardizingPath
        let resolvedBase = (basePath as NSString).standardizingPath
        let resolvedComponents = (resolvedPath as NSString).pathComponents
        let baseComponents = (resolvedBase as NSString).pathComponents
        guard resolvedComponents.count >= baseComponents.count else {
            throw PathSecurityError.pathTraversalAttempt(
                requested: relativePath, resolved: resolvedPath, allowed: resolvedBase)
        }
        for (index, baseComponent) in baseComponents.enumerated() {
            guard resolvedComponents[index] == baseComponent else {
                throw PathSecurityError.pathTraversalAttempt(
                    requested: relativePath, resolved: resolvedPath, allowed: resolvedBase)
            }
        }
        return resolvedPath
    }
}

// MARK: - Tests

final class PathValidationTests: XCTestCase {
    private let base = "/Users/alexis/Projects/Thea"

    // MARK: - Helpers

    private func assertAccepted(_ path: String, expected: String,
                                file: StaticString = #filePath, line: UInt = #line) {
        do {
            let result = try PathValidator.validate(path, basePath: base)
            XCTAssertEqual(result, expected, file: file, line: line)
        } catch {
            XCTFail("Unexpected error for '\(path)': \(error)", file: file, line: line)
        }
    }

    private func assertTraversal(_ path: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertThrowsError(try PathValidator.validate(path, basePath: base), file: file, line: line) { err in
            guard case PathSecurityError.pathTraversalAttempt = err else {
                XCTFail("Expected pathTraversalAttempt for '\(path)', got \(err)", file: file, line: line)
                return
            }
        }
    }

    private func assertSuspicious(_ path: String, pattern: String,
                                  file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertThrowsError(try PathValidator.validate(path, basePath: base), file: file, line: line) { err in
            guard case PathSecurityError.suspiciousPattern(_, let p) = err else {
                XCTFail("Expected suspiciousPattern for '\(path)', got \(err)", file: file, line: line)
                return
            }
            XCTAssertEqual(p, pattern, file: file, line: line)
        }
    }

    private func assertNullByte(_ path: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertThrowsError(try PathValidator.validate(path, basePath: base), file: file, line: line) { err in
            guard case PathSecurityError.nullByteInjection = err else {
                XCTFail("Expected nullByteInjection for path, got \(err)", file: file, line: line)
                return
            }
        }
    }

    // MARK: - Valid Paths

    func testValidRelativePaths() throws {
        assertAccepted("Sources/main.swift", expected: "\(base)/Sources/main.swift")
        assertAccepted("Shared/Core/Models/Data.swift", expected: "\(base)/Shared/Core/Models/Data.swift")
        assertAccepted("README.md", expected: "\(base)/README.md")
        assertAccepted(".gitignore", expected: "\(base)/.gitignore")
        assertAccepted(".claude/settings.json", expected: "\(base)/.claude/settings.json")
    }

    func testLeadingSlashStripped() throws {
        assertAccepted("/Sources/file.swift", expected: "\(base)/Sources/file.swift")
    }

    func testSpecialCharactersAllowed() throws {
        assertAccepted("My Documents/file.swift", expected: "\(base)/My Documents/file.swift")
        assertAccepted("Sources/Résumé.swift", expected: "\(base)/Sources/Résumé.swift")
        assertAccepted("my-dir_v2/file_name-2.swift", expected: "\(base)/my-dir_v2/file_name-2.swift")
    }

    func testSingleDotResolvesToBase() throws {
        assertAccepted(".", expected: base)
    }

    func testDotSlashPrefix() throws {
        assertAccepted("./Sources/main.swift", expected: "\(base)/Sources/main.swift")
    }

    func testEmptyPathResolvesToBase() throws {
        assertAccepted("", expected: base)
    }

    func testBasePathTrailingSlash() throws {
        let result = try PathValidator.validate("file.swift", basePath: base + "/")
        XCTAssertEqual(result, "\(base)/file.swift")
    }

    // MARK: - Path Traversal Attacks

    func testSimpleTraversalBlocked() { assertTraversal("../etc/passwd") }
    func testDeepTraversalBlocked() { assertTraversal("../../../../etc/shadow") }
    func testMidPathTraversalBlocked() { assertTraversal("Sources/../../../../../../etc/passwd") }
    func testSiblingDirectoryBlocked() { assertTraversal("../OtherProject/secrets.txt") }
    func testExactParentBlocked() { assertTraversal("..") }

    func testSystemDirectoriesBlocked() {
        assertTraversal("../../../etc/passwd")
        assertTraversal("../../../var/log/system.log")
        assertTraversal("../../../../private/etc/hosts")
    }

    func testInternalTraversalStayingInBase() throws {
        // "a/b/../c" resolves to "a/c" -- still within base, should pass
        assertAccepted("a/b/../c/file.swift", expected: "\(base)/a/c/file.swift")
    }

    func testInternalTraversalEscapingBase() {
        assertTraversal("a/../../OtherProject/file.swift")
    }

    // MARK: - Component-Wise Validation (FINDING-007)

    func testPrefixCollisionBlocked() throws {
        // "../Thea_evil" escapes base -- caught by component check
        assertTraversal("../Thea_evil/payload.sh")
        // "Thea_evil" as subdirectory within base is fine
        assertAccepted("Thea_evil/safe.txt", expected: "\(base)/Thea_evil/safe.txt")
    }

    // MARK: - Null Byte Injection

    func testNullByteVariants() {
        assertNullByte("file.swift\0")
        assertNullByte("Sources/\0/evil.swift")
        assertNullByte("file.swift\0.txt") // classic truncation attack
    }

    // MARK: - URL-Encoded Attacks

    func testURLEncodedTraversal() {
        assertSuspicious("%2e%2e/etc/passwd", pattern: "%2e%2e")
        assertSuspicious("Sources%2f..%2fetc", pattern: "%2f")
        assertSuspicious("Sources%5c..%5cetc", pattern: "%5c")
        assertSuspicious("file%00.swift", pattern: "%00")
    }

    func testMixedCaseURLEncoding() {
        // %2E%2E should match via case-insensitive check
        XCTAssertThrowsError(try PathValidator.validate("%2E%2E/secret", basePath: base)) { err in
            guard case PathSecurityError.suspiciousPattern = err else {
                XCTFail("Expected suspiciousPattern, got \(err)")
                return
            }
        }
    }

    // MARK: - Suspicious Patterns (Exhaustive)

    func testAllSuspiciousPatterns() {
        let cases: [(String, String)] = [
            ("a.../b", "..."),
            ("a//b", "//"),
            ("a\\\\b", "\\\\"),
            ("a\nb", "\n"),
            ("a\rb", "\r"),
            ("a%00b", "%00"),
            ("a%2e%2eb", "%2e%2e"),
            ("a%2fb", "%2f"),
            ("a%5cb", "%5c")
        ]
        for (input, expected) in cases {
            assertSuspicious(input, pattern: expected)
        }
    }

    // MARK: - Home Directory Expansion

    func testTildeNotExpanded() throws {
        // "~" treated as literal directory name, stays within base
        let result = try PathValidator.validate("~/etc/passwd", basePath: base)
        XCTAssertTrue(result.hasPrefix(base), "Tilde path must stay within base")
    }

    // MARK: - Very Long Paths

    func testLongPath() throws {
        let longPath = (0 ..< 20).map { _ in "abcdefghij" }.joined(separator: "/")
        let result = try PathValidator.validate(longPath, basePath: base)
        XCTAssertTrue(result.hasPrefix(base))
        XCTAssertTrue(result.count > 200)
    }

    func testDeeplyNestedPath() throws {
        let deepPath = (0 ..< 50).map { "d\($0)" }.joined(separator: "/")
        let result = try PathValidator.validate(deepPath, basePath: base)
        XCTAssertTrue(result.hasPrefix(base))
    }

    // MARK: - Allowed vs Restricted Directories

    func testSubdirectoriesAllowed() throws {
        for sub in ["Sources", "Tests", "Shared/Core", "Resources/Assets", ".git/objects"] {
            let result = try PathValidator.validate(sub, basePath: base)
            XCTAssertTrue(result.hasPrefix(base), "'\(sub)' should be within base")
        }
    }

    // MARK: - Symlink Concerns (Logic-Level)

    func testSymlinkLogicLevel() throws {
        // standardizingPath resolves syntactic ".." but NOT real symlinks.
        // Real symlink testing needs FS access (out of scope).
        // Syntactic traversal staying in base: accepted
        assertAccepted("a/../b/file.swift", expected: "\(base)/b/file.swift")
        // Syntactic traversal escaping base: blocked
        assertTraversal("a/../../OtherProject/file.swift")
    }
}
