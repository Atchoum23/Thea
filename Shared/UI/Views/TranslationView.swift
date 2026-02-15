// TranslationView.swift
// Thea — Translation UI for macOS and iOS
// Replaces: DeepL, Google Translate, Auto Translate

import SwiftUI

// MARK: - Translation View

struct TranslationView: View {
    @StateObject private var engine = TranslationEngine.shared
    @State private var inputText = ""
    @State private var outputText = ""
    @State private var sourceLanguage = "auto"
    @State private var targetLanguage = "fr"
    @State private var showingHistory = false
    @State private var errorMessage: String?
    @State private var showCopiedFeedback = false

    private let languages = ConversationLanguageService.shared.supportedLanguages

    var body: some View {
        VStack(spacing: 0) {
            languageBar
            Divider()
            translationArea
            if let error = errorMessage {
                errorBanner(error)
            }
            Divider()
            bottomBar
        }
        .frame(minWidth: 400, minHeight: 350)
    }

    // MARK: - Language Selection Bar

    private var languageBar: some View {
        HStack(spacing: 12) {
            sourceLanguagePicker
            swapButton
            targetLanguagePicker
            Spacer()
            providerPicker
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.theaSurface.opacity(0.5))
    }

    private var sourceLanguagePicker: some View {
        Menu {
            Button {
                sourceLanguage = "auto"
            } label: {
                Label("Auto-Detect", systemImage: "wand.and.stars")
            }
            Divider()
            recentSourceLanguages
            Divider()
            allLanguageItems(selecting: $sourceLanguage)
        } label: {
            HStack(spacing: 4) {
                if sourceLanguage == "auto" {
                    Image(systemName: "wand.and.stars")
                        .font(.caption)
                    Text("Auto-Detect")
                } else if let lang = languages.first(where: { $0.code == sourceLanguage }) {
                    Text(lang.flag)
                    Text(lang.name)
                }
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
            .font(.theaCaption1)
        }
        #if os(macOS)
        .menuStyle(.borderlessButton)
        #endif
        .accessibilityLabel("Source language")
    }

    @ViewBuilder
    private var recentSourceLanguages: some View {
        let recentSources = Array(Set(engine.recentPairs.map(\.source))).prefix(5)
        if !recentSources.isEmpty {
            ForEach(Array(recentSources), id: \.self) { code in
                if let lang = languages.first(where: { $0.code == code }) {
                    Button {
                        sourceLanguage = code
                    } label: {
                        Label("\(lang.flag) \(lang.name)", systemImage: "clock")
                    }
                }
            }
        }
    }

    private var targetLanguagePicker: some View {
        Menu {
            recentTargetLanguages
            if !engine.recentPairs.isEmpty {
                Divider()
            }
            allLanguageItems(selecting: $targetLanguage)
        } label: {
            HStack(spacing: 4) {
                if let lang = languages.first(where: { $0.code == targetLanguage }) {
                    Text(lang.flag)
                    Text(lang.name)
                }
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
            .font(.theaCaption1)
        }
        #if os(macOS)
        .menuStyle(.borderlessButton)
        #endif
        .accessibilityLabel("Target language")
    }

    @ViewBuilder
    private var recentTargetLanguages: some View {
        let recentTargets = Array(Set(engine.recentPairs.map(\.target))).prefix(5)
        if !recentTargets.isEmpty {
            ForEach(Array(recentTargets), id: \.self) { code in
                if let lang = languages.first(where: { $0.code == code }) {
                    Button {
                        targetLanguage = code
                    } label: {
                        Label("\(lang.flag) \(lang.name)", systemImage: "clock")
                    }
                }
            }
        }
    }

    private func allLanguageItems(selecting binding: Binding<String>) -> some View {
        ForEach(languages) { lang in
            Button {
                binding.wrappedValue = lang.code
            } label: {
                Text("\(lang.flag) \(lang.name) (\(lang.nativeName))")
            }
        }
    }

    private var swapButton: some View {
        Button {
            guard sourceLanguage != "auto" else { return }
            let temp = sourceLanguage
            sourceLanguage = targetLanguage
            targetLanguage = temp
            let tempText = inputText
            inputText = outputText
            outputText = tempText
        } label: {
            Image(systemName: "arrow.left.arrow.right")
                .font(.theaBody)
                .foregroundStyle(sourceLanguage == "auto" ? Color.secondary : Color.theaPrimaryDefault)
        }
        .buttonStyle(.plain)
        .disabled(sourceLanguage == "auto")
        .accessibilityLabel("Swap languages")
    }

    private var providerPicker: some View {
        Menu {
            ForEach(TranslationProvider.allCases, id: \.rawValue) { provider in
                Button {
                    engine.preferredProvider = provider
                } label: {
                    Label(provider.rawValue, systemImage: provider.icon)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: engine.preferredProvider.icon)
                Text(engine.preferredProvider.rawValue)
                    .font(.caption)
            }
            .foregroundStyle(.secondary)
        }
        #if os(macOS)
        .menuStyle(.borderlessButton)
        #endif
        .accessibilityLabel("Translation provider")
    }

    // MARK: - Translation Area

    private var translationArea: some View {
        #if os(macOS)
        HSplitView {
            inputPanel
            outputPanel
        }
        #else
        VStack(spacing: 0) {
            inputPanel
            Divider()
            outputPanel
        }
        #endif
    }

    private var inputPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Source")
                    .font(.theaCaption1)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(inputText.count)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)

            TextEditor(text: $inputText)
                .font(.theaBody)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 8)
                .frame(minHeight: 100)
                .accessibilityLabel("Source text")

