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
    var defaultProviderId: String {
        get { settingsManager.defaultProvider }
        set { settingsManager.defaultProvider = newValue }
    }

    /// Whether stream responses are enabled
    var streamResponses: Bool {
        get { settingsManager.streamResponses }
        set { settingsManager.streamResponses = newValue }
    }

    /// Current theme
    var theme: String {
        get { settingsManager.theme }
        set { settingsManager.theme = newValue }
    }

    /// Whether debug mode is enabled
    var debugMode: Bool {
        get { settingsManager.debugMode }
        set { settingsManager.debugMode = newValue }
    }

    // MARK: - Dependencies

    @ObservationIgnored private let settingsManager: SettingsManager
    @ObservationIgnored private let providerRegistry: ProviderRegistry
    @ObservationIgnored private let logger = Logger(subsystem: "app.thea", category: "SettingsViewModel")

    // MARK: - Initialization

    init(
        settingsManager: SettingsManager = .shared,
        providerRegistry: ProviderRegistry = .shared
    ) {
        self.settingsManager = settingsManager
        self.providerRegistry = providerRegistry
    }

    // MARK: - Tab Navigation

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
            case .about: return "info.circle"
            }
        }
    }

    /// Navigate to a specific tab
    func navigateTo(_ tab: SettingsTab) {
        selectedTab = tab
    }

    // MARK: - Provider Management

    /// Get all available providers
    var availableProviderInfo: [any AIProvider] {
        providerRegistry.availableProviders
    }

    /// Check if a provider has an API key configured
    func hasAPIKey(for providerId: String) -> Bool {
        settingsManager.hasAPIKey(for: providerId)
    }

    /// Request API key entry for a provider
    func requestAPIKey(for providerId: String) {
        apiKeyProvider = providerId
        showingAPIKeyEntry = true
    }

    /// Save API key for a provider
    func saveAPIKey(_ key: String, for providerId: String) {
        isSaving = true
        errorMessage = nil

        settingsManager.setAPIKey(key, for: providerId)
        logger.info("API key saved for provider: \(providerId)")

        isSaving = false
        showingAPIKeyEntry = false
        apiKeyProvider = nil
    }

    /// Remove API key for a provider
    func removeAPIKey(for providerId: String) {
        settingsManager.deleteAPIKey(for: providerId)
        logger.info("API key removed for provider: \(providerId)")
    }

    // MARK: - Reset

    /// Reset all settings to defaults
    func resetToDefaults() {
        isSaving = true

        settingsManager.resetToDefaults()
        logger.info("Settings reset to defaults")

        isSaving = false
    }

    // MARK: - Validation

    /// Validate current settings
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
