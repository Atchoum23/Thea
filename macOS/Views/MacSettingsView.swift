import SwiftUI

struct MacSettingsView: View {
  @StateObject private var settingsManager = SettingsManager.shared
  @State private var voiceManager = VoiceActivationManager.shared
  @StateObject private var cloudSyncManager = CloudSyncManager.shared

  @State private var selectedTab: SettingsTab = .general

  enum SettingsTab: String, CaseIterable {
    case general = "General"
    case aiProviders = "AI Providers"
    case voice = "Voice"
    case sync = "Sync"
    case privacy = "Privacy"
    case advanced = "Advanced"

    var icon: String {
      switch self {
      case .general: return "gear"
      case .aiProviders: return "brain.head.profile"
      case .voice: return "mic.fill"
      case .sync: return "icloud.fill"
      case .privacy: return "lock.fill"
      case .advanced: return "slider.horizontal.3"
      }
    }
  }

  var body: some View {
    TabView(selection: $selectedTab) {
      ForEach(SettingsTab.allCases, id: \.self) { tab in
        viewForTab(tab)
          .tabItem {
            Label(tab.rawValue, systemImage: tab.icon)
          }
          .tag(tab)
      }
    }
    .frame(width: 600, height: 500)
  }

  @ViewBuilder
  private func viewForTab(_ tab: SettingsTab) -> some View {
    switch tab {
    case .general:
      generalSettings
    case .aiProviders:
      aiProviderSettings
    case .voice:
      voiceSettings
    case .sync:
      syncSettings
    case .privacy:
      privacySettings
    case .advanced:
      advancedSettings
    }
  }

  // MARK: - General Settings

  private var generalSettings: some View {
    Form {
      Section("Appearance") {
        Picker("Theme", selection: $settingsManager.theme) {
          Text("System").tag("system")
          Text("Light").tag("light")
          Text("Dark").tag("dark")
        }
        .pickerStyle(.segmented)

        Picker("Font Size", selection: $settingsManager.fontSize) {
          Text("Small").tag("small")
          Text("Medium").tag("medium")
          Text("Large").tag("large")
        }
        .pickerStyle(.segmented)
      }

      Section("Behavior") {
        Toggle("Launch at Login", isOn: $settingsManager.launchAtLogin)
        Toggle("Show in Menu Bar", isOn: $settingsManager.showInMenuBar)
        Toggle("Enable Notifications", isOn: $settingsManager.notificationsEnabled)
      }
    }
    .formStyle(.grouped)
    .padding()
  }

  // MARK: - AI Provider Settings

  private var aiProviderSettings: some View {
    Form {
      Section("Default Provider") {
        Picker("Provider", selection: $settingsManager.defaultProvider) {
          ForEach(settingsManager.availableProviders, id: \.self) { provider in
            Text(provider).tag(provider)
          }
        }

        Toggle("Stream Responses", isOn: $settingsManager.streamResponses)
      }

      Section("API Keys") {
        apiKeyField(provider: "OpenAI", key: "openai")
        apiKeyField(provider: "Anthropic", key: "anthropic")
        apiKeyField(provider: "Google AI", key: "google")
        apiKeyField(provider: "Perplexity", key: "perplexity")
        apiKeyField(provider: "Groq", key: "groq")
        apiKeyField(provider: "OpenRouter", key: "openrouter")
      }
    }
    .formStyle(.grouped)
    .padding()
  }

  private func apiKeyField(provider: String, key: String) -> some View {
    HStack {
      Text(provider)
        .frame(width: 100, alignment: .leading)

      SecureField(
        "API Key",
        text: Binding(
          get: { settingsManager.getAPIKey(for: key) ?? "" },
          set: { newValue in
            if !newValue.isEmpty {
              settingsManager.setAPIKey(newValue, for: key)
            }
          }
        )
      )
      .textFieldStyle(.roundedBorder)
    }
  }

  // MARK: - Voice Settings

