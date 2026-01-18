import Foundation

internal extension XcodeBuildRunner.CompilerError {
    var isError: Bool { errorType == .error }

    var severityDescription: String {
        switch errorType {
        case .error: return "error"
        case .warning: return "warning"
        case .note: return "note"
        }
    }

    var compactDisplayString: String {
        "[\(severityDescription)] \(file):\(line):\(column) — \(message)"
    }
}

internal extension Sequence where Element == XcodeBuildRunner.CompilerError {
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

    func sortedByLocation() -> [XcodeBuildRunner.CompilerError] {
        return self.sorted { (lhs, rhs) in
            if lhs.file != rhs.file { return lhs.file < rhs.file }
            if lhs.line != rhs.line { return lhs.line < rhs.line }
            return lhs.column < rhs.column
        }
    }

    func sortedByPriorityThenLocation() -> [XcodeBuildRunner.CompilerError] {
        func priority(_ e: XcodeBuildRunner.CompilerError) -> Int {
            switch e.errorType {
            case .error: return 0
            case .warning: return 1
            case .note: return 2
            }
        }
        return self.sorted { (lhs, rhs) in
            let lp = priority(lhs), rp = priority(rhs)
            if lp != rp { return lp < rp }
            if lhs.file != rhs.file { return lhs.file < rhs.file }
            if lhs.line != rhs.line { return lhs.line < rhs.line }
            return lhs.column < rhs.column
        }
    }
}
