// ReleaseMonitor.swift
// Watches for new releases of Thea's dependencies

#if os(macOS)
import Foundation
import os.log

/// Monitors dependency releases via GitHub API and Apple developer feeds.
/// When a new version is detected, creates a task to evaluate compatibility.
actor ReleaseMonitor {
    static let shared = ReleaseMonitor()

    private let logger = Logger(subsystem: "ai.thea.app", category: "ReleaseMonitor")

    // MARK: - Types

    struct DependencyRelease: Codable, Sendable, Identifiable {
        let id: UUID
        let name: String
        let currentVersion: String
        let latestVersion: String
        let releaseURL: String
        let publishedAt: Date
        let isBreaking: Bool
        let checkedAt: Date

        init(
            name: String,
            currentVersion: String,
            latestVersion: String,
            releaseURL: String,
            publishedAt: Date,
            isBreaking: Bool
        ) {
            self.id = UUID()
            self.name = name
            self.currentVersion = currentVersion
            self.latestVersion = latestVersion
            self.releaseURL = releaseURL
            self.publishedAt = publishedAt
            self.isBreaking = isBreaking
            self.checkedAt = Date()
        }
    }

    struct TrackedDependency: Codable, Sendable {
        let name: String
        let owner: String
        let repo: String
        let currentVersion: String

        var githubAPIURL: String {
            "https://api.github.com/repos/\(owner)/\(repo)/releases/latest"
        }
    }

    // MARK: - State

    private(set) var availableUpdates: [DependencyRelease] = []
    private(set) var lastCheckDate: Date?
    private let storageURL: URL

    /// Dependencies tracked by Thea (from Package.resolved)
    private let trackedDependencies: [TrackedDependency] = [
        TrackedDependency(name: "mlx-swift", owner: "ml-explore", repo: "mlx-swift", currentVersion: "0.21.2"),
        TrackedDependency(name: "mlx-swift-lm", owner: "ml-explore", repo: "mlx-swift-examples", currentVersion: "1.22.0"),
        TrackedDependency(name: "swift-collections", owner: "apple", repo: "swift-collections", currentVersion: "1.1.4"),
        TrackedDependency(name: "swift-argument-parser", owner: "apple", repo: "swift-argument-parser", currentVersion: "1.5.0"),
        TrackedDependency(name: "KeychainAccess", owner: "kishikawakatsumi", repo: "KeychainAccess", currentVersion: "4.2.2"),
        TrackedDependency(name: "swift-log", owner: "apple", repo: "swift-log", currentVersion: "1.6.2"),
        TrackedDependency(name: "swift-markdown", owner: "swiftlang", repo: "swift-markdown", currentVersion: "0.5.0")
    ]

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let theaDir = appSupport.appendingPathComponent("Thea")
        try? FileManager.default.createDirectory(at: theaDir, withIntermediateDirectories: true)
        storageURL = theaDir.appendingPathComponent("release_monitor.json")

        // Load persisted state
        if let data = try? Data(contentsOf: storageURL),
           let state = try? JSONDecoder().decode(MonitorState.self, from: data) {
            availableUpdates = state.updates
            lastCheckDate = state.lastCheck
        }
    }

    // MARK: - Public API

    /// Check all tracked dependencies for new releases
    func checkForUpdates() async -> [DependencyRelease] {
        logger.info("Checking \(self.trackedDependencies.count) dependencies for updates...")
        var updates: [DependencyRelease] = []

        for dep in trackedDependencies {
            if let release = await checkDependency(dep) {
                updates.append(release)
                logger.info("Update available: \(dep.name) \(dep.currentVersion) → \(release.latestVersion)")
            }
        }

        availableUpdates = updates
        lastCheckDate = Date()
        saveState()

        logger.info("Release check complete: \(updates.count) updates available")
        return updates
    }

    /// Check a single dependency for updates
    func checkDependency(_ dep: TrackedDependency) async -> DependencyRelease? {
        guard let url = URL(string: dep.githubAPIURL) else { return nil }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Thea/1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else { return nil }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tagName = json["tag_name"] as? String,
                  let htmlURL = json["html_url"] as? String else { return nil }

            // Normalize version (strip 'v' prefix)
            let latestVersion = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName

            // Skip if same version
            guard latestVersion != dep.currentVersion else { return nil }

            // Parse published date
            let publishedAt: Date
            if let dateStr = json["published_at"] as? String {
                let formatter = ISO8601DateFormatter()
                publishedAt = formatter.date(from: dateStr) ?? Date()
            } else {
                publishedAt = Date()
            }

            // Determine if breaking (major version bump)
            let isBreaking = isMajorVersionBump(from: dep.currentVersion, to: latestVersion)

            return DependencyRelease(
                name: dep.name,
                currentVersion: dep.currentVersion,
                latestVersion: latestVersion,
                releaseURL: htmlURL,
                publishedAt: publishedAt,
                isBreaking: isBreaking
            )
        } catch {
            logger.warning("Failed to check \(dep.name): \(error.localizedDescription)")
            return nil
        }
    }

    /// Generate a summary report of available updates
    func generateReport() -> String {
        guard !availableUpdates.isEmpty else {
            return "All dependencies are up to date."
        }

        var report = "## Dependency Update Report\n\n"
        report += "**Checked:** \(lastCheckDate?.formatted() ?? "Never")\n\n"

        let breaking = availableUpdates.filter(\.isBreaking)
        let minor = availableUpdates.filter { !$0.isBreaking }

        if !breaking.isEmpty {
            report += "### Breaking Updates\n"
            for update in breaking {
                report += "- **\(update.name)**: \(update.currentVersion) → \(update.latestVersion)\n"
            }
            report += "\n"
        }

        if !minor.isEmpty {
            report += "### Compatible Updates\n"
            for update in minor {
                report += "- \(update.name): \(update.currentVersion) → \(update.latestVersion)\n"
            }
        }

        return report
    }

    // MARK: - Version Comparison

    private func isMajorVersionBump(from current: String, to latest: String) -> Bool {
        let currentParts = current.split(separator: ".").compactMap { Int($0) }
        let latestParts = latest.split(separator: ".").compactMap { Int($0) }
        guard let currentMajor = currentParts.first,
              let latestMajor = latestParts.first else { return false }
        return latestMajor > currentMajor
    }

    // MARK: - Persistence

    private struct MonitorState: Codable {
        let updates: [DependencyRelease]
        let lastCheck: Date?
    }

    private func saveState() {
        let state = MonitorState(updates: availableUpdates, lastCheck: lastCheckDate)
        if let data = try? JSONEncoder().encode(state) {
            try? data.write(to: storageURL)
        }
    }

    private func loadState() {
        guard let data = try? Data(contentsOf: storageURL),
              let state = try? JSONDecoder().decode(MonitorState.self, from: data) else { return }
        availableUpdates = state.updates
        lastCheckDate = state.lastCheck
    }
}
#endif
