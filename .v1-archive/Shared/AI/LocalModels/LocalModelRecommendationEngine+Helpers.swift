//
//  LocalModelRecommendationEngine+Helpers.swift
//  Thea
//
//  Helper methods for model recommendation engine
//  Extracted from LocalModelRecommendationEngine.swift for better code organization
//

import Foundation

// MARK: - Monitoring

extension LocalModelRecommendationEngine {
    func startMonitoring() {
        guard configuration.enableAutoDiscovery else { return }

        monitoringTask?.cancel()
        monitoringTask = Task {
            while !Task.isCancelled {
                let intervalSeconds = configuration.scanIntervalHours * 3600
                try? await Task.sleep(for: .seconds(intervalSeconds))

                await scanInstalledModels()
                await discoverAvailableModels()
                await generateRecommendations()
            }
        }
    }

    func stopMonitoring() {
        monitoringTask?.cancel()
        monitoringTask = nil
    }
}

// MARK: - User Profile

extension LocalModelRecommendationEngine {
    /// Record user activity to improve recommendations
    func recordUserActivity(taskType: TaskType) {
        userProfile.recordTask(taskType)
        saveUserProfile()

        // Regenerate recommendations periodically
        Task {
            await generateRecommendations()
        }
    }
}

// MARK: - Configuration

extension LocalModelRecommendationEngine {
    func updateConfiguration(_ config: Configuration) {
        configuration = config
        saveConfiguration()

        if config.enableAutoDiscovery {
            startMonitoring()
        } else {
            stopMonitoring()
        }
    }

    func loadConfiguration() {
        if let data = UserDefaults.standard.data(forKey: "LocalModelRecommendation.config"),
           let config = try? JSONDecoder().decode(Configuration.self, from: data) {
            configuration = config
        }
    }

    func saveConfiguration() {
        if let data = try? JSONEncoder().encode(configuration) {
            UserDefaults.standard.set(data, forKey: "LocalModelRecommendation.config")
        }
    }

    func loadUserProfile() {
        if let data = UserDefaults.standard.data(forKey: "LocalModelRecommendation.userProfile"),
           let profile = try? JSONDecoder().decode(UserUsageProfile.self, from: data) {
            userProfile = profile
        }
    }

    func saveUserProfile() {
        if let data = try? JSONEncoder().encode(userProfile) {
            UserDefaults.standard.set(data, forKey: "LocalModelRecommendation.userProfile")
        }
    }

    func saveLastScanDate() {
        UserDefaults.standard.set(lastScanDate, forKey: "LocalModelRecommendation.lastScan")
    }
}

// MARK: - Helper Methods

extension LocalModelRecommendationEngine {
    func calculateDirectorySize(url: URL) -> UInt64 {
        let fileManager = FileManager.default
        var totalSize: UInt64 = 0

        if let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) {
            for case let fileURL as URL in enumerator {
                if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    totalSize += UInt64(size)
                }
            }
        }

        return totalSize
    }

    func detectQuantization(_ url: URL) -> String? {
        let name = url.lastPathComponent.lowercased()
        if name.contains("4bit") || name.contains("q4") { return "4-bit" }
        if name.contains("8bit") || name.contains("q8") { return "8-bit" }
        if name.contains("fp16") { return "FP16" }
        return nil
    }

    func detectCapabilities(_ url: URL) -> [LocalModelCapability] {
        let name = url.lastPathComponent.lowercased()
        var capabilities: [LocalModelCapability] = [.chat]

        if name.contains("code") || name.contains("coder") {
            capabilities.append(.code)
        }
        if name.contains("instruct") {
            capabilities.append(.reasoning)
        }
        if name.contains("vision") || name.contains("vlm") {
            capabilities.append(.vision)
        }

        return capabilities
    }

    func parseOllamaCapabilities(_ model: OllamaModel) -> [LocalModelCapability] {
        var caps: [LocalModelCapability] = [.chat]
        let name = model.name.lowercased()

        if name.contains("code") { caps.append(.code) }
        if name.contains("vision") { caps.append(.vision) }
        if model.details?.families?.contains("llama") == true { caps.append(.reasoning) }

        return caps
    }

    func extractModelName(from id: String) -> String {
        // Extract clean name from "mlx-community/Llama-3.2-1B-Instruct-4bit"
        let parts = id.split(separator: "/")
        let name = parts.last.map(String.init) ?? id
        return name
            .replacingOccurrences(of: "-4bit", with: "")
            .replacingOccurrences(of: "-8bit", with: "")
            .replacingOccurrences(of: "-", with: " ")
    }

    func estimateModelSize(_ model: HuggingFaceModel) -> Double {
        // Estimate based on name hints or default
        let name = (model.modelId ?? "").lowercased()
        if name.contains("1b") { return 1.5 }
        if name.contains("3b") { return 3.5 }
        if name.contains("7b") { return 4.5 }
        if name.contains("8b") { return 5.0 }
        if name.contains("13b") { return 8.0 }
        return 4.0 // Default estimate
    }

    func detectQuantizationFromName(_ name: String) -> String? {
        let lower = name.lowercased()
        if lower.contains("4bit") || lower.contains("q4") { return "4-bit" }
        if lower.contains("8bit") || lower.contains("q8") { return "8-bit" }
        if lower.contains("fp16") { return "FP16" }
        return nil
    }

    func detectCapabilitiesFromTags(_ tags: [String]) -> [LocalModelCapability] {
        var caps: [LocalModelCapability] = []

        for tag in tags {
            let lower = tag.lowercased()
            if lower.contains("text-generation") || lower.contains("conversational") {
                caps.append(.chat)
            }
            if lower.contains("code") {
                caps.append(.code)
            }
            if lower.contains("vision") || lower.contains("image") {
                caps.append(.vision)
            }
        }

        if caps.isEmpty { caps.append(.chat) }
        return caps
    }

    func formatNumber(_ num: Int) -> String {
        if num >= 1000000 {
            return String(format: "%.1fM", Double(num) / 1000000)
        } else if num >= 1000 {
            return String(format: "%.1fK", Double(num) / 1000)
        }
        return "\(num)"
    }
}
