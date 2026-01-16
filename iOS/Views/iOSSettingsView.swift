import SwiftUI

struct iOSSettingsView: View {
  @State private var settingsManager = SettingsManager.shared
  @State private var voiceManager = VoiceActivationManager.shared
  @State private var migrationManager = MigrationManager.shared

  @State private var showingMigration = false
  @State private var showingAbout = false
  @State private var showingAPIKeys = false

  var body: some View {
    Form {
      aiProvidersSection
      voiceSection
      appearanceSection
      privacySection
      migrationSection
      aboutSection
    }
    .sheet(isPresented: $showingMigration) {
      iOSMigrationView()
    }
    .sheet(isPresented: $showingAbout) {
      iOSAboutView()
    }
    .sheet(isPresented: $showingAPIKeys) {
      iOSAPIKeysView()
    }
  }

  private var aiProvidersSection: some View {
    Section {
      Button {
        showingAPIKeys = true
      } label: {
        Label("API Keys", systemImage: "key.fill")
      }

      Picker("Default Provider", selection: $settingsManager.defaultProvider) {
        ForEach(settingsManager.availableProviders, id: \.self) { provider in
          Text(provider).tag(provider)
        }
      }

      Toggle("Stream Responses", isOn: $settingsManager.streamResponses)
    } header: {
      Text("AI Providers")
    } footer: {
      Text("Configure your AI provider settings and API keys")
    }
  }

  private var voiceSection: some View {
    Section {
      Toggle("Voice Activation", isOn: $voiceManager.isEnabled)

      if voiceManager.isEnabled {
        HStack {
          Text("Wake Word")
          Spacer()
          Text(voiceManager.wakeWord)
            .foregroundStyle(.secondary)
        }

        Toggle("Conversation Mode", isOn: $voiceManager.conversationMode)
      }
    } header: {
      Text("Voice Assistant")
    } footer: {
      if voiceManager.isEnabled {
        Text("Say '\(voiceManager.wakeWord)' to activate THEA")
      } else {
        Text("Enable voice activation to use wake word detection")
      }
    }
  }

  private var appearanceSection: some View {
    Section {
      Picker("Theme", selection: $settingsManager.theme) {
        Text("System").tag("system")
        Text("Light").tag("light")
        Text("Dark").tag("dark")
      }

      Picker("Font Size", selection: $settingsManager.fontSize) {
        Text("Small").tag("small")
        Text("Medium").tag("medium")
        Text("Large").tag("large")
      }
    } header: {
      Text("Appearance")
    }
  }

  private var privacySection: some View {
    Section {
      Toggle("iCloud Sync", isOn: $settingsManager.iCloudSyncEnabled)

      Toggle("Analytics", isOn: $settingsManager.analyticsEnabled)

      Button("Clear All Data") {
        // Will implement with confirmation dialog
      }
      .foregroundStyle(.red)
    } header: {
      Text("Privacy & Data")
    } footer: {
      Text(
        "Your conversations are stored locally and encrypted. iCloud sync is end-to-end encrypted.")
    }
  }

  private var migrationSection: some View {
    Section {
      Button {
        showingMigration = true
      } label: {
        Label("Import from Other Apps", systemImage: "arrow.down.doc.fill")
      }
    } header: {
      Text("Migration")
    } footer: {
      Text("Import your conversations from Claude, ChatGPT, or Cursor")
    }
  }

  private var aboutSection: some View {
    Section {
      Button {
        showingAbout = true
      } label: {
        Label("About THEA", systemImage: "info.circle.fill")
      }

      LabeledContent("Version", value: "1.0.0")
    } header: {
      Text("About")
    }
  }
}

// MARK: - API Keys View

