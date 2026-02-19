// EnhancedMessageBubbleTypes.swift
// Supporting views and types for EnhancedMessageBubble

import SwiftUI

#if canImport(Highlightr)
import Highlightr
import OSLog

// periphery:ignore - Reserved: logger global — reserved for future feature activation
private let logger = Logger(subsystem: "ai.thea.app", category: "EnhancedMessageBubbleTypes")
#endif

// periphery:ignore - Reserved: logger global var reserved for future feature activation

// MARK: - Supporting Views

/// Small icon action button
struct IconActionButton: View {
    let icon: String
    let color: Color
    let label: String
    let action: () -> Void

    @State private var isPressed = false

    init(icon: String, color: Color, label: String = "", action: @escaping () -> Void) {
        self.icon = icon
        self.color = color
        self.label = label
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(color)
                .frame(width: 28, height: 28)
                .background(Color.primary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: TheaRadius.xs))
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.9 : 1.0)
        .accessibilityLabel(label.isEmpty ? icon : label)
    }
}

// periphery:ignore - Reserved: ConfidenceDot type — reserved for future feature activation
/// Confidence indicator dot
struct ConfidenceDot: View {
    // periphery:ignore - Reserved: ConfidenceDot type reserved for future feature activation
    let confidence: Double

    var body: some View {
        Circle()
            .fill(confidenceColor)
            .frame(width: 6, height: 6)
            .help("Confidence: \(Int(confidence * 100))%")
    }

    private var confidenceColor: Color {
        switch confidence {
        case 0.8...1.0: return .green
        case 0.5..<0.8: return .yellow
        default: return .orange
        }
    }
}

/// Enhanced code block with syntax highlighting
struct EnhancedCodeBlock: View {
    let code: String
    let language: String?
    var isExpanded: Bool
    // periphery:ignore - Reserved: onToggle property reserved for future feature activation
    let onToggle: () -> Void

    @State private var showCopied = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                if let language {
                    Text(language.uppercased())
                        .font(.theaCaption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    copyCode()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                        Text(showCopied ? "Copied" : "Copy")
                    }
                    .font(.theaCaption2)
                    .foregroundStyle(showCopied ? .green : .secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, TheaSpacing.md)
            .padding(.vertical, TheaSpacing.sm)
            .background(colorScheme == .dark ? Color(white: 0.12) : Color(white: 0.92))

            // Code content
            if isExpanded {
                ScrollView(.horizontal, showsIndicators: false) {
                    Text(code)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(TheaSpacing.md)
                }
                .background(colorScheme == .dark ? Color(white: 0.08) : Color(white: 0.97))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: TheaRadius.sm))
        .overlay(
            RoundedRectangle(cornerRadius: TheaRadius.sm)
                .stroke(colorScheme == .dark ? Color(white: 0.2) : Color(white: 0.85), lineWidth: 1)
        )
    }

    private func copyCode() {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(code, forType: .string)
        #else
        UIPasteboard.general.string = code
        #endif

        withAnimation(TheaAnimation.bouncy) {
            showCopied = true
        }

        Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: 1_500_000_000)
            } catch {
                return
            }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { showCopied = false }
        }
    }
}

// MARK: - Block Parsing

/// Parsed response block
struct ParsedBlock: Identifiable {
    let id: String
    let type: ResponseBlockType
    let content: String
    var metadata: [String: String] = [:]
}

/// Parse message text into dynamic blocks
func parseResponseBlocks(_ text: String) -> [ParsedBlock] {
    var blocks: [ParsedBlock] = []
    var currentText = ""
    var blockIndex = 0

    let lines = text.components(separatedBy: "\n")
    var inCodeBlock = false
    var codeLanguage: String?
    var codeContent = ""

    for line in lines {
        // Code block detection
        if line.hasPrefix("```") {
            if inCodeBlock {
                // End code block
                blocks.append(ParsedBlock(
                    id: "code-\(blockIndex)",
                    type: .code,
                    content: codeContent.trimmingCharacters(in: .whitespacesAndNewlines),
                    metadata: codeLanguage.map { ["language": $0] } ?? [:]
                ))
                blockIndex += 1
                codeContent = ""
                codeLanguage = nil
                inCodeBlock = false
            } else {
                // Start code block - flush current text
                if !currentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    blocks.append(ParsedBlock(
                        id: "text-\(blockIndex)",
                        type: .text,
                        content: currentText.trimmingCharacters(in: .whitespacesAndNewlines)
                    ))
                    blockIndex += 1
                    currentText = ""
                }

                inCodeBlock = true
                codeLanguage = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                if codeLanguage?.isEmpty == true { codeLanguage = nil }
            }
            continue
        }

        if inCodeBlock {
            codeContent += line + "\n"
        } else {
            // Check for special block markers
            if line.hasPrefix("\u{26A0}\u{FE0F}") || line.lowercased().contains("warning:") {
                if !currentText.isEmpty {
                    blocks.append(ParsedBlock(id: "text-\(blockIndex)", type: .text, content: currentText))
                    blockIndex += 1
                    currentText = ""
                }
                blocks.append(ParsedBlock(id: "warning-\(blockIndex)", type: .warning, content: line))
                blockIndex += 1
            } else if line.hasPrefix("\u{2705}") || line.lowercased().contains("success:") {
                if !currentText.isEmpty {
                    blocks.append(ParsedBlock(id: "text-\(blockIndex)", type: .text, content: currentText))
                    blockIndex += 1
                    currentText = ""
                }
                blocks.append(ParsedBlock(id: "success-\(blockIndex)", type: .success, content: line))
                blockIndex += 1
            } else {
                currentText += line + "\n"
            }
        }
    }

    // Flush remaining content
    if !currentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        blocks.append(ParsedBlock(
            id: "text-\(blockIndex)",
            type: .text,
            content: currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        ))
    }

    return blocks.isEmpty ? [ParsedBlock(id: "text-0", type: .text, content: text)] : blocks
}

// MARK: - Quick Actions

public enum MessageQuickAction: String, CaseIterable {
    case copy
    case regenerate
    case expand
    case simplify
    case explain
    case translate
}

// MARK: - Preview

#Preview("Enhanced Message Bubble") {
    ScrollView {
        VStack(spacing: TheaSpacing.lg) {
            EnhancedMessageBubble(
                message: Message(
                    id: UUID(),
                    conversationID: UUID(),
                    role: .user,
                    content: .text("Can you help me write a Swift function?"),
                    model: nil
                )
            )

            EnhancedMessageBubble(
                message: Message(
                    id: UUID(),
                    conversationID: UUID(),
                    role: .assistant,
                    content: .text("""
                    Sure! Here's a simple Swift function:

                    ```swift
                    func greet(name: String) -> String {
                        return "Hello, \\(name)!"
                    }
                    ```

                    \u{2705} This function takes a name and returns a greeting.
                    """),
                    model: "claude-4-sonnet"
                )
            )

            EnhancedMessageBubble(
                message: Message(
                    id: UUID(),
                    conversationID: UUID(),
                    role: .assistant,
                    content: .text("Thinking..."),
                    model: "claude-4-sonnet"
                ),
                isStreaming: true
            )
        }
        .padding()
    }
    .frame(width: 600, height: 800)
    .background(Color.windowBackground)
}
