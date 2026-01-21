#if os(macOS)
import AppKit
import Foundation

/// Manages folder access permissions for Cowork sessions
@MainActor
@Observable
final class FolderAccessManager {
    static let shared = FolderAccessManager()

    var allowedFolders: [AllowedFolder] = []
    var recentFolders: [URL] = []

    private let bookmarksKey = "cowork.folderBookmarks"
    private let recentFoldersKey = "cowork.recentFolders"
    private let maxRecentFolders = 10

    struct AllowedFolder: Identifiable, Equatable {
        let id: UUID
        let url: URL
        var bookmark: Data?
        var permissions: Permissions
        var addedAt: Date

        struct Permissions: OptionSet, Equatable {
            let rawValue: Int

            static let read = Permissions(rawValue: 1 << 0)
            static let write = Permissions(rawValue: 1 << 1)
            static let delete = Permissions(rawValue: 1 << 2)
            static let createSubfolders = Permissions(rawValue: 1 << 3)

            static let readOnly: Permissions = [.read]
            static let readWrite: Permissions = [.read, .write]
            static let full: Permissions = [.read, .write, .delete, .createSubfolders]
        }

        init(url: URL, permissions: Permissions = .full) {
            self.id = UUID()
            self.url = url
            self.permissions = permissions
            self.addedAt = Date()

            // Create security-scoped bookmark
            self.bookmark = try? url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        }
    }

    private init() {
        loadAllowedFolders()
        loadRecentFolders()
    }

    // MARK: - Folder Access

    /// Request access to a folder via system dialog
    @MainActor
    func requestFolderAccess(initialDirectory: URL? = nil) -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.message = "Select a folder for Thea Cowork to access"
        panel.prompt = "Grant Access"

        if let dir = initialDirectory {
            panel.directoryURL = dir
        }

        guard panel.runModal() == .OK, let url = panel.url else {
            return nil
        }

