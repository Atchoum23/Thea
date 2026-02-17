// PersonalizationSettingsView.swift
// Thea — Let users tell Thea about themselves so every conversation feels tailored.

import SwiftUI

// MARK: - Platform Color Helpers

private extension Color {
    static var theaTextBackground: Color {
        #if os(macOS)
        Color(nsColor: .textBackgroundColor)
        #else
        Color(uiColor: .systemBackground)
        #endif
    }

    static var theaSeparator: Color {
        #if os(macOS)
        Color(nsColor: .separatorColor)
        #else
        Color(uiColor: .separator)
        #endif
    }
}

// MARK: - Personalization Settings View

struct PersonalizationSettingsView: View {
    @StateObject private var settings = SettingsManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var contextDraft: String = ""
    @State private var responsePrefDraft: String = ""
    @State private var showSavedBanner = false
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case context, responsePreference
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection

                enableToggleSection

                if settings.personalizationEnabled {
                    aboutMeSection
                    responsePrefSection
                    previewSection
                    saveButton
                }
            }
            .padding(24)
        }
        .navigationTitle("Personalization")
        .overlay(savedBanner, alignment: .top)
        .onAppear {
            contextDraft = settings.personalizationContext
            responsePrefDraft = settings.personalizationResponsePreference
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Personalization")
                .font(.title2.bold())
            Text("Tell Thea about yourself so it can tailor its responses to your background, preferences, and communication style.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var enableToggleSection: some View {
        GroupBox {
            Toggle(isOn: $settings.personalizationEnabled) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Inject into every conversation")
                        .font(.body)
                    Text("When enabled, your personal context is prepended to the system prompt for every message.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.switch)
            .padding(.vertical, 4)
        }
        .accessibilityLabel("Inject personalization into every conversation")
    }

    private var aboutMeSection: some View {
        aboutMeSectionContent
    }

    @ViewBuilder
    private var aboutMeSectionContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("About Me", systemImage: "person.fill")
                .font(.headline)

            Text("Describe yourself: your name, role, domain expertise, interests, or any context that helps Thea understand you.")
                .font(.caption)
                .foregroundStyle(.secondary)

            aboutMeEditor

            HStack {
                Spacer()
                Text("\(contextDraft.count) characters")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var aboutMeEditor: some View {
        TextEditor(text: $contextDraft)
            .font(.body)
            .frame(minHeight: 130, maxHeight: 240)
            .padding(8)
            .background(Color.theaTextBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(aboutMeEditorBorder)
            .focused($focusedField, equals: .context)
            .accessibilityLabel("About me")
            .accessibilityHint("Describe yourself to help Thea personalize responses")
            .overlay(alignment: .topLeading) {
                if contextDraft.isEmpty {
                    Text("e.g. I'm a senior iOS engineer at a startup. I work mainly in Swift and Python, care about performance, and prefer straight answers.")
                        .font(.body)
                        .foregroundStyle(.tertiary)
                        .padding(12)
                        .allowsHitTesting(false)
                }
            }
    }

    private var aboutMeEditorBorder: some View {
        RoundedRectangle(cornerRadius: 8)
            .stroke(
                focusedField == .context ? Color.accentColor : Color.theaSeparator,
                lineWidth: focusedField == .context ? 1.5 : 0.5
            )
    }

    private var responsePrefSection: some View {
        responsePrefSectionContent
    }

    @ViewBuilder
    private var responsePrefSectionContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("How I Like Responses", systemImage: "text.bubble.fill")
                .font(.headline)

            Text("Describe your preferred response format: length, tone, code style, level of detail, etc.")
                .font(.caption)
                .foregroundStyle(.secondary)

            responsePrefEditor

            HStack {
                Spacer()
                Text("\(responsePrefDraft.count) characters")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var responsePrefEditor: some View {
        TextEditor(text: $responsePrefDraft)
            .font(.body)
            .frame(minHeight: 90, maxHeight: 160)
            .padding(8)
            .background(Color.theaTextBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(responsePrefEditorBorder)
            .focused($focusedField, equals: .responsePreference)
            .accessibilityLabel("How I like responses")
            .accessibilityHint("Describe your preferred response style and format")
            .overlay(alignment: .topLeading) {
                if responsePrefDraft.isEmpty {
                    Text("e.g. Keep it short unless I ask for details. Use code examples where relevant. Skip the preamble.")
                        .font(.body)
                        .foregroundStyle(.tertiary)
                        .padding(12)
                        .allowsHitTesting(false)
                }
            }
    }

    private var responsePrefEditorBorder: some View {
        RoundedRectangle(cornerRadius: 8)
            .stroke(
                focusedField == .responsePreference ? Color.accentColor : Color.theaSeparator,
                lineWidth: focusedField == .responsePreference ? 1.5 : 0.5
            )
    }

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("System Prompt Preview", systemImage: "eye.fill")
                .font(.headline)

            Text("This is the personalization block that will be prepended to every system prompt when enabled.")
                .font(.caption)
                .foregroundStyle(.secondary)

            previewScrollView
        }
    }

    private var previewScrollView: some View {
        let preview = buildPreview()
        return ScrollView {
            Text(preview.isEmpty ? "(No personalization content yet.)" : preview)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(preview.isEmpty ? .tertiary : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
        }
        .frame(maxHeight: 120)
        .background(Color.theaTextBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.theaSeparator, lineWidth: 0.5)
        )
        .accessibilityLabel("System prompt preview")
        .accessibilityValue(preview.isEmpty ? "No personalization content yet" : preview)
    }

    private var saveButton: some View {
        HStack {
            Spacer()
            Button("Save") {
                savePersonalization()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!hasChanges)
            .accessibilityLabel("Save personalization settings")
        }
    }

    private var savedBanner: some View {
        Group {
            if showSavedBanner {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Personalization saved")
                        .font(.callout)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.regularMaterial)
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
                .transition(.move(edge: .top).combined(with: .opacity))
                .padding(.top, 12)
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7), value: showSavedBanner)
    }

    // MARK: - Helpers

    private var hasChanges: Bool {
        contextDraft != settings.personalizationContext ||
        responsePrefDraft != settings.personalizationResponsePreference
    }

    private func buildPreview() -> String {
        var parts: [String] = []
        let ctx = contextDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let pref = responsePrefDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        if !ctx.isEmpty { parts.append("USER CONTEXT:\n\(ctx)") }
        if !pref.isEmpty { parts.append("RESPONSE PREFERENCES:\n\(pref)") }
        return parts.joined(separator: "\n\n")
    }

    private func savePersonalization() {
        settings.personalizationContext = contextDraft
        settings.personalizationResponsePreference = responsePrefDraft

        showSavedBanner = true
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            showSavedBanner = false
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        PersonalizationSettingsView()
    }
    .frame(width: 600, height: 700)
}
