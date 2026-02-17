// LiveAutoCorrectView.swift
// Thea V4 — SwiftUI modifier and suggestion view for LiveAutoCorrect
//
// Extracted from LiveAutoCorrect.swift (SRP: UI components are separate
// from the correction service and data models).

import SwiftUI

// MARK: - View Modifier

public struct AutoCorrectModifier: ViewModifier {
    @Binding var text: String
    @State private var correctionResult: CorrectionResult?
    @State private var showSuggestions = false

    public func body(content: Content) -> some View {
        content
            .onChange(of: text) { _, newValue in
                if LiveAutoCorrect.shared.isEnabled && LiveAutoCorrect.shared.liveMode {
                    LiveAutoCorrect.shared.processLiveInput(newValue) { result in
                        Task { @MainActor in
                            correctionResult = result
                            if result.hasCorrections && LiveAutoCorrect.shared.showSuggestions {
                                showSuggestions = true
                            } else if !LiveAutoCorrect.shared.showSuggestions && result.hasCorrections {
                                text = result.corrected
                            }
                        }
                    }
                }
            }
            .popover(isPresented: $showSuggestions) {
                if let result = correctionResult {
                    AutoCorrectSuggestionView(result: result) { accepted in
                        if accepted {
                            text = result.corrected
                        }
                        showSuggestions = false
                    }
                }
            }
    }
}

public extension View {
    /// Enable AI-powered auto-correct for a text field
    func autoCorrect(text: Binding<String>) -> some View {
        modifier(AutoCorrectModifier(text: text))
    }
}

// MARK: - Suggestion View

struct AutoCorrectSuggestionView: View {
    let result: CorrectionResult
    let onAction: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "text.badge.checkmark")
                    .foregroundStyle(.blue)
                Text("Suggested Correction")
                    .font(.headline)
                Spacer()
                Text(result.language.uppercased())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            ForEach(result.corrections) { correction in
                HStack {
                    Text(correction.original)
                        .strikethrough()
                        .foregroundStyle(.secondary)
                    Image(systemName: "arrow.right")
                        .foregroundStyle(.secondary)
                    Text(correction.replacement)
                        .bold()
                        .foregroundStyle(.primary)
                }
                .font(.body)
            }

            Divider()

            HStack {
                Button("Ignore") {
                    onAction(false)
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Accept") {
                    onAction(true)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(minWidth: 280)
    }
}
