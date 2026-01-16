import Foundation
import OSLog

// MARK: - GitSavepoint
// Git savepoint management for safe rollback during autonomous fixes

public actor GitSavepoint {
    public static let shared = GitSavepoint()

    private let logger = Logger(subsystem: "com.thea.system", category: "GitSavepoint")
    private let repoPath = "/Users/alexis/Documents/IT & Tech/MyApps/Thea/Development"

    private init() {}

    // MARK: - Public Types

    public struct Savepoint: Sendable, Identifiable {
        public let id: String
        public let message: String
        public let timestamp: Date
        public let commitHash: String?

        public init(id: String, message: String, timestamp: Date, commitHash: String?) {
            self.id = id
            self.message = message
            self.timestamp = timestamp
            self.commitHash = commitHash
        }
    }

    public enum SavepointError: LocalizedError, Sendable {
        case gitNotAvailable
        case savepointFailed(String)
        case rollbackFailed(String)
        case invalidSavepoint

        public var errorDescription: String? {
            switch self {
            case .gitNotAvailable:
                return "Git is not available"
            case .savepointFailed(let message):
                return "Failed to create savepoint: \(message)"
            case .rollbackFailed(let message):
                return "Failed to rollback: \(message)"
            case .invalidSavepoint:
                return "Invalid savepoint ID"
            }
        }
    }

    // MARK: - Create Savepoint

    public func createSavepoint(message: String) async throws -> String {
        logger.info("Creating savepoint: \(message)")

        // Check if there are uncommitted changes
        let statusResult = try await TerminalService.shared.git(
            arguments: ["status", "--porcelain"],
            workingDirectory: repoPath
        )

        guard statusResult.isSuccess else {
            throw SavepointError.gitNotAvailable
        }

        let hasChanges = !statusResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        if hasChanges {
            // Create a commit for the savepoint
            return try await createCommitSavepoint(message: message)
        } else {
            // No changes, just record current HEAD
            return try await getCurrentCommit()
        }
    }

    // MARK: - Rollback

    public func rollback(to savepoint: String) async throws {
        logger.info("Rolling back to savepoint: \(savepoint)")

        // Verify savepoint exists (it's either a commit hash or stash reference)
        if savepoint.hasPrefix("stash@{") {
            // It's a stash
            try await rollbackToStash(savepoint)
        } else {
            // It's a commit hash
            try await rollbackToCommit(savepoint)
        }
    }

    // MARK: - List Savepoints

    public func listSavepoints(limit: Int = 10) async throws -> [Savepoint] {
        // List recent commits that might be savepoints
        let logResult = try await TerminalService.shared.git(
            arguments: ["log", "--format=%H|%s|%at", "-n", "\(limit)"],
            workingDirectory: repoPath
        )

        guard logResult.isSuccess else {
            throw SavepointError.gitNotAvailable
        }

        let lines = logResult.stdout.components(separatedBy: .newlines)
        var savepoints: [Savepoint] = []

        for line in lines {
            let parts = line.components(separatedBy: "|")
            guard parts.count == 3 else { continue }

            let hash = parts[0]
            let message = parts[1]
            let timestamp = TimeInterval(parts[2]) ?? 0
            let date = Date(timeIntervalSince1970: timestamp)

            savepoints.append(Savepoint(
                id: hash,
                message: message,
                timestamp: date,
                commitHash: hash
            ))
        }

        return savepoints
    }

    // MARK: - Private Helpers

    private func createCommitSavepoint(message: String) async throws -> String {
        // Stage all changes
        let addResult = try await TerminalService.shared.git(
            arguments: ["add", "-A"],
            workingDirectory: repoPath
        )

        guard addResult.isSuccess else {
            throw SavepointError.savepointFailed("Failed to stage changes")
        }

        // Create commit
        let commitMessage = "SAVEPOINT: \(message)"
        let commitResult = try await TerminalService.shared.git(
            arguments: ["commit", "-m", commitMessage],
            workingDirectory: repoPath
        )

        guard commitResult.isSuccess else {
            throw SavepointError.savepointFailed("Failed to create commit: \(commitResult.stderr)")
        }

        // Get the commit hash
        let commit = try await getCurrentCommit()
        logger.info("Created savepoint commit: \(commit)")
        return commit
    }

    private func getCurrentCommit() async throws -> String {
        let result = try await TerminalService.shared.git(
            arguments: ["rev-parse", "HEAD"],
            workingDirectory: repoPath
        )

        guard result.isSuccess else {
            throw SavepointError.gitNotAvailable
        }

        return result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func rollbackToCommit(_ commitHash: String) async throws {
        // Reset to the commit (keeping working directory changes)
        let resetResult = try await TerminalService.shared.git(
            arguments: ["reset", "--hard", commitHash],
            workingDirectory: repoPath
        )

        guard resetResult.isSuccess else {
            throw SavepointError.rollbackFailed("Failed to reset to commit: \(resetResult.stderr)")
        }

        logger.info("Rolled back to commit: \(commitHash)")
    }

    private func rollbackToStash(_ stashRef: String) async throws {
        // Apply the stash
        let stashResult = try await TerminalService.shared.git(
            arguments: ["stash", "apply", stashRef],
            workingDirectory: repoPath
        )

        guard stashResult.isSuccess else {
            throw SavepointError.rollbackFailed("Failed to apply stash: \(stashResult.stderr)")
        }

        logger.info("Applied stash: \(stashRef)")
    }

    // MARK: - Clean Working Directory

    public func cleanWorkingDirectory() async throws {
        // Discard all uncommitted changes
        let cleanResult = try await TerminalService.shared.git(
            arguments: ["reset", "--hard", "HEAD"],
            workingDirectory: repoPath
        )

        guard cleanResult.isSuccess else {
            throw SavepointError.savepointFailed("Failed to clean working directory")
        }

        // Remove untracked files
        let removeResult = try await TerminalService.shared.git(
            arguments: ["clean", "-fd"],
            workingDirectory: repoPath
        )

        if !removeResult.isSuccess {
            logger.warning("Failed to remove untracked files: \(removeResult.stderr)")
            // Continue anyway - this is not critical
        }

        logger.info("Cleaned working directory")
    }

    // MARK: - Check Repository State

    public func hasUncommittedChanges() async throws -> Bool {
        let statusResult = try await TerminalService.shared.git(
            arguments: ["status", "--porcelain"],
            workingDirectory: repoPath
        )

        guard statusResult.isSuccess else {
            throw SavepointError.gitNotAvailable
        }

        return !statusResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
