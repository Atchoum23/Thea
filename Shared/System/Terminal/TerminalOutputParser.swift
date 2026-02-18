#if os(macOS)
    import Foundation
    import OSLog
    import SwiftUI

    /// Parser for terminal output including ANSI codes and structured data
    enum TerminalOutputParser {
        private static let logger = Logger(subsystem: "ai.thea.app", category: "TerminalOutputParser")

        // MARK: - ANSI Color Parsing

        /// Parse ANSI escape codes and return attributed string segments
        static func parseANSI(_ text: String) -> [ANSISegment] {
            var segments: [ANSISegment] = []
            var currentStyle = ANSIStyle()
            _ = ""

            let pattern = "\u{001B}\\[([0-9;]*)m"
            let regex: NSRegularExpression
            do {
                regex = try NSRegularExpression(pattern: pattern, options: [])
            } catch {
                logger.error("Failed to compile ANSI regex: \(error)")
                return [ANSISegment(text: text, style: currentStyle)]
            }

            var lastEnd = text.startIndex
            let nsRange = NSRange(text.startIndex..., in: text)

            regex.enumerateMatches(in: text, options: [], range: nsRange) { match, _, _ in
                guard let match,
                      let range = Range(match.range, in: text),
                      let codeRange = Range(match.range(at: 1), in: text) else { return }

                // Add text before this match
                let textBefore = String(text[lastEnd ..< range.lowerBound])
                if !textBefore.isEmpty {
                    segments.append(ANSISegment(text: textBefore, style: currentStyle))
                }

                // Parse the ANSI codes
                let codes = String(text[codeRange]).split(separator: ";").compactMap { Int($0) }
                currentStyle = currentStyle.applying(codes: codes)

                lastEnd = range.upperBound
            }

            // Add remaining text
            let remaining = String(text[lastEnd...])
            if !remaining.isEmpty {
                segments.append(ANSISegment(text: remaining, style: currentStyle))
            }

            return segments.isEmpty ? [ANSISegment(text: text, style: ANSIStyle())] : segments
        }

        /// Strip all ANSI codes from text
        static func stripANSI(_ text: String) -> String {
            let pattern = "\u{001B}\\[[0-9;]*m"
            let regex: NSRegularExpression
            do {
                regex = try NSRegularExpression(pattern: pattern, options: [])
            } catch {
                logger.error("Failed to compile ANSI regex: \(error)")
                return text
            }
            let range = NSRange(text.startIndex..., in: text)
            return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "")
        }

        // MARK: - Structured Output Parsing

        /// Detect if output is JSON
        static func isJSON(_ text: String) -> Bool {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return (trimmed.hasPrefix("{") && trimmed.hasSuffix("}")) ||
                (trimmed.hasPrefix("[") && trimmed.hasSuffix("]"))
        }

        /// Parse JSON output
        static func parseJSON(_ text: String) -> Any? {
            guard let data = text.data(using: .utf8) else { return nil }
            do {
                return try JSONSerialization.jsonObject(with: data, options: [])
            } catch {
                logger.error("Failed to parse JSON: \(error)")
                return nil
            }
        }

        /// Detect if output looks like a table (columns aligned with spaces)
        static func isTable(_ text: String) -> Bool {
            let lines = text.components(separatedBy: .newlines).filter { !$0.isEmpty }
            guard lines.count >= 2 else { return false }

            // Check if lines have similar column structure
            let firstLineColumns = lines[0].split(separator: " ", omittingEmptySubsequences: true).count
            guard firstLineColumns >= 2 else { return false }

            let similarStructure = lines.prefix(5).allSatisfy { line in
                let cols = line.split(separator: " ", omittingEmptySubsequences: true).count
                return abs(cols - firstLineColumns) <= 2
            }

            return similarStructure
        }

        /// Parse common error patterns
        static func parseErrors(_ text: String) -> [TerminalErrorInfo] {
            var errors: [TerminalErrorInfo] = []

            // Common error patterns
            let patterns: [(pattern: String, type: ErrorType)] = [
                ("error:", .error),
                ("Error:", .error),
                ("ERROR:", .error),
                ("fatal:", .fatal),
                ("Fatal:", .fatal),
                ("FATAL:", .fatal),
                ("warning:", .warning),
                ("Warning:", .warning),
                ("WARNING:", .warning),
                ("command not found", .commandNotFound),
                ("Permission denied", .permissionDenied),
                ("No such file or directory", .fileNotFound),
                ("Connection refused", .connectionError),
                ("Operation timed out", .timeout)
            ]

            for line in text.components(separatedBy: .newlines) {
                for (pattern, type) in patterns where line.localizedCaseInsensitiveContains(pattern) {
                    errors.append(TerminalErrorInfo(line: line, type: type))
                    break
                }
            }

            return errors
        }

        /// Redact sensitive information from output
        static func redactSensitive(_ text: String) -> String {
            var result = text

            // Patterns to redact
            let redactionPatterns: [(pattern: String, replacement: String)] = [
                // API keys and tokens
                ("sk-[a-zA-Z0-9]{20,}", "[REDACTED_API_KEY]"),
                ("api[_-]?key[\"']?\\s*[:=]\\s*[\"']?[a-zA-Z0-9\\-_]{20,}", "api_key=[REDACTED]"),
                // Passwords
                ("password[\"']?\\s*[:=]\\s*[\"']?[^\\s\"']+", "password=[REDACTED]"),
                // AWS credentials
                ("AKIA[0-9A-Z]{16}", "[REDACTED_AWS_KEY]"),
                // Private keys
                ("-----BEGIN.*PRIVATE KEY-----[\\s\\S]*?-----END.*PRIVATE KEY-----", "[REDACTED_PRIVATE_KEY]"),
                // Bearer tokens
                ("Bearer\\s+[a-zA-Z0-9\\-_\\.]+", "Bearer [REDACTED]"),
                // Basic auth
                ("Basic\\s+[a-zA-Z0-9+/=]+", "Basic [REDACTED]")
            ]

            for (pattern, replacement) in redactionPatterns {
                do {
                    let regex = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
                    let range = NSRange(result.startIndex..., in: result)
                    result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: replacement)
                } catch {
                    logger.error("Failed to compile redaction regex '\(pattern)': \(error)")
                }
            }

            return result
        }
    }

    // MARK: - Supporting Types

    struct ANSISegment: Identifiable {
        let id = UUID()
        let text: String
        let style: ANSIStyle
    }

    struct ANSIStyle {
        var foregroundColor: Color?
        var backgroundColor: Color?
        var isBold: Bool = false
        var isDim: Bool = false
        var isItalic: Bool = false
        var isUnderline: Bool = false
        var isStrikethrough: Bool = false

        func applying(codes: [Int]) -> ANSIStyle {
            var newStyle = self

            for code in codes {
                switch code {
                case 0: // Reset
                    newStyle = ANSIStyle()
                case 1: // Bold
                    newStyle.isBold = true
                case 2: // Dim
                    newStyle.isDim = true
                case 3: // Italic
                    newStyle.isItalic = true
                case 4: // Underline
                    newStyle.isUnderline = true
                case 9: // Strikethrough
                    newStyle.isStrikethrough = true
                case 22: // Normal intensity
                    newStyle.isBold = false
                    newStyle.isDim = false
                case 23: // Not italic
                    newStyle.isItalic = false
                case 24: // Not underline
                    newStyle.isUnderline = false
                case 29: // Not strikethrough
                    newStyle.isStrikethrough = false
                // Foreground colors (30-37, 90-97)
                case 30: newStyle.foregroundColor = .black
                case 31: newStyle.foregroundColor = .red
                case 32: newStyle.foregroundColor = .green
                case 33: newStyle.foregroundColor = .yellow
                case 34: newStyle.foregroundColor = .blue
                case 35: newStyle.foregroundColor = .purple
                case 36: newStyle.foregroundColor = .cyan
                case 37: newStyle.foregroundColor = .white
                case 39: newStyle.foregroundColor = nil // Default
                // Bright foreground colors
                case 90: newStyle.foregroundColor = Color(.systemGray)
                case 91: newStyle.foregroundColor = Color(.systemRed)
                case 92: newStyle.foregroundColor = Color(.systemGreen)
                case 93: newStyle.foregroundColor = Color(.systemYellow)
                case 94: newStyle.foregroundColor = Color(.systemBlue)
                case 95: newStyle.foregroundColor = Color(.systemPurple)
                case 96: newStyle.foregroundColor = Color(.systemCyan)
                case 97: newStyle.foregroundColor = .white
                // Background colors (40-47, 100-107)
                case 40: newStyle.backgroundColor = .black
                case 41: newStyle.backgroundColor = .red
                case 42: newStyle.backgroundColor = .green
                case 43: newStyle.backgroundColor = .yellow
                case 44: newStyle.backgroundColor = .blue
                case 45: newStyle.backgroundColor = .purple
                case 46: newStyle.backgroundColor = .cyan
                case 47: newStyle.backgroundColor = .white
                case 49: newStyle.backgroundColor = nil // Default
                default: break
                }
            }

            return newStyle
        }
    }

    struct TerminalErrorInfo: Identifiable {
        let id = UUID()
        let line: String
        let type: ErrorType
    }

    enum ErrorType {
        case error
        case fatal
        case warning
        case commandNotFound
        case permissionDenied
        case fileNotFound
        case connectionError
        case timeout

        var color: Color {
            switch self {
            case .error, .fatal, .permissionDenied:
                .red
            case .warning:
                .orange
            case .commandNotFound, .fileNotFound:
                .yellow
            case .connectionError, .timeout:
                .purple
            }
        }

        var icon: String {
            switch self {
            case .error, .fatal:
                "xmark.circle.fill"
            case .warning:
                "exclamationmark.triangle.fill"
            case .commandNotFound, .fileNotFound:
                "questionmark.circle.fill"
            case .permissionDenied:
                "lock.fill"
            case .connectionError:
                "wifi.slash"
            case .timeout:
                "clock.badge.exclamationmark"
            }
        }
    }

#endif
