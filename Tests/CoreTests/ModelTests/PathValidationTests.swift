import Foundation
import XCTest

// MARK: - Local Mirror of PathSecurityError

/// Mirrors PathSecurityError from ProjectPathManager for standalone testing
private enum PathSecurityError: Error, Equatable {
    case pathTraversalAttempt(requested: String, resolved: String, allowed: String)
    case nullByteInjection(path: String)
    case suspiciousPattern(path: String, pattern: String)
}

// MARK: - Local Mirror of Path Validation Logic

/// Pure-function extraction of ProjectPathManager.validatePath for unit testing.
/// No file system access, no singletons — deterministic and side-effect free.
private enum PathValidator {

    /// Suspicious patterns that must be rejected before any path processing.
    static let suspiciousPatterns = ["...", "//", "\\\\", "\n", "\r", "%00", "%2e%2e", "%2f", "%5c"]

    /// Validates that `relativePath` resolved against `basePath` stays within `basePath`.
    /// Mirrors ProjectPathManager.validatePath exactly.
    static func validate(_ relativePath: String, basePath: String) throws -> String {
        // 1. Null byte injection check
        guard !relativePath.contains("\0") else {
            throw PathSecurityError.nullByteInjection(path: relativePath)
        }

        // 2. Suspicious pattern check (case-insensitive)
        for pattern in suspiciousPatterns {
            if relativePath.lowercased().contains(pattern) {
                throw PathSecurityError.suspiciousPattern(path: relativePath, pattern: pattern)
            }
        }

        // 3. Strip leading slash so it is treated as relative
        let cleanRelative = relativePath.hasPrefix("/") ? String(relativePath.dropFirst()) : relativePath

        // 4. Construct and normalize paths
        let fullPath = (basePath as NSString).appendingPathComponent(cleanRelative)
        let resolvedPath = (fullPath as NSString).standardizingPath
        let resolvedBase = (basePath as NSString).standardizingPath

        // 5. Component-wise containment check (FINDING-007 fix)
        let resolvedComponents = (resolvedPath as NSString).pathComponents
        let baseComponents = (resolvedBase as NSString).pathComponents

        guard resolvedComponents.count >= baseComponents.count else {
            throw PathSecurityError.pathTraversalAttempt(
                requested: relativePath, resolved: resolvedPath, allowed: resolvedBase
            )
        }

        for (index, baseComponent) in baseComponents.enumerated() {
            guard resolvedComponents[index] == baseComponent else {
                throw PathSecurityError.pathTraversalAttempt(
                    requested: relativePath, resolved: resolvedPath, allowed: resolvedBase
                )
            }
        }

        return resolvedPath
    }
}

// MARK: - Tests

final class PathValidationTests: XCTestCase {

    private let basePath = "/Users/alexis/Projects/Thea"

    // MARK: - Valid Paths

    func testSimpleRelativePath() throws {
        let result = try PathValidator.validate("Sources/main.swift", basePath: basePath)
        XCTAssertEqual(result, "/Users/alexis/Projects/Thea/Sources/main.swift")
    }

    func testNestedSubdirectory() throws {
        let result = try PathValidator.validate("Shared/Core/Models/Data.swift", basePath: basePath)
        XCTAssertEqual(result, "/Users/alexis/Projects/Thea/Shared/Core/Models/Data.swift")
    }

    func testSingleFileName() throws {
        let result = try PathValidator.validate("README.md", basePath: basePath)
        XCTAssertEqual(result, "/Users/alexis/Projects/Thea/README.md")
    }

    func testLeadingSlashIsStripped() throws {
        // A leading slash should be removed so the path is treated as relative
        let result = try PathValidator.validate("/Sources/file.swift", basePath: basePath)
        XCTAssertEqual(result, "/Users/alexis/Projects/Thea/Sources/file.swift")
    }

    func testHiddenFileInAllowedDir() throws {
        let result = try PathValidator.validate(".gitignore", basePath: basePath)
        XCTAssertEqual(result, "/Users/alexis/Projects/Thea/.gitignore")
    }

    func testHiddenDirectoryInAllowedDir() throws {
        let result = try PathValidator.validate(".claude/settings.json", basePath: basePath)
        XCTAssertEqual(result, "/Users/alexis/Projects/Thea/.claude/settings.json")
    }

    // MARK: - Path Traversal Attacks

    func testSimpleTraversalBlocked() throws {
        // "../" navigates out of basePath — standardizingPath resolves it
        XCTAssertThrowsError(try PathValidator.validate("../etc/passwd", basePath: basePath)) { error in
            guard case PathSecurityError.pathTraversalAttempt = error else {
                XCTFail("Expected pathTraversalAttempt, got \(error)")
                return
            }
        }
    }

