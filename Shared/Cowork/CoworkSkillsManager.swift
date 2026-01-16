import Foundation

/// Manages skills (file type creation capabilities) for Cowork
@MainActor
@Observable
final class CoworkSkillsManager {
    static let shared = CoworkSkillsManager()

    var enabledSkills: Set<SkillType> = Set(SkillType.allCases)
    var skillConfigurations: [SkillType: SkillConfiguration] = [:]

    enum SkillType: String, CaseIterable, Codable, Identifiable {
        case document = "Document"
        case spreadsheet = "Spreadsheet"
        case presentation = "Presentation"
        case pdf = "PDF"
        case image = "Image"
        case code = "Code"
        case fileOrganization = "File Organization"
        case webScraping = "Web Scraping"
        case dataTransformation = "Data Transformation"
        case archive = "Archive"
        case terminal = "Terminal"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .document: return "doc.fill"
            case .spreadsheet: return "tablecells.fill"
            case .presentation: return "play.rectangle.fill"
            case .pdf: return "doc.richtext.fill"
            case .image: return "photo.fill"
            case .code: return "chevron.left.forwardslash.chevron.right"
            case .fileOrganization: return "folder.fill"
            case .webScraping: return "globe"
            case .dataTransformation: return "arrow.triangle.2.circlepath"
            case .archive: return "archivebox.fill"
            case .terminal: return "terminal.fill"
            }
        }

        var description: String {
            switch self {
            case .document:
                return "Create and edit Word documents (.docx)"
            case .spreadsheet:
                return "Create and edit Excel spreadsheets (.xlsx)"
            case .presentation:
                return "Create and edit PowerPoint presentations (.pptx)"
            case .pdf:
                return "Create and manipulate PDF documents"
            case .image:
                return "Process, resize, and convert images"
            case .code:
                return "Generate source code in various languages"
            case .fileOrganization:
                return "Sort, rename, and organize files"
            case .webScraping:
                return "Extract data from web pages"
            case .dataTransformation:
                return "Convert between data formats (CSV, JSON, XML)"
            case .archive:
                return "Create and extract archives (ZIP, TAR)"
            case .terminal:
                return "Execute system commands via Terminal"
            }
        }

        var supportedExtensions: [String] {
            switch self {
            case .document: return ["doc", "docx", "rtf", "txt", "md"]
            case .spreadsheet: return ["xls", "xlsx", "csv", "tsv"]
            case .presentation: return ["ppt", "pptx"]
            case .pdf: return ["pdf"]
            case .image: return ["jpg", "jpeg", "png", "gif", "webp", "svg", "heic"]
            case .code: return ["swift", "py", "js", "ts", "java", "cpp", "c", "go", "rs", "rb", "php", "html", "css"]
            case .fileOrganization: return []
            case .webScraping: return ["html", "json"]
            case .dataTransformation: return ["csv", "json", "xml", "yaml", "plist"]
            case .archive: return ["zip", "tar", "gz", "7z"]
            case .terminal: return []
            }
        }
    }

    struct SkillConfiguration: Codable {
        var isEnabled: Bool = true
        var customSettings: [String: String] = [:]
    }

    private init() {
        loadConfiguration()
    }

    // MARK: - Skill Management

    func isEnabled(_ skill: SkillType) -> Bool {
        enabledSkills.contains(skill)
    }

    func enable(_ skill: SkillType) {
        enabledSkills.insert(skill)
        saveConfiguration()
    }

    func disable(_ skill: SkillType) {
        enabledSkills.remove(skill)
        saveConfiguration()
    }

    func toggle(_ skill: SkillType) {
        if isEnabled(skill) {
            disable(skill)
        } else {
            enable(skill)
        }
    }

    // MARK: - Skill Execution

    func canHandle(extension ext: String) -> SkillType? {
        let lowercased = ext.lowercased()
        for skill in enabledSkills {
            if skill.supportedExtensions.contains(lowercased) {
                return skill
            }
        }
        return nil
    }

    func canHandle(url: URL) -> SkillType? {
        canHandle(extension: url.pathExtension)
    }

    /// Get all skills that can handle a specific file type
    func skillsForExtension(_ ext: String) -> [SkillType] {
        let lowercased = ext.lowercased()
        return enabledSkills.filter { skill in
            skill.supportedExtensions.contains(lowercased)
        }
    }

    // MARK: - Skill Actions

    /// Create a new document using a skill
    func createDocument(
        skill: SkillType,
        name: String,
        at directory: URL,
        content: String? = nil
    ) async throws -> URL {
        guard isEnabled(skill) else {
            throw SkillError.skillDisabled(skill)
        }

        let ext = skill.supportedExtensions.first ?? "txt"
        let url = directory.appendingPathComponent("\(name).\(ext)")

        switch skill {
        case .document:
            return try await createTextDocument(at: url, content: content)
        case .spreadsheet:
            return try await createSpreadsheet(at: url, content: content)
        case .code:
            return try await createCodeFile(at: url, content: content)
        case .dataTransformation:
            return try await createDataFile(at: url, content: content)
        default:
            throw SkillError.unsupportedOperation("Create not supported for \(skill.rawValue)")
        }
    }

    // MARK: - Private Skill Implementations

    private func createTextDocument(at url: URL, content: String?) async throws -> URL {
        let text = content ?? ""
        try text.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func createSpreadsheet(at url: URL, content: String?) async throws -> URL {
        // Create a basic CSV file
        let csv = content ?? "Column1,Column2,Column3\n"
        try csv.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func createCodeFile(at url: URL, content: String?) async throws -> URL {
        let code = content ?? "// Generated by Thea Cowork\n"
        try code.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func createDataFile(at url: URL, content: String?) async throws -> URL {
        let data = content ?? "{}"
        try data.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    // MARK: - File Organization Skills

    func organizeFiles(
        in directory: URL,
        strategy: OrganizationStrategy
    ) async throws -> OrganizationResult {
        guard isEnabled(.fileOrganization) else {
            throw SkillError.skillDisabled(.fileOrganization)
        }

        let fileManager = FileManager.default
        let fileOps = FileOperationsManager()

        var result = OrganizationResult()

        let files = try fileOps.listDirectory(at: directory)

        for file in files where !file.hasDirectoryPath {
            let destination: URL

            switch strategy {
            case .byType:
                let type = CoworkArtifact.ArtifactType.from(url: file)
                let subdir = directory.appendingPathComponent(type.rawValue)
                if !fileManager.fileExists(atPath: subdir.path) {
                    try fileOps.createDirectory(at: subdir)
                    result.createdDirectories.append(subdir)
                }
                destination = subdir.appendingPathComponent(file.lastPathComponent)

            case .byDate:
                let attrs = try fileOps.getFileAttributes(at: file)
                let date = attrs.modifiedAt ?? Date()
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM"
                let subdir = directory.appendingPathComponent(formatter.string(from: date))
                if !fileManager.fileExists(atPath: subdir.path) {
                    try fileOps.createDirectory(at: subdir)
                    result.createdDirectories.append(subdir)
                }
                destination = subdir.appendingPathComponent(file.lastPathComponent)

            case .byExtension:
                let ext = file.pathExtension.lowercased()
                let subdir = directory.appendingPathComponent(ext.isEmpty ? "no-extension" : ext)
                if !fileManager.fileExists(atPath: subdir.path) {
                    try fileOps.createDirectory(at: subdir)
                    result.createdDirectories.append(subdir)
                }
                destination = subdir.appendingPathComponent(file.lastPathComponent)

            case .flatten:
                // Already at root level
                continue
            }

            if file != destination {
                try fileOps.moveFile(from: file, to: destination)
                result.movedFiles.append((from: file, to: destination))
            }
        }

        return result
    }

    enum OrganizationStrategy: String, CaseIterable {
        case byType = "By Type"
        case byDate = "By Date"
        case byExtension = "By Extension"
        case flatten = "Flatten"
    }

    struct OrganizationResult {
        var movedFiles: [(from: URL, to: URL)] = []
        var createdDirectories: [URL] = []

        var movedCount: Int { movedFiles.count }
        var createdCount: Int { createdDirectories.count }
    }

    // MARK: - Archive Skills

    func createArchive(
        from files: [URL],
        to destination: URL,
        format: ArchiveFormat = .zip
    ) async throws -> URL {
        guard isEnabled(.archive) else {
            throw SkillError.skillDisabled(.archive)
        }

        // Use Process to create archive
        let process = Process()

        switch format {
        case .zip:
            process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
            process.arguments = ["-r", destination.path] + files.map(\.path)
        case .tar:
            process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
            process.arguments = ["-cvf", destination.path] + files.map(\.path)
        case .tarGz:
            process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
            process.arguments = ["-czvf", destination.path] + files.map(\.path)
        }

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw SkillError.operationFailed("Archive creation failed")
        }

        return destination
    }

    func extractArchive(
        from archive: URL,
        to destination: URL
    ) async throws {
        guard isEnabled(.archive) else {
            throw SkillError.skillDisabled(.archive)
        }

        let process = Process()
        let ext = archive.pathExtension.lowercased()

        switch ext {
        case "zip":
            process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
            process.arguments = [archive.path, "-d", destination.path]
        case "tar":
            process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
            process.arguments = ["-xvf", archive.path, "-C", destination.path]
        case "gz", "tgz":
            process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
            process.arguments = ["-xzvf", archive.path, "-C", destination.path]
        default:
            throw SkillError.unsupportedOperation("Unknown archive format: \(ext)")
        }

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw SkillError.operationFailed("Archive extraction failed")
        }
    }

    enum ArchiveFormat: String, CaseIterable {
        case zip = "ZIP"
        case tar = "TAR"
        case tarGz = "TAR.GZ"
    }

    // MARK: - Persistence

    private func saveConfiguration() {
        let enabledRaw = enabledSkills.map(\.rawValue)
        UserDefaults.standard.set(enabledRaw, forKey: "cowork.enabledSkills")

        if let data = try? JSONEncoder().encode(skillConfigurations) {
            UserDefaults.standard.set(data, forKey: "cowork.skillConfigurations")
        }
    }

    private func loadConfiguration() {
        if let enabledRaw = UserDefaults.standard.stringArray(forKey: "cowork.enabledSkills") {
            enabledSkills = Set(enabledRaw.compactMap { SkillType(rawValue: $0) })
        }

        if let data = UserDefaults.standard.data(forKey: "cowork.skillConfigurations"),
           let configs = try? JSONDecoder().decode([SkillType: SkillConfiguration].self, from: data) {
            skillConfigurations = configs
        }
    }

    // MARK: - Errors

    enum SkillError: LocalizedError {
        case skillDisabled(SkillType)
        case unsupportedOperation(String)
        case operationFailed(String)

        var errorDescription: String? {
            switch self {
            case .skillDisabled(let skill):
                return "\(skill.rawValue) skill is disabled"
            case .unsupportedOperation(let message):
                return "Unsupported operation: \(message)"
            case .operationFailed(let message):
                return "Operation failed: \(message)"
            }
        }
    }
}
