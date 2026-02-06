// AutoCorrectSettingsView.swift
// Thea V2
//
// Settings view for AI-powered auto-correct feature.
// Implements Apple's Liquid Glass design language.
//
// CREATED: February 2, 2026

import SwiftUI

struct AutoCorrectSettingsView: View {
    // Use @Bindable for @Observable singleton
    @Bindable private var autoCorrect = LiveAutoCorrect.shared

    @State private var showUserDictionary = false
    @State private var newWord = ""

    var body: some View {
        Form {
            // MARK: - Main Toggle
            Section {
                Toggle("Enable AI Auto-Correct", isOn: $autoCorrect.isEnabled)
                    .tint(.blue)

                if autoCorrect.isEnabled {
                    Toggle("Live Corrections", isOn: $autoCorrect.liveMode)
                    Toggle("Show Suggestions", isOn: $autoCorrect.showSuggestions)
                }
            } header: {
                Label("Auto-Correct", systemImage: "text.badge.checkmark")
            } footer: {
                Text("AI-powered spelling, grammar, and punctuation correction with automatic language detection.")
            }

            // MARK: - Language Detection
            if autoCorrect.isEnabled {
                Section {
                    HStack {
                        Text("Detected Language")
                        Spacer()
                        Text(languageName(autoCorrect.detectedLanguage))
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Confidence")
                        Spacer()
                        Text("\(Int(autoCorrect.languageConfidence * 100))%")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Label("Language Detection", systemImage: "globe")
                }

                // MARK: - Timing
                Section {
                    Stepper(
                        "Debounce: \(autoCorrect.debounceInterval)ms",
                        value: $autoCorrect.debounceInterval,
                        in: 100...1000,
                        step: 100
                    )

                    Stepper(
                        "Min Word Length: \(autoCorrect.minimumWordLength)",
                        value: $autoCorrect.minimumWordLength,
                        in: 2...5
                    )
                } header: {
                    Label("Timing", systemImage: "clock")
                } footer: {
                    Text("Higher debounce values reduce corrections but improve performance.")
                }

                // MARK: - User Dictionary
                Section {
                    Button {
                        showUserDictionary = true
                    } label: {
                        HStack {
                            Text("User Dictionary")
                            Spacer()
                            Text("\(autoCorrect.userDictionary.count) words")
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                } header: {
                    Label("Custom Words", systemImage: "character.book.closed")
                } footer: {
                    Text("Words you add won't be flagged as misspellings.")
                }

                // MARK: - Statistics
                Section {
                    LabeledContent("Texts Processed", value: "\(autoCorrect.stats.textsProcessed)")
                    LabeledContent("Total Corrections", value: "\(autoCorrect.stats.totalCorrections)")
                    LabeledContent("Avg Processing Time", value: String(format: "%.0fms", autoCorrect.stats.averageProcessingTime * 1000))

                    Button("Reset Statistics", role: .destructive) {
                        autoCorrect.resetStats()
                    }
                } header: {
                    Label("Statistics", systemImage: "chart.bar")
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Auto-Correct")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .sheet(isPresented: $showUserDictionary) {
            UserDictionaryView(autoCorrect: autoCorrect)
        }
    }

    private func languageName(_ code: String) -> String {
        Locale.current.localizedString(forLanguageCode: code) ?? code.uppercased()
    }
}

// MARK: - User Dictionary View

struct UserDictionaryView: View {
    @Bindable var autoCorrect: LiveAutoCorrect
    @State private var newWord = ""
    @State private var searchText = ""
    @Environment(\.dismiss) private var dismiss

    var filteredWords: [String] {
        let words = Array(autoCorrect.userDictionary).sorted()
        if searchText.isEmpty {
            return words
        }
        return words.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            List {
                // Add new word section
                Section {
                    HStack {
                        TextField("Add word...", text: $newWord)
                            #if os(iOS)
                            .textInputAutocapitalization(.never)
                            #endif
                            .autocorrectionDisabled()

                        Button {
                            addWord()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.blue)
                        }
                        .disabled(newWord.isEmpty)
                    }
                }

                // Word list
                Section {
                    if filteredWords.isEmpty {
                        ContentUnavailableView(
                            "No Custom Words",
                            systemImage: "character.book.closed",
                            description: Text("Add words that shouldn't be corrected.")
                        )
                    } else {
                        ForEach(filteredWords, id: \.self) { word in
                            Text(word)
                        }
                        .onDelete { indexSet in
                            deleteWords(at: indexSet)
                        }
                    }
                } header: {
                    if !filteredWords.isEmpty {
                        Text("\(filteredWords.count) words")
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search words")
            .navigationTitle("User Dictionary")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func addWord() {
        let word = newWord.trimmingCharacters(in: .whitespacesAndNewlines)
        if !word.isEmpty {
            autoCorrect.addToUserDictionary(word)
            newWord = ""
        }
    }

    private func deleteWords(at offsets: IndexSet) {
        for index in offsets {
            let word = filteredWords[index]
            autoCorrect.removeFromUserDictionary(word)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        AutoCorrectSettingsView()
    }
}