    func testDeepTraversalBlocked() throws {
        XCTAssertThrowsError(
            try PathValidator.validate("../../../../etc/shadow", basePath: basePath)
        ) { error in
            guard case PathSecurityError.pathTraversalAttempt = error else {
                XCTFail("Expected pathTraversalAttempt, got \(error)")
                return
            }
        }
    }

    func testMidPathTraversalBlocked() throws {
        // Goes into Sources then back out past basePath
        XCTAssertThrowsError(
            try PathValidator.validate("Sources/../../../../../../etc/passwd", basePath: basePath)
        ) { error in
            guard case PathSecurityError.pathTraversalAttempt = error else {
                XCTFail("Expected pathTraversalAttempt, got \(error)")
                return
            }
        }
    }

    func testTraversalToSiblingDirectory() throws {
        // Tries to reach /Users/alexis/Projects/OtherProject via ../
        XCTAssertThrowsError(
            try PathValidator.validate("../OtherProject/secrets.txt", basePath: basePath)
        ) { error in
            guard case PathSecurityError.pathTraversalAttempt = error else {
                XCTFail("Expected pathTraversalAttempt, got \(error)")
                return
            }
        }
    }

    func testTraversalExactlyToParentBlocked() throws {
        // Resolves to exactly the parent — fewer components than base
        XCTAssertThrowsError(
            try PathValidator.validate("..", basePath: basePath)
        ) { error in
            guard case PathSecurityError.pathTraversalAttempt = error else {
                XCTFail("Expected pathTraversalAttempt, got \(error)")
                return
            }
        }
    }

    // MARK: - Component-Wise Validation (FINDING-007)

    func testPrefixCollisionBlocked() throws {
        // "/Users/alexis/Projects/Thea_evil" starts with the same prefix string
        // but is NOT under basePath. Component-wise check catches this.
        let evilBase = "/Users/alexis/Projects/Thea_evil"
        // Construct a relative path that, after joining with basePath, would resolve
        // to the evil directory — this requires traversal.
        XCTAssertThrowsError(
            try PathValidator.validate("../Thea_evil/payload.sh", basePath: basePath)
        ) { error in
            guard case PathSecurityError.pathTraversalAttempt = error else {
                XCTFail("Expected pathTraversalAttempt, got \(error)")
                return
            }
        }
        // Also verify that a legitimate "Thea_evil" subdir within basePath is fine
        let result = try PathValidator.validate("Thea_evil/safe.txt", basePath: basePath)
        XCTAssertEqual(result, "/Users/alexis/Projects/Thea/Thea_evil/safe.txt")
    }

    // MARK: - Null Byte Injection

    func testNullByteAtEnd() {
        XCTAssertThrowsError(
            try PathValidator.validate("file.swift\0", basePath: basePath)
        ) { error in
            guard case PathSecurityError.nullByteInjection = error else {
                XCTFail("Expected nullByteInjection, got \(error)")
                return
            }
        }
    }

    func testNullByteInMiddle() {
        XCTAssertThrowsError(
            try PathValidator.validate("Sources/\0/evil.swift", basePath: basePath)
        ) { error in
            guard case PathSecurityError.nullByteInjection = error else {
                XCTFail("Expected nullByteInjection, got \(error)")
                return
            }
        }
    }

    func testNullByteBeforeExtension() {
        // Classic null-byte truncation attack: "file.swift\0.txt"
        XCTAssertThrowsError(
            try PathValidator.validate("file.swift\0.txt", basePath: basePath)
        ) { error in
            guard case PathSecurityError.nullByteInjection = error else {
                XCTFail("Expected nullByteInjection, got \(error)")
                return
            }
        }
    }

    // MARK: - URL-Encoded Path Traversal

    func testURLEncodedDotDot() {
        // %2e%2e = ".." URL-encoded
        XCTAssertThrowsError(
            try PathValidator.validate("%2e%2e/etc/passwd", basePath: basePath)
        ) { error in
            guard case PathSecurityError.suspiciousPattern(_, let pattern) = error else {
                XCTFail("Expected suspiciousPattern, got \(error)")
                return
            }
            XCTAssertEqual(pattern, "%2e%2e")
        }
    }

    func testURLEncodedSlash() {
        // %2f = "/" URL-encoded
        XCTAssertThrowsError(
            try PathValidator.validate("Sources%2f..%2f..%2fetc%2fpasswd", basePath: basePath)
        ) { error in
            guard case PathSecurityError.suspiciousPattern(_, let pattern) = error else {
                XCTFail("Expected suspiciousPattern, got \(error)")
                return
            }
            XCTAssertEqual(pattern, "%2f")
        }
    }

