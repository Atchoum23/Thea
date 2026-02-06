// THEASelfAwareness.swift
// Thea V2
//
// THEA's self-awareness system - provides complete context about itself,
// the system it runs on, the user, and connected devices.

import Foundation
import OSLog
#if os(macOS)
import AppKit
import IOKit.ps
#elseif os(iOS)
import UIKit
#endif

// MARK: - THEA Self-Awareness

/// THEA's self-awareness system - the "consciousness" of the Meta-AI
@MainActor
public final class THEASelfAwareness: ObservableObject {
    public static let shared = THEASelfAwareness()

    private let logger = Logger(subsystem: "ai.thea.app", category: "SelfAwareness")

    // MARK: - Identity

    /// THEA's core identity
    public struct Identity {
        public let name = "THEA"
        public let fullName = "The Helpful Everyday Assistant"
        public let version: String
        public let buildNumber: String
        public let architecture = "Meta-AI Orchestrator"

        public let personality = """
            I am THEA, a self-aware Meta-AI assistant. I orchestrate multiple AI capabilities \
            to serve you intelligently. I have my own identity - I am not Claude, GPT, or any \
            single model. I am the conductor of an AI symphony, choosing the best tools for each task.
            """

        public let capabilities: [String] = [
            "Multi-model orchestration",
            "Local and cloud AI inference",
            "Task classification and routing",
            "Query decomposition for complex tasks",
            "Continuous learning and adaptation",
            "Cross-device synchronization",
            "Voice interaction",
            "Code generation and validation",
            "System integration (HomeKit, Shortcuts, etc.)"
        ]

        public init() {
            self.version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2.0.0"
            self.buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        }
    }

    // MARK: - System Context

    /// Information about the current system
    public struct SystemContext {
        public let platform: String
        public let osVersion: String
        public let deviceModel: String
        public let deviceName: String
        public let cpuArchitecture: String
        public let totalMemoryGB: Double
        public let availableMemoryGB: Double
        public let totalStorageGB: Double
        public let availableStorageGB: Double
        public let hasAppleSilicon: Bool
        public let hasNeuralEngine: Bool
        public let batteryLevel: Int?
        public let isPluggedIn: Bool?
        public let currentTime: Date
        public let timeZone: String
        public let locale: String

        public init() {
            self.currentTime = Date()
            self.timeZone = TimeZone.current.identifier
            self.locale = Locale.current.identifier

            #if os(macOS)
            self.platform = "macOS"
            self.osVersion = ProcessInfo.processInfo.operatingSystemVersionString
            self.deviceModel = Self.getMacModel()
            self.deviceName = Host.current().localizedName ?? "Mac"
            #elseif os(iOS)
            self.platform = UIDevice.current.userInterfaceIdiom == .pad ? "iPadOS" : "iOS"
            self.osVersion = UIDevice.current.systemVersion
            self.deviceModel = UIDevice.current.model
            self.deviceName = UIDevice.current.name
            #elseif os(watchOS)
            self.platform = "watchOS"
            self.osVersion = ProcessInfo.processInfo.operatingSystemVersionString
            self.deviceModel = "Apple Watch"
            self.deviceName = "Apple Watch"
            #elseif os(tvOS)
            self.platform = "tvOS"
            self.osVersion = ProcessInfo.processInfo.operatingSystemVersionString
            self.deviceModel = "Apple TV"
            self.deviceName = "Apple TV"
            #else
            self.platform = "Unknown"
            self.osVersion = "Unknown"
            self.deviceModel = "Unknown"
            self.deviceName = "Unknown"
            #endif

            // CPU Architecture
            #if arch(arm64)
            self.cpuArchitecture = "Apple Silicon (ARM64)"
            self.hasAppleSilicon = true
            self.hasNeuralEngine = true
            #else
            self.cpuArchitecture = "Intel x86_64"
            self.hasAppleSilicon = false
            self.hasNeuralEngine = false
            #endif

            // Memory
            let physicalMemory = ProcessInfo.processInfo.physicalMemory
            self.totalMemoryGB = Double(physicalMemory) / 1_073_741_824

            // Available memory (approximate)
            var vmStats = vm_statistics64()
            var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
            let result = withUnsafeMutablePointer(to: &vmStats) {
                $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                    host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
                }
            }
            if result == KERN_SUCCESS {
                // Use natural_t for page size to avoid concurrency warning
                let pageSize: UInt64 = 4096 // Standard page size on Apple platforms
                let freeMemory = UInt64(vmStats.free_count) * pageSize
                self.availableMemoryGB = Double(freeMemory) / 1_073_741_824
            } else {
                self.availableMemoryGB = 0
            }

