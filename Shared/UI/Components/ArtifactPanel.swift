//
//  ArtifactPanel.swift
//  Thea
//
//  Dual-panel artifact display for generated code, documents, and visualizations
//  Based on Claude Desktop's Artifacts feature
//  Uses existing Artifact types from ArtifactManager.swift
//

import SwiftUI

// MARK: - Artifact Panel View

/// Main artifact panel that shows in the 4th column
struct ArtifactPanel: View {
    @Binding var artifacts: [Artifact]
    @Binding var selectedArtifactId: UUID?
    let onClose: () -> Void

    @State private var showingVersionHistory = false

    private var selectedArtifact: Artifact? {
        artifacts.first { $0.id == selectedArtifactId }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Panel header
            panelHeader

            Divider()

            if let artifact = selectedArtifact {
                // Artifact content view
                ArtifactDetailView(
                    artifact: artifact,
                    showingVersionHistory: $showingVersionHistory
                )
            } else if artifacts.isEmpty {
                // Empty state
                emptyState
            } else {
                // Artifact list
                artifactList
            }
        }
        .frame(minWidth: 300, idealWidth: 400)
        .background(Color.windowBackground)
    }

    // MARK: - Header

    private var panelHeader: some View {
        HStack {
            if selectedArtifact != nil {
                Button {
                    selectedArtifactId = nil
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.plain)
                .help("Back to list")
                .accessibilityLabel("Back to list")
            }

            Text(selectedArtifact?.title ?? "Artifacts")
                .font(.headline)

            Spacer()

            if selectedArtifact != nil {
                Button {
                    showingVersionHistory.toggle()
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
                .help("Version history")
                .accessibilityLabel("Version history")
            }

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.plain)
            .help("Close panel")
            .accessibilityLabel("Close panel")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "doc.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text("No Artifacts Yet")
                .font(.headline)

            Text("Generated code, documents, and other content will appear here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
        }
    }

    // MARK: - Artifact List

    private var artifactList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(artifacts) { artifact in
                    ArtifactRow(artifact: artifact)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedArtifactId = artifact.id
                        }
                }
            }
            .padding(16)
        }
    }
}

// MARK: - Artifact Row

struct ArtifactRow: View {
    let artifact: Artifact