struct iOSAPIKeysView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var settingsManager = SettingsManager.shared

  @State private var openAIKey = ""
  @State private var anthropicKey = ""
  @State private var googleKey = ""
  @State private var perplexityKey = ""
  @State private var groqKey = ""
  @State private var openRouterKey = ""

  var body: some View {
    NavigationStack {
      Form {
        Section {
          SecureField("API Key", text: $openAIKey)
        } header: {
          Text("OpenAI")
        } footer: {
          Text("Get your API key from platform.openai.com")
        }

        Section {
          SecureField("API Key", text: $anthropicKey)
        } header: {
          Text("Anthropic")
        } footer: {
          Text("Get your API key from console.anthropic.com")
        }

        Section {
          SecureField("API Key", text: $googleKey)
        } header: {
          Text("Google AI")
        } footer: {
          Text("Get your API key from makersuite.google.com")
        }

        Section {
          SecureField("API Key", text: $perplexityKey)
        } header: {
          Text("Perplexity")
        } footer: {
          Text("Get your API key from perplexity.ai")
        }

        Section {
          SecureField("API Key", text: $groqKey)
        } header: {
          Text("Groq")
        } footer: {
          Text("Get your API key from console.groq.com")
        }

        Section {
          SecureField("API Key", text: $openRouterKey)
        } header: {
          Text("OpenRouter")
        } footer: {
          Text("Get your API key from openrouter.ai")
        }
      }
      .navigationTitle("API Keys")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            dismiss()
          }
        }

        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            saveAPIKeys()
          }
        }
      }
      .onAppear {
        loadAPIKeys()
      }
    }
  }

  private func loadAPIKeys() {
    openAIKey = settingsManager.getAPIKey(for: "openai") ?? ""
    anthropicKey = settingsManager.getAPIKey(for: "anthropic") ?? ""
    googleKey = settingsManager.getAPIKey(for: "google") ?? ""
    perplexityKey = settingsManager.getAPIKey(for: "perplexity") ?? ""
    groqKey = settingsManager.getAPIKey(for: "groq") ?? ""
    openRouterKey = settingsManager.getAPIKey(for: "openrouter") ?? ""
  }

  private func saveAPIKeys() {
    if !openAIKey.isEmpty {
      settingsManager.setAPIKey(openAIKey, for: "openai")
    }
    if !anthropicKey.isEmpty {
      settingsManager.setAPIKey(anthropicKey, for: "anthropic")
    }
    if !googleKey.isEmpty {
      settingsManager.setAPIKey(googleKey, for: "google")
    }
    if !perplexityKey.isEmpty {
      settingsManager.setAPIKey(perplexityKey, for: "perplexity")
    }
    if !groqKey.isEmpty {
      settingsManager.setAPIKey(groqKey, for: "groq")
    }
    if !openRouterKey.isEmpty {
      settingsManager.setAPIKey(openRouterKey, for: "openrouter")
    }
    dismiss()
  }
}

// MARK: - Migration View

struct iOSMigrationView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var migrationManager = MigrationManager.shared

  @State private var selectedSource: MigrationSourceInfo?
  @State private var showingImport = false
  @State private var migrationProgress: MigrationProgress?

  var body: some View {
    NavigationStack {
      Form {
        Section {
          ForEach(migrationManager.availableSources) { sourceInfo in
            Button {
              selectedSource = sourceInfo
              showingImport = true
            } label: {
              HStack {
                Image(systemName: sourceInfo.source.metadata.icon)
                  .font(.title2)
                  .foregroundStyle(.theaPrimary)
                  .frame(width: 40)

                VStack(alignment: .leading, spacing: 4) {
                  Text(sourceInfo.source.metadata.displayName)
                    .font(.headline)

                  Text(sourceInfo.source.metadata.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                if sourceInfo.isDetected {
                  Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                }
              }
            }
            .disabled(!sourceInfo.isDetected)
          }
        } header: {
          Text("Available Sources")
        } footer: {
          Text("Import your conversations from other AI apps")
        }

        if migrationManager.isMigrating, let progress = migrationProgress {
          Section("Migration Progress") {
            VStack(spacing: 12) {
              ProgressView(value: progress.percentage, total: 100)

              HStack {
                Text(progress.message)
                  .font(.caption)
                Spacer()
                Text("\(Int(progress.percentage))%")
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }
            }
          }
        }
      }
      .navigationTitle("Import Data")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Close") {
            dismiss()
          }
          .disabled(migrationManager.isMigrating)
        }
      }
      .task {
        await migrationManager.detectSources()
      }
      .sheet(isPresented: $showingImport) {
        if let source = selectedSource {
          iOSMigrationImportView(sourceInfo: source) { progress in
            migrationProgress = progress
          }
        }
      }
    }
  }
}

struct iOSMigrationImportView: View {
  @Environment(\.dismiss) private var dismiss
  let sourceInfo: MigrationSourceInfo
  let progressHandler: (MigrationProgress) -> Void

  @State private var migrationManager = MigrationManager.shared
  @State private var stats: MigrationStats?
  @State private var isImporting = false
  @State private var importComplete = false

  var body: some View {
    NavigationStack {
      Form {
        Section {
          HStack {
            Image(systemName: sourceInfo.source.metadata.icon)
              .font(.largeTitle)
              .foregroundStyle(.theaPrimary)

            VStack(alignment: .leading, spacing: 4) {
              Text(sourceInfo.source.metadata.displayName)
                .font(.headline)

              Text(sourceInfo.source.metadata.description)
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }
          .padding(.vertical, 8)
        } header: {
          Text("Source")
        }

        if let stats = stats {
          Section("What Will Be Imported") {
            LabeledContent("Conversations", value: "\(stats.conversationCount)")
            LabeledContent("Messages", value: "\(stats.messageCount)")
            if stats.projectCount > 0 {
              LabeledContent("Projects", value: "\(stats.projectCount)")
            }
            if stats.attachmentCount > 0 {
              LabeledContent("Attachments", value: "\(stats.attachmentCount)")
            }
          }
        }

        if importComplete {
          Section {
            HStack {
              Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.title)

              Text("Import Complete")
                .font(.headline)
            }
          }
        }
      }
      .navigationTitle("Import")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            dismiss()
          }
          .disabled(isImporting)
        }

