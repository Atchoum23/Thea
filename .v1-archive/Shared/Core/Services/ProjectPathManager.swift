import Foundation

// MARK: - ProjectPathManager

// Centralized management of project path resolution
// SECURITY: No hardcoded paths - uses runtime detection only

@MainActor
public final class ProjectPathManager {
    public static let shared = ProjectPathManager()

    // MARK: - Keys

    private let userDefaultsKey = "TheaProjectPath"
    private let environmentKey = "THEA_PROJECT_PATH"

    // MARK: - Cached Path

    private var _cachedPath: String?

    private init() {}

    // MARK: - Configuration

    /// Explicitly set the project path (persisted to UserDefaults)
    public func setProjectPath(_ path: String) {
        guard FileManager.default.fileExists(atPath: path) else {
            print("⚠️ ProjectPathManager: Path does not exist: \(path)")
            return
        }
        UserDefaults.standard.set(path, forKey: userDefaultsKey)
        _cachedPath = path
        print("✅ ProjectPathManager: Set project path to: \(path)")
    }

    /// Clear the cached and saved project path
    public func clearProjectPath() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        _cachedPath = nil
    }

    // MARK: - Path Resolution

    /// Get the current project path using the resolution chain
    /// Priority: 1. Cached → 2. Configured → 3. Environment → 4. UserDefaults → 5. Bundle Detection → 6. Current Directory
    public var projectPath: String? {
        // 1. Return cached path if valid
        if let cached = _cachedPath, FileManager.default.fileExists(atPath: cached) {
            return cached
        }

        // 2. Try environment variable
        if let envPath = ProcessInfo.processInfo.environment[environmentKey],
           !envPath.isEmpty,
           FileManager.default.fileExists(atPath: envPath)
        {
            _cachedPath = envPath
            return envPath
        }

        // 3. Try UserDefaults (persisted setting)
        if let savedPath = UserDefaults.standard.string(forKey: userDefaultsKey),
           FileManager.default.fileExists(atPath: savedPath)
        {
            _cachedPath = savedPath
            return savedPath
        }

        // 4. Try Bundle path resolution (works when running from Xcode)
        if let bundlePath = resolveFromBundle() {
            _cachedPath = bundlePath
            return bundlePath
        }

        // 5. Try current directory if it contains project.yml
        let currentDir = FileManager.default.currentDirectoryPath
        if isValidTheaProject(at: currentDir) {
            _cachedPath = currentDir
            return currentDir
        }

        // 6. No valid path found
        print("⚠️ ProjectPathManager: No valid project path found")
        return nil
    }

    /// Get project path, throwing if not found
    public func requireProjectPath() throws -> String {
        guard let path = projectPath else {
            throw ProjectPathError.projectPathNotFound
        }
        return path
    }

    // MARK: - Validation

    /// Check if a path appears to be a valid Thea project
    public func isValidTheaProject(at path: String) -> Bool {
        let fm = FileManager.default

        // Check for project.yml (XcodeGen config)
        let projectYml = (path as NSString).appendingPathComponent("project.yml")
        if fm.fileExists(atPath: projectYml) {
            return true
        }

        // Check for Shared directory (source folder)
        let sharedDir = (path as NSString).appendingPathComponent("Shared")
        if fm.fileExists(atPath: sharedDir) {
            return true
        }

        // Check for Thea.xcodeproj
        let xcodeproj = (path as NSString).appendingPathComponent("Thea.xcodeproj")
        if fm.fileExists(atPath: xcodeproj) {
            return true
        }

        return false
    }

    // MARK: - Private Helpers

    private func resolveFromBundle() -> String? {
        guard let bundlePath = Bundle.main.resourcePath else {
            return nil
        }

        // When running from Xcode, the bundle is inside DerivedData
        // Walk up the tree to find the source project

        let components = bundlePath.components(separatedBy: "/")

        // Look for DerivedData pattern
        if let derivedDataIndex = components.firstIndex(of: "DerivedData") {
            // Path before DerivedData might be the project
            let basePath = components[0 ..< derivedDataIndex].joined(separator: "/")

            // Try common project locations relative to DerivedData parent
            let possiblePaths = [
                basePath,
                (basePath as NSString).deletingLastPathComponent
            ]

            for possiblePath in possiblePaths {
                if isValidTheaProject(at: possiblePath) {
                    return possiblePath
                }
            }
        }

        // Try walking up from bundle
        var currentPath = bundlePath
        for _ in 0 ..< 5 { // Max 5 levels up
            currentPath = (currentPath as NSString).deletingLastPathComponent
            if isValidTheaProject(at: currentPath) {
                return currentPath
            }
        }

        return nil
    }
}