    var body: some View {
        HStack(spacing: 12) {
            // Type icon
            Image(systemName: iconForArtifact(artifact))
                .font(.system(size: 20))
                .foregroundStyle(.theaPrimary)
                .frame(width: 32, height: 32)
                .background(Color.theaPrimaryDefault.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 4) {
                Text(artifact.title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(artifact.type.displayName)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)

                    if artifact.version > 1 {
                        Text("•")
                            .foregroundStyle(.secondary)
                        Text("v\(artifact.version)")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(Color.controlBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func iconForArtifact(_ artifact: Artifact) -> String {
        switch artifact.type {
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .document: return "doc.text"
        case .visualization: return "chart.pie"
        case .interactive: return "hand.tap"
        case .data: return "tablecells"
        }
    }
}

// MARK: - Artifact Detail View

struct ArtifactDetailView: View {
    let artifact: Artifact
    @Binding var showingVersionHistory: Bool

    @State private var selectedTab: ContentTab = .code
    @State private var showCopied = false
    @State private var saveError: Error?
    @State private var showingSaveError = false

    enum ContentTab: String, CaseIterable {
        case code = "Code"
        case preview = "Preview"
    }

    private var showsTabs: Bool {
        switch artifact.type {
        case .document(format: .markdown), .document(format: .html):
            return true
        default:
            return false
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar (for HTML/Markdown)
            if showsTabs {
                tabBar
                Divider()
            }

            // Content area
            ZStack(alignment: .topTrailing) {
                contentArea

                // Action buttons
                actionButtons
                    .padding(12)
            }

            // Version info
            if showingVersionHistory {
                Divider()
                versionInfoView
            }
        }
        .alert("Save Failed", isPresented: $showingSaveError, presenting: saveError) { _ in
            Button("OK") { }
        } message: { error in
            Text("Could not save file: \(error.localizedDescription)")
        }
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(ContentTab.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    Text(tab.rawValue)
                        .font(.system(size: 12, weight: selectedTab == tab ? .semibold : .regular))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(selectedTab == tab ? Color.theaPrimaryDefault.opacity(0.1) : Color.clear)
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, 8)
    }

    // MARK: - Content Area

    @ViewBuilder
    private var contentArea: some View {
        ScrollView {
            switch selectedTab {
            case .code:
                codeView
            case .preview:
                previewView
            }
        }
    }

    private var codeView: some View {
        Text(artifact.content)
            .font(.system(.body, design: .monospaced))
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
    }

    @ViewBuilder
    private var previewView: some View {
        switch artifact.type {
        case .document(format: .markdown):
            // In a full implementation, use MarkdownUI
            Text(artifact.content)
                .padding(16)
        case .document(format: .html):
            // In a full implementation, use WebView
            Text("HTML Preview")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        default:
            codeView
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 8) {
            // Copy button
            Button {
                copyToClipboard()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                    Text(showCopied ? "Copied" : "Copy")
                }
                .font(.system(size: 12))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .foregroundStyle(showCopied ? .green : .primary)

            // Save button
            #if os(macOS)
                Button {
                    saveToFile()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.down")
                        Text("Save")
                    }
                    .font(.system(size: 12))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            #endif
        }
    }

    // MARK: - Version Info

    private var versionInfoView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Version Info")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 12)

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Version")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Text("\(artifact.version)")
                        .font(.system(size: 12, weight: .medium))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Modified")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Text(artifact.modifiedAt, format: .dateTime)
                        .font(.system(size: 12))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Size")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Text("\(artifact.content.count) chars")
                        .font(.system(size: 12))
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
    }

    // MARK: - Actions

    private func copyToClipboard() {
        #if os(macOS)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(artifact.content, forType: .string)
        #else
            UIPasteboard.general.string = artifact.content
        #endif

        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            showCopied = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                showCopied = false
            }
        }
    }

    #if os(macOS)
        private func saveToFile() {
            let panel = NSSavePanel()
            panel.nameFieldStringValue = artifact.title
            panel.canCreateDirectories = true

            if panel.runModal() == .OK, let url = panel.url {
                do {
                    try artifact.content.write(to: url, atomically: true, encoding: .utf8)
                } catch {
                    saveError = error
                    showingSaveError = true
                }
            }
        }
    #endif
}

// MARK: - Artifact Extraction Utility

/// Utility for extracting artifacts from message content
enum ArtifactExtractor {
    /// Extract code blocks from markdown content
    static func extractCodeBlocks(from content: String) -> [Artifact] {
        var artifacts: [Artifact] = []
        let pattern = "```(\\w+)?\\n([\\s\\S]*?)```"

        let regex: NSRegularExpression
        do {
            regex = try NSRegularExpression(pattern: pattern, options: [])
        } catch {
            logger.error("Failed to compile regex pattern: \(error.localizedDescription)")
            return artifacts
        }

        let range = NSRange(content.startIndex..., in: content)
        let matches = regex.matches(in: content, options: [], range: range)

        for (index, match) in matches.enumerated() {
            var language: String?
            var code: String = ""

            if match.numberOfRanges > 1,
               let langRange = Range(match.range(at: 1), in: content)
            {
                language = String(content[langRange])
            }

            if match.numberOfRanges > 2,
               let codeRange = Range(match.range(at: 2), in: content)
            {
                code = String(content[codeRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            }

            if !code.isEmpty {
                let title = language.map { "\($0.capitalized) Code \(index + 1)" } ?? "Code Block \(index + 1)"
                // Default to swift if language not recognized
                let codeLanguage = CodeLanguage(rawValue: language ?? "swift") ?? .swift
                artifacts.append(Artifact(
                    title: title,
                    type: .code(language: codeLanguage),
                    content: code
                ))
            }
        }

        return artifacts
    }
}

// MARK: - Previews

#if DEBUG
    #Preview("Artifact Panel - Empty") {
        ArtifactPanel(
            artifacts: .constant([]),
            selectedArtifactId: .constant(nil)
        )            {}
        .frame(height: 500)
    }

    #Preview("Artifact Panel - With Items") {
        ArtifactPanel(
            artifacts: .constant([
                Artifact(
                    title: "UserModel.swift",
                    type: .code(language: .swift),
                    content: "struct User {\n    let id: UUID\n    let name: String\n}"
                ),
                Artifact(
                    title: "README.md",
                    type: .document(format: .markdown),
                    content: "# Project\n\nThis is a sample project."
                ),
                Artifact(
                    title: "config.json",
                    type: .data(format: .json),
                    content: "{\n  \"key\": \"value\"\n}"
                )
            ]),
            selectedArtifactId: .constant(nil)
        )            {}
        .frame(height: 500)
    }

    #Preview("Artifact Detail View") {
        ArtifactDetailView(
            artifact: Artifact(
                title: "Example.swift",
                type: .code(language: .swift),
                content: """
                import Foundation

                struct Example {
                    let value: Int

                    func compute() -> Int {
                        return value * 2
                    }
                }
                """
            ),
            showingVersionHistory: .constant(false)
        )
        .frame(width: 400, height: 400)
    }
#endif
