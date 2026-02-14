//
//  InlineCodeEditor.swift
//  Thea
//
//  Inline Code Editing - allows editing code directly within chat messages
//  without regenerating the entire response.
//
//  Based on 2026 AI code assistant best practices.
//
//  Copyright 2026. All rights reserved.
//

import Foundation
import SwiftUI
import os.log

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
        // Save current version to history
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

// MARK: - Inline Code Editor Controller

/// Manages inline code editing state and operations
@MainActor
public final class InlineCodeEditorController: ObservableObject {
    public static let shared = InlineCodeEditorController()

    private let logger = Logger(subsystem: "ai.thea.app", category: "InlineCodeEditor")

    // MARK: - Published State

    @Published public var activeBlock: EditableCodeBlock?
    @Published public var isProcessing: Bool = false
    @Published public var showEditMenu: Bool = false
    @Published public var selectedEditType: CodeEditType = .refactor
    @Published public var customPrompt: String = ""
    @Published public var showDiff: Bool = true

    // MARK: - Callbacks

    /// Called to request an AI edit
    public var onRequestEdit: ((InlineCodeEditRequest) async throws -> String)?

    // MARK: - Initialization

    private init() {
        logger.info("InlineCodeEditorController initialized")
    }

    // MARK: - Public API

    /// Start editing a code block
    public func startEditing(code: String, language: String?) {
        activeBlock = EditableCodeBlock(code: code, language: language)
        activeBlock?.isEditing = true
        showEditMenu = true
        logger.info("Started editing code block")
    }

    /// Apply an edit to the active block
    public func applyEdit(type: CodeEditType, prompt: String? = nil) async throws {
        guard var block = activeBlock else { return }

        isProcessing = true
        defer { isProcessing = false }

        let request = InlineCodeEditRequest(
            codeBlock: block,
            editType: type,
            customPrompt: prompt
        )

        guard let onRequestEdit else {
            throw InlineEditError.noHandler
        }

        let newCode = try await onRequestEdit(request)
        block.applyEdit(newCode: newCode, type: type, prompt: prompt)
        activeBlock = block

        logger.info("Applied \(type.rawValue) edit")
    }

    /// Undo the last edit
    public func undo() {
        activeBlock?.undo()
    }

    /// Revert to original code
    public func revert() {
        activeBlock?.revert()
    }

    /// Accept changes and close editor
    public func acceptChanges() -> String? {
        let code = activeBlock?.code
        activeBlock = nil
        showEditMenu = false
        return code
    }

    /// Cancel editing and discard changes
    public func cancelEditing() {
        activeBlock = nil
        showEditMenu = false
        customPrompt = ""
    }
}

// MARK: - Errors

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

// MARK: - Inline Code Editor View

/// Main view for inline code editing
public struct InlineCodeEditorView: View {
    @ObservedObject var controller = InlineCodeEditorController.shared
    @Environment(\.colorScheme) private var colorScheme

    public init() {}

