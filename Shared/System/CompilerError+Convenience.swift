#if os(macOS)
    import Foundation

    // MARK: - CompilerError Convenience Extensions

    public extension XcodeBuildRunner.CompilerError {
        /// Returns true if this is an error (not a warning or note)
        var isError: Bool {
            errorType == .error
        }

        /// Returns true if this is a warning
        var isWarning: Bool {
            errorType == .warning
        }

        /// Returns true if this is a note
        var isNote: Bool {
            errorType == .note
        }

        /// A compact string representation for display
        var compactDisplayString: String {
            let fileName = (file as NSString).lastPathComponent
            return "\(severityDescription): \(fileName):\(line):\(column) - \(message)"
        }

        /// A human-readable description of the severity
        var severityDescription: String {
            switch errorType {
            case .error:
                "Error"
            case .warning:
                "Warning"
            case .note:
                "Note"
            }
        }
    }

#endif