            HStack(spacing: 8) {
                pasteButton
                clearButton
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
        .background(Color.theaSurface.opacity(0.2))
    }

    private var outputPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Translation")
                    .font(.theaCaption1)
                    .foregroundStyle(.secondary)
                Spacer()
                if engine.isTranslating {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)

            if outputText.isEmpty && !engine.isTranslating {
                Text("Translation will appear here")
                    .font(.theaBody)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                ScrollView {
                    Text(outputText)
                        .font(.theaBody)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.top, 4)
                }
                .frame(minHeight: 100)
            }

            HStack(spacing: 8) {
                copyButton
                Spacer()
                if showCopiedFeedback {
                    Text("Copied!")
                        .font(.caption)
                        .foregroundStyle(.green)
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
        .background(Color.theaSurface.opacity(0.3))
    }

    // MARK: - Action Buttons

    private var pasteButton: some View {
        Button {
            #if os(macOS)
            if let text = NSPasteboard.general.string(forType: .string) {
                inputText = text
            }
            #else
            if let text = UIPasteboard.general.string {
                inputText = text
            }
            #endif
        } label: {
            Label("Paste", systemImage: "doc.on.clipboard")
                .font(.caption)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
    }

    private var clearButton: some View {
        Button {
            inputText = ""
            outputText = ""
            errorMessage = nil
        } label: {
            Label("Clear", systemImage: "xmark.circle")
                .font(.caption)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .disabled(inputText.isEmpty)
    }

    private var copyButton: some View {
        Button {
            #if os(macOS)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(outputText, forType: .string)
            #else
            UIPasteboard.general.string = outputText
            #endif
            withAnimation {
                showCopiedFeedback = true
            }
            Task {
                try? await Task.sleep(for: .seconds(2))
                withAnimation {
                    showCopiedFeedback = false
                }
            }
        } label: {
            Label("Copy", systemImage: "doc.on.doc")
                .font(.caption)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .disabled(outputText.isEmpty)
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: 12) {
            Button {
                showingHistory.toggle()
            } label: {
                Label("History", systemImage: "clock.arrow.circlepath")
                    .font(.theaCaption1)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            Spacer()

            Button {
                Task {
                    await performTranslation()
                }
            } label: {
                Label("Translate", systemImage: "arrow.right.circle.fill")
                    .font(.theaCaption1)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.theaPrimaryDefault)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || engine.isTranslating)
            .keyboardShortcut(.return, modifiers: .command)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .sheet(isPresented: $showingHistory) {
            TranslationHistoryView(engine: engine) { entry in
                inputText = entry.sourceText
                outputText = entry.translatedText
                sourceLanguage = entry.sourceLanguage
                targetLanguage = entry.targetLanguage
                showingHistory = false
            }
        }
    }

    // MARK: - Error Banner

    private func errorBanner(_ message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.caption)
            Spacer()
            Button {
                errorMessage = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.1))
    }

    // MARK: - Translation Action

    private func performTranslation() async {
        errorMessage = nil
        let source = sourceLanguage == "auto" ? nil : sourceLanguage
        let request = TranslationRequest(
            text: inputText,
            from: source,
            to: targetLanguage,
            provider: engine.preferredProvider
        )
        do {
            let result = try await engine.translate(request)
            outputText = result.translatedText
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Translation History View

struct TranslationHistoryView: View {
    @ObservedObject var engine: TranslationEngine
    let onSelect: (TranslationHistoryEntry) -> Void

    @State private var searchText = ""
    @Environment(\.dismiss) private var dismiss

    private var filteredHistory: [TranslationHistoryEntry] {
        if searchText.isEmpty {
            return engine.history
        }
        let query = searchText.lowercased()
        return engine.history.filter {
            $0.sourceText.lowercased().contains(query) ||
            $0.translatedText.lowercased().contains(query)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                Divider()
                if filteredHistory.isEmpty {
                    ContentUnavailableView(
                        "No Translation History",
                        systemImage: "clock.arrow.circlepath",
                        description: Text(searchText.isEmpty
                            ? "Translations will appear here"
                            : "No results for \"\(searchText)\"")
                    )
                } else {
                    List {
                        favoriteSection
                        allSection
                    }
                    .listStyle(.inset)
                }
            }
            .navigationTitle("Translation History")
            #if os(macOS)
            .frame(minWidth: 400, minHeight: 400)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .destructiveAction) {
                    Button("Clear All") {
                        engine.clearHistory()
                    }
                    .disabled(engine.history.isEmpty)
                }
            }
        }
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search translations...", text: $searchText)
                .textFieldStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var favoriteSection: some View {
        let favorites = filteredHistory.filter(\.isFavorite)
        if !favorites.isEmpty {
            Section("Favorites") {
                ForEach(favorites) { entry in
                    historyRow(entry)
                }
            }
        }
    }

    private var allSection: some View {
        Section("Recent") {
            ForEach(filteredHistory.filter { !$0.isFavorite }) { entry in
                historyRow(entry)
            }
        }
    }

    private func historyRow(_ entry: TranslationHistoryEntry) -> some View {
        Button {
            onSelect(entry)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    languageBadge(entry.sourceLanguage)
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    languageBadge(entry.targetLanguage)
                    Spacer()
                    Text(entry.timestamp, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Text(entry.sourceText.prefix(80) + (entry.sourceText.count > 80 ? "..." : ""))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(entry.translatedText.prefix(80) + (entry.translatedText.count > 80 ? "..." : ""))
                    .font(.caption)
                    .lineLimit(1)
            }
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                engine.toggleFavorite(entry)
            } label: {
                Label(
                    entry.isFavorite ? "Unfavorite" : "Favorite",
                    systemImage: entry.isFavorite ? "star.slash" : "star"
                )
            }
            Button(role: .destructive) {
                engine.deleteHistoryEntry(entry)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func languageBadge(_ code: String) -> some View {
        let lang = ConversationLanguageService.shared.supportedLanguages.first { $0.code == code }
        return HStack(spacing: 2) {
            Text(lang?.flag ?? "")
            Text(lang?.name ?? code)
        }
        .font(.caption2)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.theaSurface)
        .clipShape(Capsule())
    }
}

// MARK: - Preview

#Preview("Translation View") {
    TranslationView()
        .frame(width: 700, height: 500)
}
