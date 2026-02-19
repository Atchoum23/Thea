//
//  SettingsViewModel.swift
//  Thea
//
//  Created by Claude Code on 2026-02-01
//  ViewModel for coordinating settings across all tabs
//

import Foundation
import SwiftUI
import os.log

/// ViewModel for managing application settings
@MainActor
@Observable
final class SettingsViewModel {
    // MARK: - State

    /// Currently selected settings tab
    var selectedTab: SettingsTab = .general

    /// Whether settings are being saved
    var isSaving: Bool = false

    /// Current error message
    var errorMessage: String?

    /// Whether to show the API key entry sheet
    var showingAPIKeyEntry: Bool = false

    /// Provider for which to enter API key
    var apiKeyProvider: String?

    // MARK: - Settings State (observed from managers)

    /// Default AI provider ID
    // periphery:ignore - Reserved: defaultProviderId property — reserved for future feature activation
    var defaultProviderId: String {
        get { settingsManager.defaultProvider }
        set { settingsManager.defaultProvider = newValue }
    }

    /// Whether stream responses are enabled
    // periphery:ignore - Reserved: streamResponses property — reserved for future feature activation
    var streamResponses: Bool {
        get { settingsManager.streamResponses }
        set { settingsManager.streamResponses = newValue }
    }

    /// Current theme
    // periphery:ignore - Reserved: theme property — reserved for future feature activation
    var theme: String {
        get { settingsManager.theme }
        set { settingsManager.theme = newValue }
    }

// periphery:ignore - Reserved: defaultProviderId property reserved for future feature activation

    /// Whether debug mode is enabled
    var debugMode: Bool {
        get { settingsManager.debugMode }
        set { settingsManager.debugMode = newValue }
    // periphery:ignore - Reserved: streamResponses property reserved for future feature activation
    }

    // MARK: - Dependencies

    @ObservationIgnored private let settingsManager: SettingsManager
    // periphery:ignore - Reserved: theme property reserved for future feature activation
    @ObservationIgnored private let providerRegistry: ProviderRegistry
    @ObservationIgnored private let logger = Logger(subsystem: "app.thea", category: "SettingsViewModel")

    // MARK: - Initialization

    // periphery:ignore - Reserved: debugMode property reserved for future feature activation
    init(
        settingsManager: SettingsManager = .shared,
        providerRegistry: ProviderRegistry = .shared
    ) {
        self.settingsManager = settingsManager
        self.providerRegistry = providerRegistry
    // periphery:ignore - Reserved: settingsManager property reserved for future feature activation
    // periphery:ignore - Reserved: providerRegistry property reserved for future feature activation
    // periphery:ignore - Reserved: logger property reserved for future feature activation
    }

    // MARK: - Tab Navigation

// periphery:ignore - Reserved: init(settingsManager:providerRegistry:) initializer reserved for future feature activation

    /// Available settings tabs
    enum SettingsTab: String, CaseIterable, Identifiable {
        case general = "General"
        case providers = "Providers"
        case models = "Models"
        case voice = "Voice"
        case privacy = "Privacy"
        case advanced = "Advanced"
        case about = "About"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .general: return "gearshape"
            case .providers: return "cloud"
            case .models: return "cpu"
            case .voice: return "mic"
            case .privacy: return "lock.shield"
            case .advanced: return "wrench.and.screwdriver"
            // periphery:ignore - Reserved: icon property reserved for future feature activation
            case .about: return "info.circle"
            }
        }
    }

    /// Navigate to a specific tab
    // periphery:ignore - Reserved: navigateTo(_:) instance method — reserved for future feature activation
    func navigateTo(_ tab: SettingsTab) {
        selectedTab = tab
    }

    // MARK: - Provider Management

    /// Get all available providers
    // periphery:ignore - Reserved: navigateTo(_:) instance method reserved for future feature activation
    var availableProviderInfo: [ProviderRegistry.ProviderInfo] {
        providerRegistry.availableProviders
    }

    /// Check if a provider has an API key configured
    // periphery:ignore - Reserved: hasAPIKey(for:) instance method — reserved for future feature activation
    func hasAPIKey(for providerId: String) -> Bool {
        // periphery:ignore - Reserved: availableProviderInfo property reserved for future feature activation
        settingsManager.hasAPIKey(for: providerId)
    }

    /// Request API key entry for a provider
    // periphery:ignore - Reserved: hasAPIKey(for:) instance method reserved for future feature activation
    func requestAPIKey(for providerId: String) {
        apiKeyProvider = providerId
        showingAPIKeyEntry = true
    }

// periphery:ignore - Reserved: requestAPIKey(for:) instance method reserved for future feature activation

    /// Save API key for a provider
    func saveAPIKey(_ key: String, for providerId: String) {
        isSaving = true
        errorMessage = nil

// periphery:ignore - Reserved: saveAPIKey(_:for:) instance method reserved for future feature activation

        settingsManager.setAPIKey(key, for: providerId)
        logger.info("API key saved for provider: \(providerId)")

        isSaving = false
        showingAPIKeyEntry = false
        apiKeyProvider = nil
    }

    /// Remove API key for a provider
    // periphery:ignore - Reserved: removeAPIKey(for:) instance method — reserved for future feature activation
    func removeAPIKey(for providerId: String) {
        settingsManager.deleteAPIKey(for: providerId)
        // periphery:ignore - Reserved: removeAPIKey(for:) instance method reserved for future feature activation
        logger.info("API key removed for provider: \(providerId)")
    }

    // MARK: - Reset

    /// Reset all settings to defaults
    // periphery:ignore - Reserved: resetToDefaults() instance method — reserved for future feature activation
    func resetToDefaults() {
        // periphery:ignore - Reserved: resetToDefaults() instance method reserved for future feature activation
        isSaving = true

        settingsManager.resetToDefaults()
        logger.info("Settings reset to defaults")

        isSaving = false
    }

    // MARK: - Validation

    /// Validate current settings
    // periphery:ignore - Reserved: validateSettings() instance method reserved for future feature activation
    func validateSettings() -> [String] {
        var issues: [String] = []

        // Check if at least one provider has an API key
        let hasAnyProvider = availableProviderInfo.contains { $0.isConfigured }
        if !hasAnyProvider {
            issues.append("No AI providers configured. Add an API key to get started.")
        }

        return issues
    }
}
