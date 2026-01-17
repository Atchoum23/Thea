import Foundation
import Combine

@MainActor
final class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    // AI Provider Settings
    @Published var defaultProvider: String {
        didSet { UserDefaults.standard.set(defaultProvider, forKey: "defaultProvider") }
    }
    
    @Published var streamResponses: Bool {
        didSet { UserDefaults.standard.set(streamResponses, forKey: "streamResponses") }
    }
    
    let availableProviders: [String] = ["openai", "anthropic", "google", "perplexity", "groq", "openrouter"]
    
    // Appearance Settings
    @Published var theme: String {
        didSet { UserDefaults.standard.set(theme, forKey: "theme") }
    }
    
    @Published var fontSize: String {
        didSet { UserDefaults.standard.set(fontSize, forKey: "fontSize") }
    }
    
    // Privacy Settings
    @Published var iCloudSyncEnabled: Bool {
        didSet { UserDefaults.standard.set(iCloudSyncEnabled, forKey: "iCloudSyncEnabled") }
    }
    
    @Published var analyticsEnabled: Bool {
        didSet { UserDefaults.standard.set(analyticsEnabled, forKey: "analyticsEnabled") }
    }
    
    private init() {
        self.defaultProvider = UserDefaults.standard.string(forKey: "defaultProvider") ?? "openai"
        self.streamResponses = UserDefaults.standard.bool(forKey: "streamResponses")
        self.theme = UserDefaults.standard.string(forKey: "theme") ?? "system"
        self.fontSize = UserDefaults.standard.string(forKey: "fontSize") ?? "medium"
        self.iCloudSyncEnabled = UserDefaults.standard.bool(forKey: "iCloudSyncEnabled")
        self.analyticsEnabled = UserDefaults.standard.bool(forKey: "analyticsEnabled")
    }
    
    // API Key Management (stored in UserDefaults temporarily - should use Keychain in production)
    func getAPIKey(for provider: String) -> String? {
        UserDefaults.standard.string(forKey: "apiKey_\(provider)")
    }
    
    func setAPIKey(_ key: String, for provider: String) {
        UserDefaults.standard.set(key, forKey: "apiKey_\(provider)")
    }
    
    func deleteAPIKey(for provider: String) {
        UserDefaults.standard.removeObject(forKey: "apiKey_\(provider)")
    }
}