    func testURLEncodedBackslash() {
        // %5c = "\\" URL-encoded
        XCTAssertThrowsError(
            try PathValidator.validate("Sources%5c..%5cetc", basePath: basePath)
        ) { error in
            guard case PathSecurityError.suspiciousPattern(_, let pattern) = error else {
                XCTFail("Expected suspiciousPattern, got \(error)")
                return
            }
            XCTAssertEqual(pattern, "%5c")
        }
    }

    func testURLEncodedNullByte() {
        // %00 = null byte URL-encoded
        XCTAssertThrowsError(
            try PathValidator.validate("file%00.swift", basePath: basePath)
        ) { error in
            guard case PathSecurityError.suspiciousPattern(_, let pattern) = error else {
                XCTFail("Expected suspiciousPattern, got \(error)")
                return
            }
            XCTAssertEqual(pattern, "%00")
        }
    }

    func testMixedCaseURLEncoding() {
        // %2E%2E should also be caught (case-insensitive check)
        XCTAssertThrowsError(
            try PathValidator.validate("%2E%2E/secret", basePath: basePath)
        ) { error in
            guard case PathSecurityError.suspiciousPattern = error else {
                XCTFail("Expected suspiciousPattern, got \(error)")
                return
            }
        }
    }

    // MARK: - Suspicious Patterns

    func testTripleDotBlocked() {
        XCTAssertThrowsError(
            try PathValidator.validate("Sources/.../file.swift", basePath: basePath)
        ) { error in
            guard case PathSecurityError.suspiciousPattern(_, let pattern) = error else {
                XCTFail("Expected suspiciousPattern, got \(error)")
                return
            }
            XCTAssertEqual(pattern, "...")
        }
    }

    func testDoubleSlashBlocked() {
        XCTAssertThrowsError(
            try PathValidator.validate("Sources//file.swift", basePath: basePath)
        ) { error in
            guard case PathSecurityError.suspiciousPattern(_, let pattern) = error else {
                XCTFail("Expected suspiciousPattern, got \(error)")
                return
            }
            XCTAssertEqual(pattern, "//")
        }
    }

    func testBackslashBlocked() {
        XCTAssertThrowsError(
            try PathValidator.validate("Sources\\\\file.swift", basePath: basePath)
        ) { error in
            guard case PathSecurityError.suspiciousPattern(_, let pattern) = error else {
                XCTFail("Expected suspiciousPattern, got \(error)")
                return
            }
            XCTAssertEqual(pattern, "\\\\")
        }
    }

    func testNewlineBlocked() {
        XCTAssertThrowsError(
            try PathValidator.validate("file\n.swift", basePath: basePath)
        ) { error in
            guard case PathSecurityError.suspiciousPattern(_, let pattern) = error else {
                XCTFail("Expected suspiciousPattern, got \(error)")
                return
            }
            XCTAssertEqual(pattern, "\n")
        }
    }

    func testCarriageReturnBlocked() {
        XCTAssertThrowsError(
            try PathValidator.validate("file\r.swift", basePath: basePath)
        ) { error in
            guard case PathSecurityError.suspiciousPattern(_, let pattern) = error else {
                XCTFail("Expected suspiciousPattern, got \(error)")
                return
            }
            XCTAssertEqual(pattern, "\r")
        }
    }

    // MARK: - Special Characters in Paths

    func testSpacesInPathAllowed() throws {
        let result = try PathValidator.validate("My Documents/file.swift", basePath: basePath)
        XCTAssertEqual(result, "/Users/alexis/Projects/Thea/My Documents/file.swift")
    }

    func testUnicodeInPathAllowed() throws {
        let result = try PathValidator.validate("Sources/Résumé.swift", basePath: basePath)
        XCTAssertEqual(result, "/Users/alexis/Projects/Thea/Sources/Résumé.swift")
    }

    func testEmojiInPathAllowed() throws {
        let result = try PathValidator.validate("Docs/notes-📝.md", basePath: basePath)
        XCTAssertEqual(result, "/Users/alexis/Projects/Thea/Docs/notes-📝.md")
    }

    func testDashAndUnderscoreAllowed() throws {
        let result = try PathValidator.validate("my-dir_v2/file_name-2.swift", basePath: basePath)
        XCTAssertEqual(result, "/Users/alexis/Projects/Thea/my-dir_v2/file_name-2.swift")
    }

    func testSingleDotInPathAllowed() throws {
        // "." is current directory, should resolve to basePath itself
        let result = try PathValidator.validate(".", basePath: basePath)
        XCTAssertEqual(result, basePath)
    }

    // MARK: - Home Directory Expansion

    func testTildeIsNotExpandedInRelativePath() throws {
        // "~" should be treated as a literal directory name, not expanded
        let result = try PathValidator.validate("~/etc/passwd", basePath: basePath)
        // NSString.appendingPathComponent treats "~" literally
        XCTAssertTrue(result.hasPrefix(basePath), "Path must stay within basePath")
    }