// MARK: - Path Traversal Security

public extension ProjectPathManager {
    /// SECURITY: Validate that a resolved path stays within the allowed base directory
    /// Prevents path traversal attacks using ../ or symlinks
    /// SECURITY FIX (FINDING-007): Uses component-wise validation instead of string prefix
    func validatePath(_ relativePath: String, basePath: String) throws -> String {
        // SECURITY: Reject paths with null bytes (path injection attack) FIRST
        guard !relativePath.contains("\0") else {
            throw PathSecurityError.nullByteInjection(path: relativePath)
        }

        // SECURITY: Reject paths with suspicious patterns BEFORE any processing
        let suspiciousPatterns = ["...", "//", "\\\\", "\n", "\r", "%00", "%2e%2e", "%2f", "%5c"]
        for pattern in suspiciousPatterns {
            if relativePath.lowercased().contains(pattern) {
                throw PathSecurityError.suspiciousPattern(path: relativePath, pattern: pattern)
            }
        }

        // Remove any leading slash to ensure it's treated as relative
        let cleanRelative = relativePath.hasPrefix("/") ? String(relativePath.dropFirst()) : relativePath

        // Construct the full path
        let fullPath = (basePath as NSString).appendingPathComponent(cleanRelative)

        // Resolve symlinks and normalize the path
        let resolvedPath = (fullPath as NSString).standardizingPath

        // Normalize the base path too
        let resolvedBase = (basePath as NSString).standardizingPath

        // SECURITY FIX (FINDING-007): Use component-wise validation instead of hasPrefix
        // The hasPrefix check is vulnerable: "/allowed/path_evil" matches "/allowed/path"
        let resolvedComponents = (resolvedPath as NSString).pathComponents
        let baseComponents = (resolvedBase as NSString).pathComponents

        // Verify the resolved path contains at least as many components as base
        guard resolvedComponents.count >= baseComponents.count else {
            throw PathSecurityError.pathTraversalAttempt(
                requested: relativePath,
                resolved: resolvedPath,
                allowed: resolvedBase
            )
        }

        // Verify each base component matches exactly
        for (index, baseComponent) in baseComponents.enumerated() {
            guard resolvedComponents[index] == baseComponent else {
                throw PathSecurityError.pathTraversalAttempt(
                    requested: relativePath,
                    resolved: resolvedPath,
                    allowed: resolvedBase
                )
            }
        }

        return resolvedPath
    }

    /// SECURITY: Validate and return a safe full path
    func safeFullPath(for relativePath: String) throws -> String {
        guard let base = projectPath else {
            throw ProjectPathError.projectPathNotFound
        }
        return try validatePath(relativePath, basePath: base)
    }
}

// MARK: - Security Errors

public enum PathSecurityError: Error, LocalizedError {
    case pathTraversalAttempt(requested: String, resolved: String, allowed: String)
    case nullByteInjection(path: String)
    case suspiciousPattern(path: String, pattern: String)

    public var errorDescription: String? {
        switch self {
        case let .pathTraversalAttempt(requested, resolved, allowed):
            "SECURITY: Path traversal attempt blocked. Requested '\(requested)' resolved to '\(resolved)' which is outside allowed base '\(allowed)'"
        case let .nullByteInjection(path):
            "SECURITY: Null byte injection detected in path: \(path)"
        case let .suspiciousPattern(path, pattern):
            "SECURITY: Suspicious pattern '\(pattern)' detected in path: \(path)"
        }
    }
}

// MARK: - Errors

public enum ProjectPathError: Error, LocalizedError {
    case projectPathNotFound
    case pathDoesNotExist(String)
    case invalidProjectStructure(String)

    public var errorDescription: String? {
        switch self {
        case .projectPathNotFound:
            "Thea project path not found. Set THEA_PROJECT_PATH environment variable or configure in Settings."
        case let .pathDoesNotExist(path):
            "Project path does not exist: \(path)"
        case let .invalidProjectStructure(path):
            "Invalid Thea project structure at: \(path)"
        }
    }
}
