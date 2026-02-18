import MarkdownUI
import SwiftUI

#if canImport(Highlightr)
    import Highlightr
#endif

// MARK: - Code Block View with Syntax Highlighting

struct CodeBlockView: View {
    let configuration: CodeBlockConfiguration

    @State private var showCopied = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with language and copy button
            HStack {
                if let language = configuration.language {
                    Text(language)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                }

                Spacer()

                Button {
                    copyCode()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                        Text(showCopied ? "Copied" : "Copy")
                    }
                    .font(.caption)
                    .foregroundStyle(showCopied ? .green : .secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Copy code snippet")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(headerBackground)

            // Code content with syntax highlighting
            ScrollView(.horizontal, showsIndicators: false) {
                highlightedCode
                    .padding(12)
            }
            .background(codeBackground)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(borderColor, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var highlightedCode: some View {
        let code = configuration.content

        #if canImport(Highlightr) && os(macOS)
            if let attributedCode = highlightCodeWithHighlightr(code) {
                Text(attributedCode)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
            } else {
                plainCodeText(code)
            }
        #else
            plainCodeText(code)
        #endif
    }

    #if canImport(Highlightr) && os(macOS)
        /// Highlights code using Highlightr library
        private func highlightCodeWithHighlightr(_ code: String) -> AttributedString? {
            guard let highlighter = Highlightr(),
                  let language = configuration.language else {
                return nil
            }

            let themeName = colorScheme == .dark ? "monokai-sublime" : "github"
            highlighter.setTheme(to: themeName)

            guard let highlighted = highlighter.highlight(code, as: language) else {
                return nil
            }

            return AttributedString(highlighted)
        }
    #endif

    private func plainCodeText(_ code: String) -> some View {
        Text(code)
            .font(.system(.body, design: .monospaced))
            .foregroundStyle(.primary)
            .textSelection(.enabled)
    }

    private func copyCode() {
        let code = configuration.content
        #if os(macOS)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(code, forType: .string)
        #else
            UIPasteboard.general.string = code
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

    private var headerBackground: Color {
        Color.theaSurface.opacity(0.8)
    }

    private var codeBackground: Color {
        Color.theaSurface.opacity(0.5)
    }

    private var borderColor: Color {
        Color.secondary.opacity(0.2)
    }
}

// MARK: - Code Syntax Highlighter for MarkdownUI

struct TheaCodeHighlighter: CodeSyntaxHighlighter {
    func highlightCode(_ code: String, language: String?) -> Text {
        Text(code)
            .font(.system(.body, design: .monospaced))
    }
}
