// SkillsRegistry+Types.swift
// Thea
//
// Supporting types for SkillsRegistryService.

import Foundation
import OSLog

private let skillsTypesLogger = Logger(subsystem: "com.thea.app", category: "SkillsRegistryTypes")

// MARK: - Models

public struct MarketplaceSkill: Identifiable, Codable, Sendable {
    public let id: String
    public let name: String
    public let description: String
    public let category: MarketplaceSkillCategory
    public let tags: [String]
    public let author: String
    public let version: String
    public let downloads: Int
    public let trustScore: Int // 0-10 (Context7 scale)
    public let relatedLibraries: [String]
    public let instructions: String

    // Context7 Skills Registry additions
    public let repositoryPath: String?  // e.g., "/anthropics/skills"
    public let isVerified: Bool
    public let benchmarkScore: Int?

    public var trustLevel: TrustLevel {
        switch trustScore {
        case 7...10: return .high
        case 3..<7: return .medium
        default: return .low
        }
    }

    public init(
        id: String,
        name: String,
        description: String,
        category: MarketplaceSkillCategory,
        tags: [String],
        author: String,
        version: String,
        downloads: Int,
        trustScore: Int,
        relatedLibraries: [String],
        instructions: String,
        repositoryPath: String? = nil,
        isVerified: Bool = false,
        benchmarkScore: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.category = category
        self.tags = tags
        self.author = author
        self.version = version
        self.downloads = downloads
        self.trustScore = trustScore
        self.relatedLibraries = relatedLibraries
        self.instructions = instructions
        self.repositoryPath = repositoryPath
        self.isVerified = isVerified
        self.benchmarkScore = benchmarkScore
    }
}

public enum MarketplaceSkillCategory: String, Codable, Sendable, CaseIterable {
    case coding
    case architecture
    case testing
    case documentation
    case devops
    case security
    case data
    case other
}

public struct InstalledSkill: Identifiable, Codable, Sendable {
    public let id: String
    public let marketplaceId: String
    public let name: String
    public let description: String
    public let instructions: String
    public let scope: SkillInstallScope
    public let installedAt: Date
    public let version: String
    public let trustScore: Int

    public func toSkillDefinition() -> SkillDefinition {
        SkillDefinition(
            id: id,
            name: name,
            description: description,
            instructions: instructions,
            scope: scope == .global ? .global : .workspace,
            triggers: [SkillTrigger(type: .keyword, pattern: name.lowercased())]
        )
    }
}

public enum SkillInstallScope: Codable, Sendable, Equatable {
    case global
    case project(path: String)

    public var rawValue: String {
        switch self {
        case .global: return "global"
        case .project(let path): return "project:\(path)"
        }
    }
}

public struct SkillReview: Identifiable, Codable, Sendable {
    public let id: String
    public let skillId: String
    public let userId: String
    public let rating: Int // 1-5
    public let comment: String
    public let createdAt: Date
}

public enum VoteType: String, Codable, Sendable {
    case up
    case down
}

struct MarketplaceCache: Codable {
    let skills: [MarketplaceSkill]
    let syncedAt: Date
}

// MARK: - Dependency Scanner

