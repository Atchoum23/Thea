import Foundation

extension XcodeBuildRunner.CompilerError {
    public var isError: Bool { errorType == .error }
    public var isWarning: Bool { errorType == .warning }
    public var isNote: Bool { errorType == .note }

    public var severityDescription: String {
        switch errorType {
        case .error: return "error"
        case .warning: return "warning"
        case .note: return "note"
        }
    }

    public var fileURL: URL? {
        URL(fileURLWithPath: file)
    }

    public var locationDescription: String {
        "\(file):\(line):\(column)"
    }

    // Display formatting
    public var compactDisplayString: String {
        "[\(severityDescription)] \(locationDescription) — \(message)"
    }

    public var detailedDisplayString: String {
        "\(locationDescription) [\(severityDescription)] — \(message)"
    }
}

public extension Sequence where Element == XcodeBuildRunner.CompilerError {
    var errorsOnly: [XcodeBuildRunner.CompilerError] { filter { $0.isError } }
    var warningsOnly: [XcodeBuildRunner.CompilerError] { filter { $0.isWarning } }
    var notesOnly: [XcodeBuildRunner.CompilerError] { filter { $0.isNote } }

    func groupedByFile() -> [String: [XcodeBuildRunner.CompilerError]] {
        Dictionary(grouping: self, by: { $0.file })
    }

    func sortedByLocation() -> [XcodeBuildRunner.CompilerError] {
        self.sorted { lhs, rhs in
            if lhs.file != rhs.file { return lhs.file < rhs.file }
            if lhs.line != rhs.line { return lhs.line < rhs.line }
            if lhs.column != rhs.column { return lhs.column < rhs.column }
            return lhs.message < rhs.message
        }
    }
    func deduplicated() -> [XcodeBuildRunner.CompilerError] {
        var seen: Set<String> = []
        var result: [XcodeBuildRunner.CompilerError] = []
        for e in self {
            let key = "\(e.file)|\(e.line)|\(e.column)|\(e.message)|\(e.errorType.rawValue)"
            if !seen.contains(key) {
                seen.insert(key)
                result.append(e)
            }
        }
        return result
    }
}

public extension Array where Element == XcodeBuildRunner.CompilerError {
    var errorsOnly: [XcodeBuildRunner.CompilerError] { (self as any Sequence).errorsOnly }
    var warningsOnly: [XcodeBuildRunner.CompilerError] { (self as any Sequence).warningsOnly }
    var notesOnly: [XcodeBuildRunner.CompilerError] { (self as any Sequence).notesOnly }
    func sortedByLocation() -> [XcodeBuildRunner.CompilerError] { (self as any Sequence).sortedByLocation() }
}

