#if os(macOS)
import Foundation

// MARK: - CompilerError Convenience Extensions

extension XcodeBuildRunner.CompilerError {
    /// Returns true if this is an error (not a warning or note)
    public var isError: Bool {
        errorType == .error
    }
    
    /// Returns true if this is a warning
    public var isWarning: Bool {
        errorType == .warning
    }
    
    /// Returns true if this is a note
    public var isNote: Bool {
        errorType == .note
    }
    
    /// A compact string representation for display
    public var compactDisplayString: String {
        let fileName = (file as NSString).lastPathComponent
        return "\(severityDescription): \(fileName):\(line):\(column) - \(message)"
    }
    
    /// A human-readable description of the severity
    public var severityDescription: String {
        switch errorType {
        case .error:
            return "Error"
        case .warning:
            return "Warning"
        case .note:
            return "Note"
        }
    }
}

#endif
