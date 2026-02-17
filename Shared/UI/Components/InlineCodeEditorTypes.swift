// InlineCodeEditorTypes.swift
// Supporting types and views for InlineCodeEditor

import Foundation
import SwiftUI

// MARK: - Code Edit Types

/// Types of inline code edits
public enum CodeEditType: String, Sendable, CaseIterable {
    case refactor       // Improve code structure
    case fix            // Fix bugs/issues
    case optimize       // Performance optimization
    case document       // Add documentation
    case test           // Generate tests
    case simplify       // Reduce complexity
    case modernize      // Update to modern patterns
    case custom         // Custom instruction

    var displayName: String {
        switch self {
        case .refactor: return "Refactor"
        case .fix: return "Fix"
        case .optimize: return "Optimize"
        case .document: return "Document"
        case .test: return "Add Tests"
        case .simplify: return "Simplify"
        case .modernize: return "Modernize"
        case .custom: return "Custom"
        }
    }

    var icon: String {
        switch self {
        case .refactor: return "arrow.triangle.2.circlepath"
        case .fix: return "wrench.and.screwdriver"
        case .optimize: return "gauge.with.needle.fill"
        case .document: return "doc.text"
        case .test: return "checkmark.seal"
        case .simplify: return "scissors"
        case .modernize: return "sparkles"
        case .custom: return "pencil"
        }
    }

    var color: Color {
        switch self {
        case .refactor: return .blue
        case .fix: return .red
        case .optimize: return .orange
        case .document: return .green
        case .test: return .purple
        case .simplify: return .teal
        case .modernize: return .pink
        case .custom: return .secondary
        }
    }

    var defaultPrompt: String {
        switch self {
        case .refactor: return "Refactor this code to improve structure and readability"
        case .fix: return "Fix any bugs or issues in this code"
        case .optimize: return "Optimize this code for better performance"
        case .document: return "Add comprehensive documentation to this code"
        case .test: return "Generate unit tests for this code"
        case .simplify: return "Simplify this code while maintaining functionality"
        case .modernize: return "Update this code to use modern patterns and syntax"
        case .custom: return ""
        }
    }
}

// MARK: - Code Block

/// Represents a code block that can be edited
public struct EditableCodeBlock: Identifiable, Sendable {
    public let id: UUID
    public var code: String
    public var language: String?
    public var lineRange: Range<Int>?
    public var isEditing: Bool = false
    public var editHistory: [CodeEditVersion]
    public let originalCode: String

    /// A snapshot version of an inline code edit, recording the code state, edit type, and timestamp.
    public struct CodeEditVersion: Identifiable, Sendable {
        public let id: UUID
        public let code: String
        public let editType: CodeEditType
        public let prompt: String?
        public let timestamp: Date

        public init(
            id: UUID = UUID(),
            code: String,
            editType: CodeEditType,
            prompt: String? = nil
        ) {
            self.id = id
            self.code = code
            self.editType = editType
            self.prompt = prompt
            self.timestamp = Date()
        }
    }

    public init(
        id: UUID = UUID(),
        code: String,
        language: String? = nil,
        lineRange: Range<Int>? = nil
    ) {
        self.id = id
        self.code = code
        self.language = language
        self.lineRange = lineRange
        self.originalCode = code
        self.editHistory = []
    }

    public var hasChanges: Bool {
        code != originalCode
    }

    public var canUndo: Bool {
        !editHistory.isEmpty
    }

    public mutating func applyEdit(newCode: String, type: CodeEditType, prompt: String? = nil) {
        editHistory.append(CodeEditVersion(
            code: code,
            editType: type,
            prompt: prompt
        ))
        code = newCode
    }

    public mutating func undo() {
        guard let lastVersion = editHistory.popLast() else { return }
        code = lastVersion.code
    }

    public mutating func revert() {
        code = originalCode
        editHistory.removeAll()
    }
}

// MARK: - Inline Code Edit Request

/// A request to edit code inline
public struct InlineCodeEditRequest: Sendable {
    public let codeBlock: EditableCodeBlock
    public let editType: CodeEditType
    public let customPrompt: String?
    public let selectionRange: Range<String.Index>?

    public init(
        codeBlock: EditableCodeBlock,
        editType: CodeEditType,
        customPrompt: String? = nil,
        selectionRange: Range<String.Index>? = nil
    ) {
        self.codeBlock = codeBlock
        self.editType = editType
        self.customPrompt = customPrompt
        self.selectionRange = selectionRange
    }

    public var effectivePrompt: String {
        customPrompt ?? editType.defaultPrompt
    }
}

// MARK: - Errors

/// Errors that can occur during inline code editing operations.
public enum InlineEditError: LocalizedError {
    case noHandler
    case editFailed(String)

    public var errorDescription: String? {
        switch self {
        case .noHandler:
            return "No edit handler configured"
        case .editFailed(let message):
            return "Edit failed: \(message)"
        }
    }
}

// MARK: - Diff View

/// Shows a diff between original and modified code
struct DiffView: View {
    let original: String
    let modified: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(computeDiff().enumerated()), id: \.offset) { _, line in
                DiffLine(line: line)
            }
        }
        .font(.system(.body, design: .monospaced))
    }

    private func computeDiff() -> [DiffLineContent] {
        let originalLines = original.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let modifiedLines = modified.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        var result: [DiffLineContent] = []
        let maxLines = max(originalLines.count, modifiedLines.count)

        for i in 0..<maxLines {
            let origLine = i < originalLines.count ? originalLines[i] : nil
            let modLine = i < modifiedLines.count ? modifiedLines[i] : nil

            if origLine == modLine {
                if let line = origLine {
                    result.append(DiffLineContent(type: .unchanged, content: line))
                }
            } else {
                if let line = origLine, modLine == nil || !modifiedLines.contains(line) {
                    result.append(DiffLineContent(type: .removed, content: line))
                }
                if let line = modLine, origLine == nil || !originalLines.contains(line) {
                    result.append(DiffLineContent(type: .added, content: line))
                }
            }
        }

        return result
    }
}

struct DiffLineContent {
    enum DiffType {
        case unchanged, added, removed
    }

    let type: DiffType
    let content: String
}

struct DiffLine: View {
    let line: DiffLineContent

    var body: some View {
        HStack(spacing: 8) {
            Text(indicator)
                .font(.system(.caption, design: .monospaced))
                .frame(width: 16)
                .foregroundStyle(indicatorColor)

            Text(line.content)
                .foregroundStyle(contentColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .background(backgroundColor)
    }

    private var indicator: String {
        switch line.type {
        case .unchanged: return " "
        case .added: return "+"
        case .removed: return "-"
        }
    }

    private var indicatorColor: Color {
        switch line.type {
        case .unchanged: return .secondary
        case .added: return .green
        case .removed: return .red
        }
    }

    private var contentColor: Color {
        switch line.type {
        case .unchanged: return .primary
        case .added: return .green
        case .removed: return .red
        }
    }

    private var backgroundColor: Color {
        switch line.type {
        case .unchanged: return .clear
        case .added: return .green.opacity(0.1)
        case .removed: return .red.opacity(0.1)
        }
    }
}

// MARK: - Code Block View

/// Displays a code block with syntax highlighting placeholder
struct InlineCodeBlockView: View {
    let code: String
    let language: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let language {
                HStack {
                    Text(language)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        #if os(macOS)
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(code, forType: .string)
                        #else
                        UIPasteboard.general.string = code
                        #endif
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Copy code")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.secondary.opacity(0.1))
            }

            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(12)
            }
        }
        .background(Color.secondary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