    // MARK: - Very Long Paths

    func testVeryLongPathAccepted() throws {
        // 200-character relative path with valid segments
        let segment = "abcdefghij" // 10 chars
        let longPath = (0 ..< 20).map { _ in segment }.joined(separator: "/")
        let result = try PathValidator.validate(longPath, basePath: basePath)
        XCTAssertTrue(result.hasPrefix(basePath))
        XCTAssertTrue(result.count > 200)
    }

    func testPathWithMaxComponents() throws {
        // Deep nesting — 50 levels
        let deepPath = (0 ..< 50).map { "d\($0)" }.joined(separator: "/")
        let result = try PathValidator.validate(deepPath, basePath: basePath)
        XCTAssertTrue(result.hasPrefix(basePath))
    }

    // MARK: - Edge Cases

    func testEmptyRelativePathResolvesToBase() throws {
        let result = try PathValidator.validate("", basePath: basePath)
        XCTAssertEqual(result, basePath)
    }

    func testBasePathWithTrailingSlash() throws {
        let baseWithSlash = basePath + "/"
        let result = try PathValidator.validate("file.swift", basePath: baseWithSlash)
        XCTAssertEqual(result, "/Users/alexis/Projects/Thea/file.swift")
    }

    func testDotSlashPrefix() throws {
        // "./file" should resolve to basePath/file
        let result = try PathValidator.validate("./Sources/main.swift", basePath: basePath)
        XCTAssertEqual(result, "/Users/alexis/Projects/Thea/Sources/main.swift")
    }

    func testInternalDotDotThatStaysWithinBase() throws {
        // "a/b/../c" resolves to "a/c" which is still within basePath
        let result = try PathValidator.validate("a/b/../c/file.swift", basePath: basePath)
        XCTAssertEqual(result, "/Users/alexis/Projects/Thea/a/c/file.swift")
    }

    func testAllSuspiciousPatternsAreChecked() {
        // Verify every pattern in the suspicious list triggers rejection
        let testCases: [(String, String)] = [
            ("a.../b", "..."),
            ("a//b", "//"),
            ("a\\\\b", "\\\\"),
            ("a\nb", "\n"),
            ("a\rb", "\r"),
            ("a%00b", "%00"),
            ("a%2e%2eb", "%2e%2e"),
            ("a%2fb", "%2f"),
            ("a%5cb", "%5c"),
        ]
        for (input, expectedPattern) in testCases {
            XCTAssertThrowsError(
                try PathValidator.validate(input, basePath: basePath),
                "Pattern '\(expectedPattern)' should be rejected in '\(input)'"
            ) { error in
                guard case PathSecurityError.suspiciousPattern(_, let pattern) = error else {
                    XCTFail("Expected suspiciousPattern for '\(expectedPattern)', got \(error)")
                    return
                }
                XCTAssertEqual(pattern, expectedPattern)
            }
        }
    }

    // MARK: - Symlink Simulation (Logic-Level)

    func testSymlinkResolutionConcern() throws {
        // standardizingPath resolves ".." but not actual symlinks (requires FS).
        // This test documents that the validator relies on standardizingPath,
        // which resolves syntactic traversal but NOT real symlinks.
        // Real symlink testing requires filesystem access — out of scope here.
        //
        // Verify that a path with ".." that resolves back INTO basePath is accepted:
        let result = try PathValidator.validate("a/../b/file.swift", basePath: basePath)
        XCTAssertEqual(result, "/Users/alexis/Projects/Thea/b/file.swift")

        // And one that escapes is blocked:
        XCTAssertThrowsError(
            try PathValidator.validate("a/../../OtherProject/file.swift", basePath: basePath)
        ) { error in
            guard case PathSecurityError.pathTraversalAttempt = error else {
                XCTFail("Expected pathTraversalAttempt, got \(error)")
                return
            }
        }
    }

    // MARK: - Allowed vs Restricted Directories

    func testSubdirectoryOfBaseIsAllowed() throws {
        let subdirs = ["Sources", "Tests", "Shared/Core", "Resources/Assets", ".git/objects"]
        for sub in subdirs {
            let result = try PathValidator.validate(sub, basePath: basePath)
            XCTAssertTrue(
                result.hasPrefix(basePath),
                "Subdirectory '\(sub)' should be within basePath"
            )
        }
    }

    func testSystemDirectoriesAreBlocked() throws {
        let attacks = [
            "../../../etc/passwd",
            "../../../var/log/system.log",
            "../../../../private/etc/hosts",
        ]
        for attack in attacks {
            XCTAssertThrowsError(
                try PathValidator.validate(attack, basePath: basePath),
                "Attack path '\(attack)' should be blocked"
            )
        }
    }
}
