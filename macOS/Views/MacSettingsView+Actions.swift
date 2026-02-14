@preconcurrency import SwiftData
import SwiftUI

// MARK: - MacSettingsView Action Helpers

extension MacSettingsView {
    func loadAPIKeysIfNeeded() {
        guard !apiKeysLoaded else { return }
        apiKeysLoaded = true
        openAIKey = settingsManager.getAPIKey(for: "openai") ?? ""
        anthropicKey = settingsManager.getAPIKey(for: "anthropic") ?? ""
        googleKey = settingsManager.getAPIKey(for: "google") ?? ""
        perplexityKey = settingsManager.getAPIKey(for: "perplexity") ?? ""
        groqKey = settingsManager.getAPIKey(for: "groq") ?? ""
        openRouterKey = settingsManager.getAPIKey(for: "openrouter") ?? ""
    }

    func apiKeyField(label: String, key: Binding<String>, provider: String) -> some View {
        HStack {
            Text(label)
                .frame(width: 100, alignment: .leading)

            SecureField("API Key", text: key)
                .textFieldStyle(.roundedBorder)
                .onChange(of: key.wrappedValue) { _, newValue in
                    if !newValue.isEmpty {
                        settingsManager.setAPIKey(newValue, for: provider)
                    }
                }

            if !key.wrappedValue.isEmpty {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
    }

    func exportAllData() {
        let panel = NSSavePanel()
        let dateString = ISO8601DateFormatter().string(from: Date())
        panel.nameFieldStringValue = "thea-export-\(dateString).json"
        panel.allowedContentTypes = [.json]

        let modelContext = self.modelContext
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }

            Task { @MainActor in
                do {
                    let conversations = try modelContext.fetch(FetchDescriptor<Conversation>())
                    let messages = try modelContext.fetch(FetchDescriptor<Message>())
                    let projects = try modelContext.fetch(FetchDescriptor<Project>())

                    let export: [String: Any] = [
                        "exportDate": dateString,
                        "version": AppConfiguration.AppInfo.version,
                        "conversations": conversations.map { conv in
                            [
                                "id": conv.id.uuidString,
                                "title": conv.title,
                                "createdAt": ISO8601DateFormatter().string(from: conv.createdAt),
                                "isArchived": conv.isArchived
                            ] as [String: Any]
                        },
                        "messages": messages.map { msg in
                            [
                                "id": msg.id.uuidString,
                                "conversationID": msg.conversationID.uuidString,
                                "role": msg.role,
                                "content": msg.content.textValue,
                                "timestamp": ISO8601DateFormatter().string(from: msg.timestamp)
                            ] as [String: Any]
                        },
                        "projects": projects.map { proj in
                            [
                                "id": proj.id.uuidString,
                                "title": proj.title,
                                "createdAt": ISO8601DateFormatter().string(from: proj.createdAt)
                            ] as [String: Any]
                        },
                        "settings": [
                            "theme": SettingsManager.shared.theme,
                            "fontSize": SettingsManager.shared.fontSize,
                            "messageDensity": SettingsManager.shared.messageDensity,
                            "defaultProvider": SettingsManager.shared.defaultProvider
                        ]
                    ]

                    let jsonData = try JSONSerialization.data(withJSONObject: export, options: [.prettyPrinted, .sortedKeys])
                    try jsonData.write(to: url)
                } catch {
                    let errorAlert = NSAlert()
                    errorAlert.messageText = "Export Failed"
                    errorAlert.informativeText = error.localizedDescription
                    errorAlert.alertStyle = .warning
                    errorAlert.runModal()
                }
            }
        }
    }

    func clearAllData() {
        let alert = NSAlert()
        alert.messageText = "Clear All Data?"
        alert.informativeText = "This will permanently delete all conversations, projects, and messages. Settings will be reset to defaults. This action cannot be undone."
        alert.alertStyle = .critical
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Clear All Data")

        guard alert.runModal() == .alertSecondButtonReturn else { return }

        do {
            try modelContext.delete(model: Message.self)
            try modelContext.delete(model: Conversation.self)
            try modelContext.delete(model: Project.self)
            try modelContext.save()
            settingsManager.resetToDefaults()
            AppConfiguration.shared.resetAllToDefaults()
        } catch {
            let errorAlert = NSAlert()
            errorAlert.messageText = "Clear Failed"
            errorAlert.informativeText = error.localizedDescription
            errorAlert.alertStyle = .warning
            errorAlert.runModal()
        }
    }

    func clearCache() {
        URLCache.shared.removeAllCachedResponses()

        if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let cacheDir = appSupport.appendingPathComponent("Thea/Cache")
            try? FileManager.default.removeItem(at: cacheDir)
        }

        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("Thea")
        try? FileManager.default.removeItem(at: tempDir)

        let successAlert = NSAlert()
        successAlert.messageText = "Cache Cleared"
        successAlert.informativeText = "All cached data has been removed."
        successAlert.alertStyle = .informational
        successAlert.runModal()
    }

    func calculateCacheSize() async -> String {
        let fm = FileManager.default
        var totalBytes = Int64(URLCache.shared.currentDiskUsage)

        if let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let cacheDir = appSupport.appendingPathComponent("Thea/Cache")
            totalBytes += directorySize(at: cacheDir)
        }

        if let cachesDir = fm.urls(for: .cachesDirectory, in: .userDomainMask).first {
            let theaCaches = cachesDir.appendingPathComponent(AppConfiguration.AppInfo.bundleIdentifier)
            totalBytes += directorySize(at: theaCaches)
        }

        let tempDir = fm.temporaryDirectory.appendingPathComponent("Thea")
        totalBytes += directorySize(at: tempDir)

        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalBytes)
    }

    func directorySize(at url: URL) -> Int64 {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles]) else {
            return 0
        }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                total += Int64(size)
            }
        }
        return total
    }
}