/// Scans project dependencies to suggest relevant skills
actor DependencyScanner {
    struct Dependency: Sendable {
        let name: String
        let version: String?
        let type: DependencyType
    }

    enum DependencyType: Sendable {
        case npm
        case pip
        case swift
        case cocoapods
        case gradle
    }

    func scanDependencies(at path: URL) async -> [Dependency] {
        var dependencies: [Dependency] = []

        // Scan package.json (npm)
        let packageJson = path.appendingPathComponent("package.json")
        if let npmDeps = scanPackageJson(at: packageJson) {
            dependencies.append(contentsOf: npmDeps)
        }

        // Scan requirements.txt (pip)
        let requirementsTxt = path.appendingPathComponent("requirements.txt")
        if let pipDeps = scanRequirementsTxt(at: requirementsTxt) {
            dependencies.append(contentsOf: pipDeps)
        }

        // Scan pyproject.toml (pip)
        let pyprojectToml = path.appendingPathComponent("pyproject.toml")
        if let pyDeps = scanPyprojectToml(at: pyprojectToml) {
            dependencies.append(contentsOf: pyDeps)
        }

        // Scan Package.swift (SPM)
        let packageSwift = path.appendingPathComponent("Package.swift")
        if let swiftDeps = scanPackageSwift(at: packageSwift) {
            dependencies.append(contentsOf: swiftDeps)
        }

        return dependencies
    }

    private func scanPackageJson(at url: URL) -> [Dependency]? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            skillsTypesLogger.debug("Failed to read package.json: \(error.localizedDescription)")
            return nil
        }
        let json: [String: Any]
        do {
            guard let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
            json = parsed
        } catch {
            skillsTypesLogger.debug("Failed to parse package.json: \(error.localizedDescription)")
            return nil
        }

        var deps: [Dependency] = []

        for key in ["dependencies", "devDependencies"] {
            if let packages = json[key] as? [String: String] {
                for (name, version) in packages {
                    deps.append(Dependency(name: name, version: version, type: .npm))
                }
            }
        }

        return deps.isEmpty ? nil : deps
    }

    private func scanRequirementsTxt(at url: URL) -> [Dependency]? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let content: String
        do {
            content = try String(contentsOf: url, encoding: .utf8)
        } catch {
            skillsTypesLogger.debug("Failed to read requirements.txt: \(error.localizedDescription)")
            return nil
        }

        var deps: [Dependency] = []

        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }

            // Parse "package==version" or "package>=version" etc.
            let parts = trimmed.components(separatedBy: CharacterSet(charactersIn: "=<>!"))
            if let name = parts.first?.trimmingCharacters(in: .whitespaces), !name.isEmpty {
                deps.append(Dependency(name: name, version: nil, type: .pip))
            }
        }

        return deps.isEmpty ? nil : deps
    }

    private func scanPyprojectToml(at url: URL) -> [Dependency]? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let content: String
        do {
            content = try String(contentsOf: url, encoding: .utf8)
        } catch {
            skillsTypesLogger.debug("Failed to read pyproject.toml: \(error.localizedDescription)")
            return nil
        }

        // Simple parsing - look for dependencies section
        var deps: [Dependency] = []
        var inDependencies = false

        for line in content.components(separatedBy: .newlines) {
            if line.contains("[project.dependencies]") || line.contains("[tool.poetry.dependencies]") {
                inDependencies = true
                continue
            }
            if line.hasPrefix("[") && inDependencies {
                inDependencies = false
                continue
            }
            if inDependencies {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.contains("=") {
                    let parts = trimmed.components(separatedBy: "=")
                    if let name = parts.first?.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "\"", with: "") {
                        deps.append(Dependency(name: name, version: nil, type: .pip))
                    }
                }
            }
        }

        return deps.isEmpty ? nil : deps
    }

    private func scanPackageSwift(at url: URL) -> [Dependency]? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let content: String
        do {
            content = try String(contentsOf: url, encoding: .utf8)
        } catch {
            skillsTypesLogger.debug("Failed to read Package.swift: \(error.localizedDescription)")
            return nil
        }

        // Simple parsing - look for .package(url: or .package(name:
        var deps: [Dependency] = []

        // Extract package names from .package declarations
        let pattern = #"\.package\([^)]*(?:name:\s*"([^"]+)"|url:[^)]*\/([^"\/]+)(?:\.git)?)"#
        let regex: NSRegularExpression
        do {
            regex = try NSRegularExpression(pattern: pattern)
        } catch {
            skillsTypesLogger.debug("Failed to compile Swift package regex: \(error.localizedDescription)")
            return deps.isEmpty ? nil : deps
        }
        let range = NSRange(content.startIndex..., in: content)
        let matches = regex.matches(in: content, range: range)
        for match in matches {
            for i in 1..<match.numberOfRanges {
                if let range = Range(match.range(at: i), in: content) {
                    let name = String(content[range])
                    deps.append(Dependency(name: name, version: nil, type: .swift))
                    break
                }
            }
        }

        return deps.isEmpty ? nil : deps
    }
}