        ToolbarItem(placement: .confirmationAction) {
          Button(importComplete ? "Done" : "Import") {
            if importComplete {
              dismiss()
            } else {
              startImport()
            }
          }
          .disabled(isImporting || stats == nil)
        }
      }
      .task {
        await loadStats()
      }
    }
  }

  private func loadStats() async {
    do {
      stats = try await sourceInfo.source.getMigrationStats()
    } catch {
      print("Failed to load stats: \(error)")
    }
  }

  private func startImport() {
    isImporting = true

    Task {
      do {
        _ = try await migrationManager.migrate(
          sourceID: sourceInfo.id, progressHandler: progressHandler)
        importComplete = true
        isImporting = false
      } catch {
        isImporting = false
        print("Import failed: \(error)")
      }
    }
  }
}

// MARK: - About View

struct iOSAboutView: View {
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 32) {
          Image(systemName: "brain.head.profile")
            .font(.system(size: 80))
            .foregroundStyle(.theaPrimary)

          VStack(spacing: 8) {
            Text("THEA")
              .font(.largeTitle)
              .fontWeight(.bold)

            Text("Your AI Life Companion")
              .font(.title3)
              .foregroundStyle(.secondary)
          }

          VStack(spacing: 16) {
            InfoRow(label: "Version", value: "1.0.0")
            InfoRow(label: "Build", value: "2026.01.11")
            InfoRow(label: "Platform", value: "iOS")
          }
          .padding()
          .background(Color(uiColor: .systemGray6))
          .clipShape(RoundedRectangle(cornerRadius: 16))

          VStack(spacing: 16) {
            Text("Features")
              .font(.headline)
              .frame(maxWidth: .infinity, alignment: .leading)

            FeatureRow(
              icon: "message.fill", title: "Multi-Provider AI",
              description: "Support for OpenAI, Anthropic, Google, and more")
            FeatureRow(
              icon: "mic.fill", title: "Voice Activation",
              description: "Hands-free interaction with wake word")
            FeatureRow(
              icon: "brain.head.profile", title: "Knowledge Base",
              description: "Semantic search across your entire Mac")
            FeatureRow(
              icon: "dollarsign.circle.fill", title: "Financial Insights",
              description: "AI-powered budget recommendations")
            FeatureRow(
              icon: "terminal.fill", title: "Code Intelligence",
              description: "Multi-file context and Git integration")
            FeatureRow(
              icon: "arrow.down.doc.fill", title: "Easy Migration",
              description: "Import from Claude, ChatGPT, Cursor")
          }

          VStack(spacing: 12) {
            Text("Made with ❤️ for teathe.app")
              .font(.caption)
              .foregroundStyle(.secondary)

            Text("© 2026 THEA. All rights reserved.")
              .font(.caption2)
              .foregroundStyle(.tertiary)
          }
        }
        .padding()
      }
      .navigationTitle("About")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") {
            dismiss()
          }
        }
      }
    }
  }
}

struct InfoRow: View {
  let label: String
  let value: String

  var body: some View {
    HStack {
      Text(label)
        .foregroundStyle(.secondary)
      Spacer()
      Text(value)
        .fontWeight(.medium)
    }
  }
}

struct FeatureRow: View {
  let icon: String
  let title: String
  let description: String

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: icon)
        .font(.title2)
        .foregroundStyle(.theaPrimary)
        .frame(width: 40)

      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .font(.headline)

        Text(description)
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Spacer()
    }
  }
}

// MARK: - Voice Settings View

struct iOSVoiceSettingsView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var voiceManager = VoiceActivationManager.shared

  @State private var customWakeWord = ""

  var body: some View {
    NavigationStack {
      Form {
        Section {
          Toggle("Voice Activation", isOn: $voiceManager.isEnabled)
        } footer: {
          Text("Enable voice activation to use wake word detection")
        }

        if voiceManager.isEnabled {
          Section {
            TextField("Wake Word", text: $customWakeWord)
              .onSubmit {
                voiceManager.wakeWord = customWakeWord
              }
          } header: {
            Text("Wake Word")
          } footer: {
            Text("Say this phrase to activate THEA. Default is 'Hey Thea'")
          }

          Section {
            Toggle("Conversation Mode", isOn: $voiceManager.conversationMode)
          } footer: {
            Text("Keep listening after responding, allowing natural back-and-forth conversation")
          }

          Section {
            if voiceManager.isListening {
              HStack {
                ProgressView()
                Text("Listening...")
                  .foregroundStyle(.secondary)
              }
            } else {
              Button("Test Wake Word") {
                testWakeWord()
              }
            }
          }
        }
      }
      .navigationTitle("Voice Settings")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") {
            dismiss()
          }
        }
      }
      .onAppear {
        customWakeWord = voiceManager.wakeWord
      }
    }
  }

  func testWakeWord() {
    do {
      try voiceManager.startWakeWordDetection()
    } catch {
      print("Failed to start wake word detection: \(error)")
    }
  }
}