  private var voiceSettings: some View {
    Form {
      Section("Voice Activation") {
        Toggle("Enable Voice Activation", isOn: $voiceManager.isEnabled)

        if voiceManager.isEnabled {
          HStack {
            Text("Wake Word")
            TextField("Wake Word", text: $voiceManager.wakeWord)
              .textFieldStyle(.roundedBorder)
          }

          Toggle("Conversation Mode", isOn: $voiceManager.conversationMode)

          Button("Test Wake Word Detection") {
            try? voiceManager.startWakeWordDetection()
          }

          if voiceManager.isListening {
            HStack {
              ProgressView()
                .scaleEffect(0.8)
              Text("Listening for '\(voiceManager.wakeWord)'...")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }
        }
      }

      Section("Text-to-Speech") {
        Toggle("Read Responses Aloud", isOn: $settingsManager.readResponsesAloud)

        if settingsManager.readResponsesAloud {
          Picker("Voice", selection: $settingsManager.selectedVoice) {
            Text("Default").tag("default")
            Text("Samantha").tag("samantha")
            Text("Alex").tag("alex")
          }
        }
      }
    }
    .formStyle(.grouped)
    .padding()
  }

  // MARK: - Sync Settings

  private var syncSettings: some View {
    Form {
      Section("iCloud Sync") {
        Toggle("Enable iCloud Sync", isOn: $settingsManager.iCloudSyncEnabled)

        if settingsManager.iCloudSyncEnabled {
          HStack {
            Text("Status")
            Spacer()
            if cloudSyncManager.isSyncing {
              ProgressView()
                .scaleEffect(0.7)
              Text("Syncing...")
                .font(.caption)
                .foregroundStyle(.secondary)
            } else if let lastSync = cloudSyncManager.lastSyncDate {
              Text("Last synced \(lastSync, style: .relative)")
                .font(.caption)
                .foregroundStyle(.secondary)
            } else {
              Text("Never synced")
                .font(.caption)
                .foregroundStyle(.tertiary)
            }
          }

          HStack {
            Button("Sync Now") {
              Task {
                try? await cloudSyncManager.performFullSync()
              }
            }
            .disabled(cloudSyncManager.isSyncing)

            Spacer()
          }

          if !cloudSyncManager.syncErrors.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
              Text("Recent Errors")
                .font(.caption)
                .foregroundStyle(.secondary)

              ForEach(cloudSyncManager.syncErrors.prefix(3)) { error in
                Text(error.errorDescription)
                  .font(.caption)
                  .foregroundStyle(.red)
              }
            }
          }
        }
      }

      Section("Handoff") {
        Toggle("Enable Handoff", isOn: $settingsManager.handoffEnabled)

        Text("Continue conversations seamlessly across your Apple devices")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .formStyle(.grouped)
    .padding()
  }

  // MARK: - Privacy Settings

  private var privacySettings: some View {
    Form {
      Section("Data Collection") {
        Toggle("Analytics", isOn: $settingsManager.analyticsEnabled)

        Text("Help improve THEA by sharing anonymous usage data")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Section("Data Management") {
        Button("Export All Data") {
          exportAllData()
        }

        Button("Clear All Data") {
          clearAllData()
        }
        .foregroundStyle(.red)
      }

      Section("Privacy Information") {
        Text(
          "Your conversations are stored locally on your device and synced via iCloud when enabled. All data is encrypted end-to-end."
        )
        .font(.caption)
        .foregroundStyle(.secondary)
      }
    }
    .formStyle(.grouped)
    .padding()
  }

  // MARK: - Advanced Settings

  private var advancedSettings: some View {
    Form {
      Section("Development") {
        Toggle("Enable Debug Mode", isOn: $settingsManager.debugMode)
        Toggle("Show Performance Metrics", isOn: $settingsManager.showPerformanceMetrics)
      }

      Section("Experimental Features") {
        Toggle("Enable Beta Features", isOn: $settingsManager.betaFeaturesEnabled)

        Text("Beta features may be unstable and are subject to change")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Section("Cache") {
        HStack {
          Text("Cache Size")
          Spacer()
          Text("~50 MB")
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        Button("Clear Cache") {
          clearCache()
        }
      }
    }
    .formStyle(.grouped)
    .padding()
  }

  // MARK: - Actions

  private func exportAllData() {
    let panel = NSSavePanel()
    panel.nameFieldStringValue = "thea-export-\(Date().ISO8601Format()).json"
    panel.allowedContentTypes = [.json]

    panel.begin { response in
      if response == .OK, let url = panel.url {
        // Export logic here
        print("Exporting data to: \(url)")
      }
    }
  }

  private func clearAllData() {
    let alert = NSAlert()
    alert.messageText = "Clear All Data?"
    alert.informativeText =
      "This will permanently delete all conversations, projects, and settings. This action cannot be undone."
    alert.alertStyle = .critical
    alert.addButton(withTitle: "Cancel")
    alert.addButton(withTitle: "Clear All Data")

    if alert.runModal() == .alertSecondButtonReturn {
      // Clear all data logic here
      print("Clearing all data")
    }
  }

  private func clearCache() {
    // Clear cache logic here
    print("Clearing cache")
  }
}

// MARK: - Settings Manager Extensions

extension SettingsManager {
  var launchAtLogin: Bool {
    get { UserDefaults.standard.bool(forKey: "launchAtLogin") }
    set { UserDefaults.standard.set(newValue, forKey: "launchAtLogin") }
  }

  var showInMenuBar: Bool {
    get { UserDefaults.standard.bool(forKey: "showInMenuBar") }
    set { UserDefaults.standard.set(newValue, forKey: "showInMenuBar") }
  }

  var notificationsEnabled: Bool {
    get { UserDefaults.standard.bool(forKey: "notificationsEnabled") }
    set { UserDefaults.standard.set(newValue, forKey: "notificationsEnabled") }
  }

  var readResponsesAloud: Bool {
    get { UserDefaults.standard.bool(forKey: "readResponsesAloud") }
    set { UserDefaults.standard.set(newValue, forKey: "readResponsesAloud") }
  }

  var selectedVoice: String {
    get { UserDefaults.standard.string(forKey: "selectedVoice") ?? "default" }
    set { UserDefaults.standard.set(newValue, forKey: "selectedVoice") }
  }

  var handoffEnabled: Bool {
    get { UserDefaults.standard.bool(forKey: "handoffEnabled") }
    set { UserDefaults.standard.set(newValue, forKey: "handoffEnabled") }
  }

  var debugMode: Bool {
    get { UserDefaults.standard.bool(forKey: "debugMode") }
    set { UserDefaults.standard.set(newValue, forKey: "debugMode") }
  }

  var showPerformanceMetrics: Bool {
    get { UserDefaults.standard.bool(forKey: "showPerformanceMetrics") }
    set { UserDefaults.standard.set(newValue, forKey: "showPerformanceMetrics") }
  }

  var betaFeaturesEnabled: Bool {
    get { UserDefaults.standard.bool(forKey: "betaFeaturesEnabled") }
    set { UserDefaults.standard.set(newValue, forKey: "betaFeaturesEnabled") }
  }
}
