// LocalModelRecommendationEngine.swift
// AI-powered local model monitoring, discovery, and recommendation system
// Features system-aware intelligent defaults based on hardware capabilities

import Foundation
#if os(macOS)
import IOKit.ps
#elseif os(iOS) || os(watchOS) || os(tvOS)
import UIKit
#endif

// MARK: - Local Model Recommendation Engine

@MainActor
@Observable
final class LocalModelRecommendationEngine {
    static let shared = LocalModelRecommendationEngine()

    // MARK: - State

    var availableModels: [DiscoveredModel] = []
    var installedModels: [InstalledLocalModel] = []
    var recommendations: [ModelRecommendation] = []
    var isScanning = false
    var lastScanDate: Date?
    var userProfile = UserUsageProfile()

    // Configuration - AI-powered with system-aware defaults
    struct Configuration: Codable, Sendable {
        var enableAutoDiscovery = true
        var scanIntervalHours: Int = 24
        var enableProactiveRecommendations = true
        var maxRecommendations = 5
        var preferredQuantization: String = "4bit"
        var maxModelSizeGB: Double = 8.0 // Will be overridden by system-aware calculation
        var preferredSources: [String] = ["mlx-community", "huggingface"]
        var enableAIPoweredScoring = true
        var autoAdjustToSystemCapabilities = true
        var performanceTier: PerformanceTier = .auto

        /// Model performance tiers based on system capabilities
        enum PerformanceTier: String, Codable, Sendable, CaseIterable {
            case auto          // AI determines best tier
            case ultralight    // 1-3GB models (8GB RAM systems)
            case light         // 3-5GB models (16GB RAM systems)
            case standard      // 5-10GB models (32GB RAM systems)
            case performance   // 10-20GB models (64GB RAM systems)
            case extreme       // 20-50GB+ models (128GB+ RAM systems)
            case unlimited     // No size restrictions (256GB+ systems)

            var displayName: String {
                switch self {
                case .auto: "Auto (AI-Selected)"
                case .ultralight: "Ultra Light (1-3GB)"
                case .light: "Light (3-5GB)"
                case .standard: "Standard (5-10GB)"
                case .performance: "Performance (10-20GB)"
                case .extreme: "Extreme (20-50GB)"
                case .unlimited: "Unlimited (50GB+)"
                }
            }

            var maxModelSizeGB: Double {
                switch self {
                case .auto: 0 // Calculated dynamically
                case .ultralight: 3.0
                case .light: 5.0
                case .standard: 10.0
                case .performance: 20.0
                case .extreme: 50.0
                case .unlimited: Double.greatestFiniteMagnitude // No limit
                }
            }
        }
    }

    var configuration = Configuration()
    var systemProfile: SystemHardwareProfile?
    var monitoringTask: Task<Void, Never>?

    // MARK: - Initialization

    private init() {
        loadConfiguration()
        loadUserProfile()
        Task {
            await detectSystemHardware()
            await applySystemAwareDefaults()
            await initialScan()
            startMonitoring()
        }
    }
}
