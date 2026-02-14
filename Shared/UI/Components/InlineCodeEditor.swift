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

// Types (CodeEditType, EditableCodeBlock, InlineCodeEditRequest, InlineEditError)
// and supporting views (DiffView, DiffLine, InlineCodeBlockView)
// are in InlineCodeEditorTypes.swift

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

// MARK: - Inline Code Editor View

/// Main view for inline code editing
public struct InlineCodeEditorView: View {
    @ObservedObject var controller = InlineCodeEditorController.shared
    @Environment(\.colorScheme) private var colorScheme

    public init() {}

    public var body: some View {
        if let block = controller.activeBlock, block.isEditing {
            VStack(spacing: 0) {
                editorToolbar
                Divider()
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

            Toggle(isOn: $controller.showDiff) {
                Label("Show Diff", systemImage: "arrow.left.arrow.right")
            }
            .toggleStyle(.button)
            .disabled(!(controller.activeBlock?.hasChanges ?? false))

            Button {
                controller.undo()
            } label: {
                Image(systemName: "arrow.uturn.backward")
            }
            .disabled(!(controller.activeBlock?.canUndo ?? false))
            .accessibilityLabel("Undo")

            Button {
                controller.revert()
            } label: {
                Image(systemName: "arrow.counterclockwise")
            }
            .disabled(!(controller.activeBlock?.hasChanges ?? false))
            .accessibilityLabel("Revert changes")

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

            if controller.isProcessing {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Applying edit...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

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
