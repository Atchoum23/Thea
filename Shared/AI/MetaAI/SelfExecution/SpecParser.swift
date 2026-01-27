// SpecParser.swift
import Foundation
import OSLog

public actor SpecParser {
    public static let shared = SpecParser()

    private let logger = Logger(subsystem: "com.thea.app", category: "SpecParser")

    // Configurable project path - can be set at runtime
    private var _configuredPath: String?

    /// Set a custom project path (useful when running from installed app)
    public func setProjectPath(_ path: String) {
        _configuredPath = path
    }

    // Dynamic base path - SECURITY: No hardcoded paths
    private func getBasePath() async -> String {
        if let configured = _configuredPath, FileManager.default.fileExists(atPath: configured) {
            return configured
        }

        // Use centralized ProjectPathManager
        if let path = await MainActor.run(body: { ProjectPathManager.shared.projectPath }) {
            return path
        }

        // Fallback to current working directory
        return FileManager.default.currentDirectoryPath
    }

    private func getSpecPath() async -> String {
        // Check multiple possible locations for the spec file
        let base = await getBasePath()
        let locations = [
            (base as NSString).appendingPathComponent("Documentation/Architecture/THEA_MASTER_SPEC.md"),
            (base as NSString).appendingPathComponent("Planning/THEA_SPECIFICATION.md"),
            (base as NSString).appendingPathComponent("THEA_MASTER_SPEC.md")
        ]
        return locations.first { FileManager.default.fileExists(atPath: $0) } ?? locations[0]
    }

    public struct ParsedSpec: Sendable {
        public let version: String
        public let phases: [PhaseDefinition]
        public let architectureRules: [String]
        public let fileIndex: [String: FileRequirement.FileStatus]
    }

    // MARK: - Public API

    public func parseSpec() async throws -> ParsedSpec {
        let specPath = await getSpecPath()
        logger.info("Parsing spec from: \(specPath)")

        let content = try String(contentsOfFile: specPath, encoding: .utf8)

        let version = parseVersion(from: content)
        let phases = parsePhases(from: content)
        let rules = parseArchitectureRules(from: content)
        let fileIndex = parseFileIndex(from: content)

        logger.info("Parsed \(phases.count) phases, \(fileIndex.count) files")

        return ParsedSpec(
            version: version,
            phases: phases,
            architectureRules: rules,
            fileIndex: fileIndex
        )
    }

    public func getPhase(_ number: Int) async throws -> PhaseDefinition? {
        let spec = try await parseSpec()
        return spec.phases.first { $0.number == number }
    }

    public func getNextPhase(after phaseId: String) async throws -> PhaseDefinition? {
        let spec = try await parseSpec()
        guard let currentIndex = spec.phases.firstIndex(where: { $0.id == phaseId }) else {
            return nil
        }
        let nextIndex = currentIndex + 1
        guard nextIndex < spec.phases.count else { return nil }
        return spec.phases[nextIndex]
    }

    // MARK: - Parsing Implementation

    private func parseVersion(from content: String) -> String {
        // Extract: **Spec Version**: X.Y.Z
        let pattern = #"\*\*Spec Version\*\*:\s*(\d+\.\d+\.\d+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
              let range = Range(match.range(at: 1), in: content)
        else {
            return "unknown"
        }
        return String(content[range])
    }

    private func parsePhases(from content: String) -> [PhaseDefinition] {
        var phases: [PhaseDefinition] = []

        // Pattern: ### Phase N: Title (X-Y hours)
        let phasePattern = #"### Phase (\d+):\s*([^\n(]+)\s*\((\d+)-(\d+)\s*hours?\)"#
        guard let regex = try? NSRegularExpression(pattern: phasePattern, options: .caseInsensitive) else {
            return phases
        }

        let matches = regex.matches(in: content, range: NSRange(content.startIndex..., in: content))

        for match in matches {
            guard let numberRange = Range(match.range(at: 1), in: content),
                  let titleRange = Range(match.range(at: 2), in: content),
                  let minHoursRange = Range(match.range(at: 3), in: content),
                  let maxHoursRange = Range(match.range(at: 4), in: content)
            else {
                continue
            }

            let number = Int(content[numberRange]) ?? 0
            let title = String(content[titleRange]).trimmingCharacters(in: .whitespaces)
            let minHours = Int(content[minHoursRange]) ?? 0
            let maxHours = Int(content[maxHoursRange]) ?? 0

            // Extract section content for this phase
            let sectionContent = extractPhaseSection(number: number, from: content)
            let files = parseFileRequirements(from: sectionContent)
            let checklist = parseChecklist(from: sectionContent)
            let deliverable = parseDeliverable(from: sectionContent)

            let phase = PhaseDefinition(
                id: "phase\(number)",
                number: number,
                title: title,
                description: extractDescription(from: sectionContent),
                estimatedHours: minHours ... maxHours,
                deliverable: deliverable,
                files: files,
                verificationChecklist: checklist,
                dependencies: number > 1 ? ["phase\(number - 1)"] : []
            )

            phases.append(phase)
        }

        return phases.sorted { $0.number < $1.number }
    }

    private func extractPhaseSection(number: Int, from content: String) -> String {
        // Find start: ### Phase N:
        let startPattern = "### Phase \(number):"
        guard let startRange = content.range(of: startPattern) else {
            return ""
        }

        // Find end: next ### Phase or next ## section
        let remaining = content[startRange.lowerBound...]
        let endPatterns = ["### Phase \(number + 1):", "## §", "---\n\n## "]

        var endIndex = remaining.endIndex
        for pattern in endPatterns {
            if let range = remaining.range(of: pattern) {
                if range.lowerBound < endIndex {
                    endIndex = range.lowerBound
                }
            }
        }

        return String(remaining[..<endIndex])
    }

    private func parseFileRequirements(from section: String) -> [FileRequirement] {
        var files: [FileRequirement] = []

        // Pattern: `path/to/file.swift` [STATUS]
        let filePattern = #"`([^`]+\.swift)`\s*\[(NEW|EDIT|EXISTS)\]"#
        guard let regex = try? NSRegularExpression(pattern: filePattern) else {
            return files
        }

        let matches = regex.matches(in: section, range: NSRange(section.startIndex..., in: section))

        for match in matches {
            guard let pathRange = Range(match.range(at: 1), in: section),
                  let statusRange = Range(match.range(at: 2), in: section)
            else {
                continue
            }

            let path = String(section[pathRange])
            let statusStr = String(section[statusRange])
            let status = FileRequirement.FileStatus(rawValue: statusStr) ?? .new

            // Extract nearby description/hints
            let codeHints = extractCodeHints(for: path, from: section)

            files.append(FileRequirement(
                path: path,
                status: status,
                description: "Implementation required",
                codeHints: codeHints,
                estimatedLines: nil
            ))
        }

        return files
    }

    private func extractCodeHints(for path: String, from section: String) -> [String] {
        // Look for code blocks after the file reference
        var hints: [String] = []

        // Find swift code blocks
        let codePattern = #"```swift\n([\s\S]*?)```"#
        guard let regex = try? NSRegularExpression(pattern: codePattern) else {
            return hints
        }

        let matches = regex.matches(in: section, range: NSRange(section.startIndex..., in: section))

        for match in matches {
            guard let codeRange = Range(match.range(at: 1), in: section) else {
                continue
            }
            let code = String(section[codeRange])
            // Check if this code block is relevant to the file
            let fileName = (path as NSString).lastPathComponent.replacingOccurrences(of: ".swift", with: "")
            if code.contains(fileName) || code.contains("// \(fileName)") {
                hints.append(code)
            }
        }

        return hints
    }

    private func parseChecklist(from section: String) -> [ChecklistItem] {
        var items: [ChecklistItem] = []

        // Pattern: - [ ] or - [x] followed by description
        let checkPattern = #"- \[([ x])\]\s*(.+)"#
        guard let regex = try? NSRegularExpression(pattern: checkPattern, options: .caseInsensitive) else {
            return items
        }

        let matches = regex.matches(in: section, range: NSRange(section.startIndex..., in: section))

        for match in matches {
            guard let statusRange = Range(match.range(at: 1), in: section),
                  let descRange = Range(match.range(at: 2), in: section)
            else {
                continue
            }

            let completed = String(section[statusRange]).lowercased() == "x"
            let description = String(section[descRange]).trimmingCharacters(in: .whitespaces)

            items.append(ChecklistItem(
                id: UUID(),
                description: description,
                completed: completed,
                verificationMethod: inferVerificationMethod(from: description)
            ))
        }

        return items
    }

    private func inferVerificationMethod(from description: String) -> ChecklistItem.VerificationMethod {
        let lower = description.lowercased()
        if lower.contains("build") || lower.contains("compile") {
            return .buildSucceeds
        } else if lower.contains("test") {
            return .testPasses
        } else if lower.contains("file") && lower.contains("exist") {
            return .fileExists
        } else if lower.contains("screen") || lower.contains("visual") || lower.contains("ocr") {
            return .screenVerification
        }
        return .manualCheck
    }

    private func parseDeliverable(from section: String) -> String? {
        // Pattern: **Deliverable**: `something.dmg` or Deliverable: something
        let pattern = #"\*\*Deliverable\*\*:\s*`?([^`\n]+)`?"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: section, range: NSRange(section.startIndex..., in: section)),
              let range = Range(match.range(at: 1), in: section)
        else {
            return nil
        }
        return String(section[range]).trimmingCharacters(in: .whitespaces)
    }

    private func extractDescription(from section: String) -> String {
        // Get first paragraph after the phase header
        let lines = section.components(separatedBy: "\n")
        var description = ""
        var foundHeader = false

        for line in lines {
            if line.hasPrefix("### Phase") {
                foundHeader = true
                continue
            }
            if foundHeader, !line.isEmpty, !line.hasPrefix("#"), !line.hasPrefix("**"), !line.hasPrefix("-"), !line.hasPrefix("`") {
                description = line.trimmingCharacters(in: .whitespaces)
                break
            }
        }

        return description
    }

    private func parseArchitectureRules(from content: String) -> [String] {
        var rules: [String] = []

        // Find the rules section
        guard let startRange = content.range(of: "### 2.1 Immutable Rules"),
              let codeStart = content.range(of: "```", range: startRange.upperBound ..< content.endIndex),
              let codeEnd = content.range(of: "```", range: codeStart.upperBound ..< content.endIndex)
        else {
            return rules
        }

        let rulesContent = content[codeStart.upperBound ..< codeEnd.lowerBound]

        // Parse numbered rules
        let pattern = #"(\d+)\.\s*([A-Z]+):\s*(.+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return rules
        }

        let matches = regex.matches(in: String(rulesContent), range: NSRange(rulesContent.startIndex..., in: rulesContent))

        for match in matches {
            guard let range = Range(match.range, in: rulesContent) else { continue }
            rules.append(String(rulesContent[range]))
        }

        return rules
    }

    private func parseFileIndex(from content: String) -> [String: FileRequirement.FileStatus] {
        var index: [String: FileRequirement.FileStatus] = [:]

        // Find FILE INDEX section
        guard let startRange = content.range(of: "## §6 FILE INDEX") ?? content.range(of: "## §7 FILE INDEX") else {
            return index
        }

        let section = content[startRange.lowerBound...]

        // Parse table rows: | `path` | STATUS |
        let pattern = #"\|\s*`([^`]+)`\s*\|\s*(✅ EXISTS|🔧 EDIT|🆕 NEW)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return index
        }

        let matches = regex.matches(in: String(section), range: NSRange(section.startIndex..., in: section))

        for match in matches {
            guard let pathRange = Range(match.range(at: 1), in: section),
                  let statusRange = Range(match.range(at: 2), in: section)
            else {
                continue
            }

            let path = String(section[pathRange])
            let statusStr = String(section[statusRange])

            let status: FileRequirement.FileStatus = if statusStr.contains("EXISTS") {
                .exists
            } else if statusStr.contains("EDIT") {
                .edit
            } else {
                .new
            }

            index[path] = status
        }

        return index
    }
}