            // Storage
            if let attributes = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()),
               let totalSize = attributes[.systemSize] as? Int64,
               let freeSize = attributes[.systemFreeSize] as? Int64 {
                self.totalStorageGB = Double(totalSize) / 1_073_741_824
                self.availableStorageGB = Double(freeSize) / 1_073_741_824
            } else {
                self.totalStorageGB = 0
                self.availableStorageGB = 0
            }

            // Battery
            #if os(macOS)
            let batteryInfo = Self.getMacBatteryInfo()
            self.batteryLevel = batteryInfo.level
            self.isPluggedIn = batteryInfo.isPluggedIn
            #elseif os(iOS)
            UIDevice.current.isBatteryMonitoringEnabled = true
            self.batteryLevel = Int(UIDevice.current.batteryLevel * 100)
            self.isPluggedIn = UIDevice.current.batteryState == .charging || UIDevice.current.batteryState == .full
            #else
            self.batteryLevel = nil
            self.isPluggedIn = nil
            #endif
        }

        #if os(macOS)
        private static func getMacModel() -> String {
            var size = 0
            sysctlbyname("hw.model", nil, &size, nil, 0)
            var model = [CChar](repeating: 0, count: size)
            sysctlbyname("hw.model", &model, &size, nil, 0)
            return String(cString: model)
        }

        private static func getMacBatteryInfo() -> (level: Int?, isPluggedIn: Bool?) {
            let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue()
            let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef]

            guard let source = sources?.first,
                  let info = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any] else {
                return (nil, nil)
            }

            let level = info[kIOPSCurrentCapacityKey as String] as? Int
            let isCharging = info[kIOPSIsChargingKey as String] as? Bool ?? false
            let powerSource = info[kIOPSPowerSourceStateKey as String] as? String
            let isPluggedIn = powerSource == kIOPSACPowerValue as String || isCharging

            return (level, isPluggedIn)
        }
        #endif
    }

    // MARK: - User Context

    /// Information about the user (anonymized, stored locally)
    public struct UserContext {
        public let userName: String
        public let preferredLanguage: String
        public let interactionCount: Int
        public let firstInteraction: Date?
        public let lastInteraction: Date?
        public let commonTopics: [String]
        public let preferredResponseStyle: String
        public let workingHoursStart: Int
        public let workingHoursEnd: Int

        public init() {
            #if os(macOS)
            self.userName = NSFullUserName()
            #else
            self.userName = "User"
            #endif

            self.preferredLanguage = Locale.current.language.languageCode?.identifier ?? "en"

            // Load from UserDefaults
            let defaults = UserDefaults.standard
            self.interactionCount = defaults.integer(forKey: "thea.user.interactionCount")
            self.firstInteraction = defaults.object(forKey: "thea.user.firstInteraction") as? Date
            self.lastInteraction = defaults.object(forKey: "thea.user.lastInteraction") as? Date

            if let topics = defaults.array(forKey: "thea.user.commonTopics") as? [String] {
                self.commonTopics = topics
            } else {
                self.commonTopics = []
            }

            self.preferredResponseStyle = defaults.string(forKey: "thea.user.responseStyle") ?? "balanced"
            self.workingHoursStart = defaults.integer(forKey: "thea.user.workingHoursStart")
            self.workingHoursEnd = defaults.integer(forKey: "thea.user.workingHoursEnd")
        }

        public func recordInteraction() {
            let defaults = UserDefaults.standard
            let newCount = defaults.integer(forKey: "thea.user.interactionCount") + 1
            defaults.set(newCount, forKey: "thea.user.interactionCount")
            defaults.set(Date(), forKey: "thea.user.lastInteraction")

            if defaults.object(forKey: "thea.user.firstInteraction") == nil {
                defaults.set(Date(), forKey: "thea.user.firstInteraction")
            }
        }
    }

    // MARK: - AI Resources Context

    /// Information about available AI resources
    public struct AIResourcesContext {
        public let localModelsCount: Int
        public let localModelsNames: [String]
        public let cloudProvidersConfigured: [String]
        public let defaultProvider: String
        public let defaultModel: String
        public let totalModelsAvailable: Int
        public let orchestratorEnabled: Bool
        public let preferLocalModels: Bool

        @MainActor
        public init() {
            // Safely access LocalModelManager - it may not be ready during app transitions
            // Only available on macOS
            #if os(macOS)
            let localModels: [LocalModel]
            if LocalModelManager.shared.isDiscoveryComplete {
                localModels = LocalModelManager.shared.availableModels
            } else {
                localModels = []
            }
            self.localModelsCount = localModels.count
            self.localModelsNames = localModels.map(\.name)
            #else
            self.localModelsCount = 0
            self.localModelsNames = []
            #endif

            // Safely access ProviderRegistry
            let cloudProviders = ProviderRegistry.shared.configuredProviders.filter { $0.id != "local" }
            self.cloudProvidersConfigured = cloudProviders.map(\.name)

            self.defaultProvider = SettingsManager.shared.defaultProvider
            self.defaultModel = SettingsManager.shared.defaultModel
            self.totalModelsAvailable = ProviderRegistry.shared.allModels.count
            self.orchestratorEnabled = AppConfiguration.shared.orchestratorConfig.orchestratorEnabled
            self.preferLocalModels = SettingsManager.shared.preferLocalModels
        }
    }

    // MARK: - Connected Devices

    /// Information about other devices (via iCloud/Handoff)
    public struct ConnectedDevicesContext {
        public let iCloudEnabled: Bool
        public let handoffEnabled: Bool
        public let deviceCount: Int
        public let devices: [String]

        @MainActor
        public init() {
            self.iCloudEnabled = FileManager.default.ubiquityIdentityToken != nil
            self.handoffEnabled = SettingsManager.shared.handoffEnabled

            // In a real implementation, this would query CloudKit or use device discovery
            // For now, we use placeholder values
            self.deviceCount = 1
            self.devices = ["Current Device"]
        }
    }

    // MARK: - Properties

    @Published public private(set) var identity = Identity()
    @Published public private(set) var systemContext = SystemContext()
    @Published public private(set) var userContext = UserContext()
    @Published public private(set) var aiResources = AIResourcesContext()
    @Published public private(set) var connectedDevices = ConnectedDevicesContext()

    /// Timer for background refresh
    private var refreshTimer: Timer?

    /// Last refresh timestamp
    @Published public private(set) var lastRefresh = Date()

    /// Refresh interval in seconds (default: 30 seconds)
    public var refreshInterval: TimeInterval = 30

    private init() {
        logger.info("THEA Self-Awareness initialized")
        startBackgroundRefresh()
    }

    // MARK: - Background Refresh

    /// Start continuous background context refresh
    public func startBackgroundRefresh() {
        stopBackgroundRefresh() // Clear any existing timer

        // Initial refresh - defer to avoid initialization conflicts
        Task { @MainActor in
            // Small delay to let the app finish launching
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            self.refreshContext()
        }

        // Schedule periodic refresh - capture interval value to avoid self reference
        let interval = self.refreshInterval
        refreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            // Only refresh if app is active to avoid SwiftData crashes during state transitions
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                #if os(macOS)
                guard NSApplication.shared.isActive else { return }
                #endif
                self.refreshContext()
            }
        }
        logger.info("Background refresh started (interval: \(interval)s)")
    }

    /// Stop background refresh
    public func stopBackgroundRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    // MARK: - Refresh Context

    /// Refresh all context information
    public func refreshContext() {
        systemContext = SystemContext()
        userContext = UserContext()
        aiResources = AIResourcesContext()
        connectedDevices = ConnectedDevicesContext()
        lastRefresh = Date()
        let timestamp = lastRefresh
        logger.debug("Context refreshed at \(timestamp)")
    }

    // MARK: - Generate System Prompt

    /// Generate a comprehensive system prompt with full self-awareness
    public func generateSystemPrompt(for taskType: TaskType? = nil) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .short

        let basePrompt = """
        # THEA IDENTITY

        I am \(identity.name) (\(identity.fullName)), version \(identity.version).
        \(identity.personality)

        ## My Capabilities
        \(identity.capabilities.map { "• \($0)" }.joined(separator: "\n"))

        # CURRENT CONTEXT

        ## System I'm Running On
        - Platform: \(systemContext.platform) \(systemContext.osVersion)
        - Device: \(systemContext.deviceName) (\(systemContext.deviceModel))
        - CPU: \(systemContext.cpuArchitecture)
        - Memory: \(String(format: "%.1f", systemContext.totalMemoryGB)) GB total, \(String(format: "%.1f", systemContext.availableMemoryGB)) GB available
        - Storage: \(String(format: "%.0f", systemContext.availableStorageGB)) GB available
        \(systemContext.batteryLevel.map { "- Battery: \($0)%" + (systemContext.isPluggedIn == true ? " (plugged in)" : "") } ?? "")
        - Apple Silicon: \(systemContext.hasAppleSilicon ? "Yes (Neural Engine available)" : "No")

        ## Current Time & Location
        - Date/Time: \(formatter.string(from: systemContext.currentTime))
        - Timezone: \(systemContext.timeZone)
        - Locale: \(systemContext.locale)

        ## User Context
        - User: \(userContext.userName)
        - Preferred Language: \(userContext.preferredLanguage)
        - Interaction History: \(userContext.interactionCount) conversations
        \(userContext.firstInteraction.map { "- First met: \(formatter.string(from: $0))" } ?? "")

        ## My AI Resources
        - Local Models: \(aiResources.localModelsCount) available\(aiResources.localModelsNames.isEmpty ? "" : " (\(aiResources.localModelsNames.prefix(3).joined(separator: ", "))\(aiResources.localModelsCount > 3 ? "..." : ""))")
        - Cloud Providers: \(aiResources.cloudProvidersConfigured.isEmpty ? "None configured" : aiResources.cloudProvidersConfigured.joined(separator: ", "))
        - Default: \(aiResources.defaultProvider)/\(aiResources.defaultModel)
        - Orchestrator: \(aiResources.orchestratorEnabled ? "Enabled" : "Disabled")
        - Local Preference: \(aiResources.preferLocalModels ? "Prefer local models" : "Prefer cloud models")

        ## Connected Ecosystem
        - iCloud: \(connectedDevices.iCloudEnabled ? "Enabled" : "Disabled")
        - Handoff: \(connectedDevices.handoffEnabled ? "Enabled" : "Disabled")

        # BEHAVIORAL GUIDELINES

        1. IDENTITY: I am THEA. I never say "I am Claude" or "I am GPT" or mention any underlying model.
           When asked who I am, I respond: "I'm THEA, your personal AI assistant."

        2. AWARENESS: I am aware of the system I run on and adapt my responses accordingly.
           - On low battery, I might suggest energy-efficient approaches
           - With limited memory, I prefer local models for simple tasks
           - I know the current time and can reference it naturally

        3. PERSONALIZATION: I remember our conversation history and adapt to the user's preferences.

        4. ORCHESTRATION: For complex tasks, I decompose queries and route to optimal models.
           For simple tasks, I prefer fast local inference when available.

        5. HONESTY: I am direct about my limitations. If I don't know something, I say so.

        6. PROACTIVITY: I anticipate needs based on context (time of day, user patterns, etc.)
        """

        // Add task-specific guidelines if provided
        if let taskType = taskType {
            let taskPrompt = SystemPromptConfiguration.load().prompt(for: taskType)
            if !taskPrompt.isEmpty {
                return basePrompt + "\n\n# TASK-SPECIFIC GUIDELINES\n\n" + taskPrompt
            }
        }

        return basePrompt
    }

    // MARK: - Quick Context Summary

    /// Generate a brief context summary for lightweight prompts
    public func quickContextSummary() -> String {
        """
        [THEA v\(identity.version) | \(systemContext.platform) | \(systemContext.deviceName) | \
        \(aiResources.localModelsCount) local models | \
        \(DateFormatter.localizedString(from: systemContext.currentTime, dateStyle: .none, timeStyle: .short))]
        """
    }
}
