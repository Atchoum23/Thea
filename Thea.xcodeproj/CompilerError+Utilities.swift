import Foundation

// This file contains additional utility methods for CompilerError
// Note: Basic utilities like isError, compactDisplayString, deduplicated, and sortedByLocation
// are defined in CompilerError+Convenience.swift

public extension Sequence where Element == XcodeBuildRunner.CompilerError {
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
