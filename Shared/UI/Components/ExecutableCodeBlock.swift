//
//  ExecutableCodeBlock.swift
//  Thea
//
//  Interactive code block with "Run" button and user confirmation
//  Security: All code execution requires explicit user approval
//
//  Created: February 4, 2026
//

import SwiftUI
import OSLog

private let logger = Logger(subsystem: "ai.thea.app", category: "ExecutableCodeBlock")

// MARK: - Executable Code Block

/// Code block with optional execution capability and user confirmation
public struct ExecutableCodeBlock: View {
    let code: String
    let language: String?
    var isExpanded: Bool
    let onToggle: () -> Void

    @State private var showCopied = false
    @State private var showConfirmation = false
    @State private var isExecuting = false
    @State private var executionResult: CodeExecResultModel?
    @State private var pendingExecution: CodePendingExecution?
    @Environment(\.colorScheme) private var colorScheme

    @StateObject private var executionManager = CodeExecutionManager.shared

    private var detectedLanguage: ExecLanguage {
        ExecLanguage.from(annotation: language ?? "")
    }

    private var canExecute: Bool {
        #if os(macOS)
        return detectedLanguage != .unknown
        #else
        return false
        #endif
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            codeHeader

            // Code content
            if isExpanded {
                codeContent
            }

            // Execution result (if any)
            if let result = executionResult {
                executionResultView(result)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: TheaRadius.sm))
        .overlay(
            RoundedRectangle(cornerRadius: TheaRadius.sm)
                .stroke(borderColor, lineWidth: 1)
        )
        .confirmationDialog(
            "Run Code?",
            isPresented: $showConfirmation,
            titleVisibility: .visible
        ) {
            Button("Run \(detectedLanguage.displayName) Code", role: .none) {
                executeConfirmed()
            }
            Button("Cancel", role: .cancel) {
                if let pending = pendingExecution {
                    executionManager.cancelExecution(pending.id)
                }
                pendingExecution = nil
            }
        } message: {
            Text("This will execute the code on your computer. Only run code you trust.")
        }
    }

    // MARK: - Header

    private var codeHeader: some View {
        HStack {
            // Language badge
            if let lang = language, !lang.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: detectedLanguage.icon)
                        .font(.caption2)
                    Text(lang.uppercased())
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                }
                .foregroundStyle(.secondary)
            }

            Spacer()

            // Action buttons
            HStack(spacing: TheaSpacing.sm) {
                // Run button (macOS only)
                if canExecute {
                    Button {
                        requestExecution()
                    } label: {
                        HStack(spacing: 4) {
                            if isExecuting {
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .frame(width: 12, height: 12)
                            } else {
                                Image(systemName: "play.fill")
                            }
                            Text(isExecuting ? "Running..." : "Run")
                        }
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(isExecuting ? .secondary : TheaBrandColors.gold)
                    }
                    .buttonStyle(.plain)
                    .disabled(isExecuting)
                }

                // Copy button
                Button {
                    copyCode()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                        Text(showCopied ? "Copied" : "Copy")
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(showCopied ? .green : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, TheaSpacing.md)
        .padding(.vertical, TheaSpacing.sm)
        .background(headerBackground)
    }

    // MARK: - Code Content

    private var codeContent: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Text(code)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .padding(TheaSpacing.md)
        }
        .background(codeBackground)
    }

    // MARK: - Execution Result

    @ViewBuilder
    private func executionResultView(_ result: CodeExecResultModel) -> some View {
        VStack(alignment: .leading, spacing: TheaSpacing.sm) {
            // Result header
            HStack {
                Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(result.success ? .green : .red)

                Text(result.success ? "Success" : "Failed")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(result.success ? .green : .red)

                Spacer()

                Text(result.formattedTime)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)

                Button {
                    executionResult = nil
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            // Output
            if let output = result.output, !output.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Output:")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)

                    ScrollView {
                        Text(output)
                            .font(.system(size: 12, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 150)
                }
            }

            // Error
            if let error = result.error, !error.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Error:")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.red)

                    Text(error)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.red.opacity(0.8))
                        .textSelection(.enabled)
                }
            }
        }
        .padding(TheaSpacing.md)
        .background(resultBackground(result.success))
    }

    // MARK: - Actions

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

    private func requestExecution() {
        // Request execution (creates pending execution)
        let pending = executionManager.requestExecution(
            code: code,
            language: detectedLanguage,
            source: "chat"
        )
        pendingExecution = pending

        // Show confirmation dialog
        showConfirmation = true
    }

    private func executeConfirmed() {
        guard let pending = pendingExecution else { return }

        isExecuting = true
        executionResult = nil

        Task {
            let result = await executionManager.confirmAndExecute(pending.id)

            await MainActor.run {
                withAnimation(TheaAnimation.standard) {
                    executionResult = result
                    isExecuting = false
                }
            }
        }

        pendingExecution = nil
    }

    // MARK: - Styling

    private var headerBackground: Color {
        colorScheme == .dark ? Color(white: 0.12) : Color(white: 0.92)
    }

    private var codeBackground: Color {
        colorScheme == .dark ? Color(white: 0.08) : Color(white: 0.97)
    }

    private var borderColor: Color {
        colorScheme == .dark ? Color(white: 0.2) : Color(white: 0.85)
    }

    private func resultBackground(_ success: Bool) -> Color {
        if success {
            return colorScheme == .dark
                ? Color.green.opacity(0.1)
                : Color.green.opacity(0.05)
        } else {
            return colorScheme == .dark
                ? Color.red.opacity(0.1)
                : Color.red.opacity(0.05)
        }
    }
}

// MARK: - Preview

#Preview("Executable Code Block") {
    VStack(spacing: TheaSpacing.lg) {
        ExecutableCodeBlock(
            code: """
            print("Hello, THEA!")
            let numbers = [1, 2, 3, 4, 5]
            let sum = numbers.reduce(0, +)
            print("Sum: \\(sum)")
            """,
            language: "swift",
            isExpanded: true
        ) {}

        ExecutableCodeBlock(
            code: """
            console.log("Hello from JavaScript!");
            const result = [1, 2, 3, 4, 5].reduce((a, b) => a + b, 0);
            console.log(`Sum: ${result}`);
            """,
            language: "javascript",
            isExpanded: true
        ) {}

        ExecutableCodeBlock(
            code: """
            print("Hello from Python!")
            numbers = [1, 2, 3, 4, 5]
            print(f"Sum: {sum(numbers)}")
            """,
            language: "python",
            isExpanded: true
        ) {}
    }
    .padding()
    .frame(width: 500)
    .background(Color.windowBackground)
}