    public var body: some View {
        if let block = controller.activeBlock, block.isEditing {
            VStack(spacing: 0) {
                // Toolbar
                editorToolbar

                Divider()

                // Code content
                ScrollView {
                    if controller.showDiff && block.hasChanges {
                        DiffView(original: block.originalCode, modified: block.code)
                            .padding()
                    } else {
                        InlineCodeBlockView(code: block.code, language: block.language)
                            .padding()
                    }
                }

                Divider()

                // Edit actions
                editActionsBar
            }
            .background(editorBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
        }
    }

    private var editorToolbar: some View {
        HStack(spacing: 12) {
            // Language indicator
            if let language = controller.activeBlock?.language {
                Label(language, systemImage: "chevron.left.forwardslash.chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(Capsule())
            }

            Spacer()

            // Diff toggle
            Toggle(isOn: $controller.showDiff) {
                Label("Show Diff", systemImage: "arrow.left.arrow.right")
            }
            .toggleStyle(.button)
            .disabled(!(controller.activeBlock?.hasChanges ?? false))

            // Undo
            Button {
                controller.undo()
            } label: {
                Image(systemName: "arrow.uturn.backward")
            }
            .disabled(!(controller.activeBlock?.canUndo ?? false))
            .accessibilityLabel("Undo")

            // Revert
            Button {
                controller.revert()
            } label: {
                Image(systemName: "arrow.counterclockwise")
            }
            .disabled(!(controller.activeBlock?.hasChanges ?? false))
            .accessibilityLabel("Revert changes")

            // Close
            Button {
                controller.cancelEditing()
            } label: {
                Image(systemName: "xmark")
            }
            .accessibilityLabel("Close editor")
        }
        .padding(12)
    }

    private var editActionsBar: some View {
        VStack(spacing: 12) {
            // Quick edit buttons
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(CodeEditType.allCases.filter { $0 != .custom }, id: \.self) { type in
                        QuickEditButton(type: type) {
                            Task {
                                try? await controller.applyEdit(type: type)
                            }
                        }
                        .disabled(controller.isProcessing)
                    }
                }
                .padding(.horizontal)
            }

            // Custom prompt input
            HStack(spacing: 8) {
                TextField("Custom instruction...", text: $controller.customPrompt)
                    .textFieldStyle(.roundedBorder)

                Button {
                    Task {
                        try? await controller.applyEdit(
                            type: .custom,
                            prompt: controller.customPrompt
                        )
                        controller.customPrompt = ""
                    }
                } label: {
                    Image(systemName: "paperplane.fill")
                }
                .disabled(controller.customPrompt.isEmpty || controller.isProcessing)
                .accessibilityLabel("Apply custom edit")
            }
            .padding(.horizontal)

            // Processing indicator
            if controller.isProcessing {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Applying edit...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Accept/Cancel buttons
            HStack(spacing: 12) {
                Button("Cancel") {
                    controller.cancelEditing()
                }
                .buttonStyle(.bordered)

                Button("Accept Changes") {
                    _ = controller.acceptChanges()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!(controller.activeBlock?.hasChanges ?? false))
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .padding(.top, 12)
    }

    private var editorBackground: some ShapeStyle {
        colorScheme == .dark
            ? AnyShapeStyle(Color(white: 0.1))
            : AnyShapeStyle(Color(white: 0.98))
    }
}

// MARK: - Quick Edit Button

private struct QuickEditButton: View {
    let type: CodeEditType
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: type.icon)
                    .font(.caption)
                Text(type.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(type.color.opacity(0.1))
            .foregroundStyle(type.color)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(type.color.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
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

        // Simple line-by-line diff
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
            // Indicator
            Text(indicator)
                .font(.system(.caption, design: .monospaced))
                .frame(width: 16)
                .foregroundStyle(indicatorColor)

            // Content
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
            // Language header
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

            // Code content
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

// MARK: - Inline Edit Context Menu

/// Context menu for inline code editing
public struct InlineEditContextMenu: View {
    let code: String
    let language: String?

    public init(code: String, language: String? = nil) {
        self.code = code
        self.language = language
    }

    public var body: some View {
        Group {
            Button {
                InlineCodeEditorController.shared.startEditing(code: code, language: language)
            } label: {
                Label("Edit Code", systemImage: "pencil")
            }

            Divider()

            ForEach(CodeEditType.allCases.filter { $0 != .custom }, id: \.self) { type in
                Button {
                    InlineCodeEditorController.shared.startEditing(code: code, language: language)
                    Task {
                        try? await InlineCodeEditorController.shared.applyEdit(type: type)
                    }
                } label: {
                    Label(type.displayName, systemImage: type.icon)
                }
            }

            Divider()

            Button {
                #if os(macOS)
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(code, forType: .string)
                #else
                UIPasteboard.general.string = code
                #endif
            } label: {
                Label("Copy Code", systemImage: "doc.on.doc")
            }
        }
    }
}

// MARK: - View Extension for Context Menu

public extension View {
    /// Adds inline code editing context menu
    func inlineCodeEditable(code: String, language: String? = nil) -> some View {
        self.contextMenu {
            InlineEditContextMenu(code: code, language: language)
        }
    }
}

// MARK: - Preview

#Preview("Inline Code Editor") {
    struct Preview: View {
        @StateObject var controller = InlineCodeEditorController.shared

        var body: some View {
            VStack {
                Button("Start Editing") {
                    controller.startEditing(
                        code: """
                        func greet(name: String) -> String {
                            return "Hello, " + name + "!"
                        }
                        """,
                        language: "swift"
                    )
                }

                InlineCodeEditorView()
                    .frame(height: 400)
            }
            .padding()
        }
    }
    return Preview()
}

#Preview("Diff View") {
    DiffView(
        original: """
        func hello() {
            print("Hello")
        }
        """,
        modified: """
        func hello(name: String) {
            print("Hello, \\(name)!")
        }
        """
    )
    .padding()
}