        return url
    }

    /// Add a folder to allowed list
    func addAllowedFolder(_ url: URL, permissions: AllowedFolder.Permissions = .full) {
        // Check if already exists
        if allowedFolders.contains(where: { $0.url == url }) {
            return
        }

        let folder = AllowedFolder(url: url, permissions: permissions)
        allowedFolders.append(folder)
        addToRecentFolders(url)
        saveAllowedFolders()
    }

    /// Remove a folder from allowed list
    func removeAllowedFolder(_ folderId: UUID) {
        allowedFolders.removeAll { $0.id == folderId }
        saveAllowedFolders()
    }

    /// Remove a folder by URL
    func removeAllowedFolder(_ url: URL) {
        allowedFolders.removeAll { $0.url == url }
        saveAllowedFolders()
    }

    /// Update permissions for a folder
    func updatePermissions(for folderId: UUID, permissions: AllowedFolder.Permissions) {
        if let index = allowedFolders.firstIndex(where: { $0.id == folderId }) {
            allowedFolders[index].permissions = permissions
            saveAllowedFolders()
        }
    }

    // MARK: - Access Checking

    /// Check if a URL is within an allowed folder
    /// Security: Uses proper path component comparison to prevent traversal attacks
    func isAllowed(_ url: URL) -> Bool {
        isPathWithinAllowedFolder(url) != nil
    }

    /// Check if a URL has specific permission
    /// Security: Uses proper path component comparison to prevent traversal attacks
    func hasPermission(_ permission: AllowedFolder.Permissions, for url: URL) -> Bool {
        guard let folder = isPathWithinAllowedFolder(url) else {
            return false
        }
        return folder.permissions.contains(permission)
    }

    /// Get the allowed folder containing a URL
    /// Security: Uses proper path component comparison to prevent traversal attacks
    func allowedFolder(containing url: URL) -> AllowedFolder? {
        isPathWithinAllowedFolder(url)
    }
    
    /// Securely check if a path is within an allowed folder
    /// This prevents path traversal attacks by:
    /// 1. Resolving symlinks to canonical paths
    /// 2. Comparing path components (not string prefixes)
    /// 3. Ensuring the target path is actually within the allowed directory
    private func isPathWithinAllowedFolder(_ url: URL) -> AllowedFolder? {
        // Resolve to canonical path (resolves symlinks and removes . and ..)
        let targetPath = url.standardizedFileURL.resolvingSymlinksInPath().path
        
        // Check for null bytes (path truncation attack)
        guard !targetPath.contains("\0") else {
            return nil
        }
        
        for folder in allowedFolders {
            let allowedPath = folder.url.standardizedFileURL.resolvingSymlinksInPath().path
            
            // Use path components for proper comparison
            let targetComponents = targetPath.components(separatedBy: "/")
            let allowedComponents = allowedPath.components(separatedBy: "/")
            
            // Target must have at least as many components as allowed path
            guard targetComponents.count >= allowedComponents.count else {
                continue
            }
            
            // All components of allowed path must match the start of target path
            let matchingComponents = zip(targetComponents, allowedComponents).allSatisfy { $0 == $1 }
            
            if matchingComponents {
                // Additional check: ensure no path traversal in the remaining components
                let remainingComponents = Array(targetComponents.dropFirst(allowedComponents.count))
                if !remainingComponents.contains("..") && !remainingComponents.contains(".") {
                    return folder
                }
            }
        }
        
        return nil
    }

    /// Validate operation before executing
    func validateOperation(_ operation: FileOperation, at url: URL) -> ValidationResult {
        guard isAllowed(url) else {
            return .denied(reason: "URL is not within an allowed folder")
        }

        switch operation {
        case .read:
            if !hasPermission(.read, for: url) {
                return .denied(reason: "Read permission not granted for this folder")
            }
        case .write, .modify:
            if !hasPermission(.write, for: url) {
                return .denied(reason: "Write permission not granted for this folder")
            }
        case .delete:
            if !hasPermission(.delete, for: url) {
                return .denied(reason: "Delete permission not granted for this folder")
            }
        case .createDirectory:
            if !hasPermission(.createSubfolders, for: url) {
                return .denied(reason: "Create subfolder permission not granted")
            }
        }

        return .allowed
    }

    enum FileOperation {
        case read, write, modify, delete, createDirectory
    }

    enum ValidationResult: Equatable {
        case allowed
        case denied(reason: String)
    }

    // MARK: - Security-Scoped Access

    /// Start accessing a security-scoped URL
    func startAccessing(_ url: URL) -> Bool {
        if let folder = allowedFolder(containing: url),
           let bookmark = folder.bookmark {
            var isStale = false
            do {
                let resolvedURL = try URL(
                    resolvingBookmarkData: bookmark,
                    options: .withSecurityScope,
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )
                return resolvedURL.startAccessingSecurityScopedResource()
            } catch {
                return false
            }
        }
        return url.startAccessingSecurityScopedResource()
    }

    /// Stop accessing a security-scoped URL
    func stopAccessing(_ url: URL) {
        url.stopAccessingSecurityScopedResource()
    }

    /// Execute a block with security-scoped access
    func withAccess<T>(to url: URL, perform block: () throws -> T) throws -> T {
        let started = startAccessing(url)
        defer {
            if started {
                stopAccessing(url)
            }
        }
        return try block()
    }

    // MARK: - Recent Folders

    private func addToRecentFolders(_ url: URL) {
        recentFolders.removeAll { $0 == url }
        recentFolders.insert(url, at: 0)
        if recentFolders.count > maxRecentFolders {
            recentFolders.removeLast()
        }
        saveRecentFolders()
    }

    // MARK: - Persistence

    private func saveAllowedFolders() {
        let bookmarks = allowedFolders.compactMap { folder -> [String: Any]? in
            guard let bookmark = folder.bookmark else { return nil }
            return [
                "id": folder.id.uuidString,
                "url": folder.url.path,
                "bookmark": bookmark,
                "permissions": folder.permissions.rawValue,
                "addedAt": folder.addedAt.timeIntervalSince1970
            ]
        }
        UserDefaults.standard.set(bookmarks, forKey: bookmarksKey)
    }

    private func loadAllowedFolders() {
        guard let bookmarks = UserDefaults.standard.array(forKey: bookmarksKey) as? [[String: Any]] else {
            return
        }

        allowedFolders = bookmarks.compactMap { dict -> AllowedFolder? in
            guard let idString = dict["id"] as? String,
                  let _ = UUID(uuidString: idString),
                  let urlPath = dict["url"] as? String,
                  let bookmark = dict["bookmark"] as? Data,
                  let permissionsRaw = dict["permissions"] as? Int,
                  let addedAtInterval = dict["addedAt"] as? TimeInterval else {
                return nil
            }

            let addedAt = Date(timeIntervalSince1970: addedAtInterval)

            var folder = AllowedFolder(
                url: URL(fileURLWithPath: urlPath),
                permissions: AllowedFolder.Permissions(rawValue: permissionsRaw)
            )
            folder.bookmark = bookmark
            folder.addedAt = addedAt

            // Verify bookmark is still valid
            var isStale = false
            if let _ = try? URL(
                resolvingBookmarkData: bookmark,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ), !isStale {
                return folder
            }

            return nil
        }
    }

    private func saveRecentFolders() {
        let paths = recentFolders.map { $0.path }
        UserDefaults.standard.set(paths, forKey: recentFoldersKey)
    }

    private func loadRecentFolders() {
        guard let paths = UserDefaults.standard.stringArray(forKey: recentFoldersKey) else {
            return
        }
        recentFolders = paths.map { URL(fileURLWithPath: $0) }
    }
}
#endif
