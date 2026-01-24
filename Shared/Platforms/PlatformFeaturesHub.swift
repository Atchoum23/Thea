// PlatformFeaturesHub.swift
// Central hub for accessing platform-specific features across all Apple platforms

import Foundation
import OSLog

// MARK: - Platform Features Hub

/// Central access point for platform-specific features
@MainActor
public final class PlatformFeaturesHub: ObservableObject {
    public static let shared = PlatformFeaturesHub()

    private let logger = Logger(subsystem: "com.thea.app", category: "PlatformFeatures")

    // MARK: - Published State

    @Published public private(set) var currentPlatform: Platform = .unknown
    @Published public private(set) var availableFeatures: Set<PlatformFeature> = []
    @Published public private(set) var isInitialized = false

    // MARK: - Initialization

    private init() {
        detectPlatform()
        detectAvailableFeatures()
    }

    // MARK: - Platform Detection

    private func detectPlatform() {
        #if os(macOS)
        currentPlatform = .macOS
        #elseif os(iOS)
        #if targetEnvironment(macCatalyst)
        currentPlatform = .macCatalyst
        #else
        currentPlatform = UIDevice.current.userInterfaceIdiom == .pad ? .iPadOS : .iOS
        #endif
        #elseif os(watchOS)
        currentPlatform = .watchOS
        #elseif os(tvOS)
        currentPlatform = .tvOS
        #elseif os(visionOS)
        currentPlatform = .visionOS
        #else
        currentPlatform = .unknown
        #endif

        logger.info("Detected platform: \(self.currentPlatform.rawValue)")
    }

    private func detectAvailableFeatures() {
        var features: Set<PlatformFeature> = [.core]

        switch currentPlatform {
        case .macOS:
            features.formUnion([
                .menuBar,
                .globalHotkeys,
                .touchBar,
                .services,
                .finderIntegration,
                .appleScript,
                .multiWindow,
                .accessibility,
                .spotlight,
                .handoff,
                .universalClipboard
            ])

        case .iOS:
            features.formUnion([
                .siriShortcuts,
                .homeScreenQuickActions,
                .widgets,
                .liveActivities,
                .shareExtension,
                .spotlight,
                .handoff,
                .universalClipboard,
                .haptics,
                .faceID,
                .healthKit,
                .coreLocation
            ])

        case .iPadOS:
            features.formUnion([
                .siriShortcuts,
                .homeScreenQuickActions,
                .widgets,
                .liveActivities,
                .shareExtension,
                .spotlight,
                .handoff,
                .universalClipboard,
                .multiWindow,
                .pencilSupport,
                .stageManager,
                .haptics
            ])

        case .watchOS:
            features.formUnion([
                .complications,
                .glances,
                .digitalCrown,
                .haptics,
                .healthKit,
                .workoutKit
            ])

        case .visionOS:
            features.formUnion([
                .immersiveSpaces,
                .volumetricWindows,
                .handTracking,
                .eyeTracking,
                .spatialAudio,
                .sharePlay
            ])

        case .tvOS:
            features.formUnion([
                .siriRemote,
                .topShelf
            ])

        case .macCatalyst:
            features.formUnion([
                .siriShortcuts,
                .widgets,
                .spotlight,
                .handoff,
                .universalClipboard,
                .multiWindow
            ])

        case .unknown:
            break
        }

        availableFeatures = features
        logger.info("Available features: \(features.count)")
    }

    // MARK: - Feature Access

    public func isFeatureAvailable(_ feature: PlatformFeature) -> Bool {
        availableFeatures.contains(feature)
    }

    // MARK: - Initialize Platform Features

    public func initialize() async {
        guard !isInitialized else { return }

        logger.info("Initializing platform features for \(self.currentPlatform.rawValue)")

        #if os(macOS)
        await initializeMacOSFeatures()
        #elseif os(iOS)
        await initializeiOSFeatures()
        #elseif os(watchOS)
        await initializeWatchOSFeatures()
        #elseif os(visionOS)
        await initializeVisionOSFeatures()
        #endif

        // Common initializations
        await initializeCommonFeatures()

        isInitialized = true
        logger.info("Platform features initialized")
    }

    // MARK: - Platform-Specific Initialization

    #if os(macOS)
    private func initializeMacOSFeatures() async {
        // Setup menu bar
        MenuBarManager.shared.setup()

        // Register global hotkeys
        GlobalHotkeyManager.shared.registerAllHotkeys()

        logger.info("macOS features initialized")
    }
    #endif

    #if os(iOS)
    private func initializeiOSFeatures() async {
        // Setup home screen quick actions
        HomeScreenActionsManager.shared.setupQuickActions()

        // Donate common shortcuts to Siri
        for action in QuickAction.allCases {
            SiriShortcutsManager.shared.donateQuickActionShortcut(action)
        }

        logger.info("iOS features initialized")
    }
    #endif

    #if os(watchOS)
    private func initializeWatchOSFeatures() async {
        // Update complications
        ComplicationManager.shared.updateComplications()

        logger.info("watchOS features initialized")
    }
    #endif

    #if os(visionOS)
    private func initializeVisionOSFeatures() async {
        // Setup spatial computing
        // Hand tracking, etc. require explicit user permission

        logger.info("visionOS features initialized")
    }
    #endif

    private func initializeCommonFeatures() async {
        // Index content in Spotlight
        await SpotlightIntegration.shared.indexQuickActions()

        // Setup Live Activities if available
        #if canImport(ActivityKit)
        // Live Activity setup handled on-demand
        #endif
    }

    // MARK: - Convenience Accessors

    /// Get menu bar manager (macOS only)
    #if os(macOS)
    public var menuBar: MenuBarManager {
        MenuBarManager.shared
    }

    public var globalHotkeys: GlobalHotkeyManager {
        GlobalHotkeyManager.shared
    }

    public var finder: FinderIntegration {
        FinderIntegration.shared
    }
    #endif

    /// Get Siri shortcuts manager (iOS/iPadOS)
    #if os(iOS)
    public var siriShortcuts: SiriShortcutsManager {
        SiriShortcutsManager.shared
    }

    public var homeScreenActions: HomeScreenActionsManager {
        HomeScreenActionsManager.shared
    }

    public var haptics: HapticFeedbackManager {
        HapticFeedbackManager.shared
    }
    #endif

    /// Get watch-specific managers (watchOS)
    #if os(watchOS)
    public var complications: ComplicationManager {
        ComplicationManager.shared
    }

    public var digitalCrown: DigitalCrownManager {
        DigitalCrownManager.shared
    }

    public var watchHaptics: WatchHapticManager {
        WatchHapticManager.shared
    }
    #endif

    /// Get spatial computing managers (visionOS)
    #if os(visionOS)
    public var spatialComputing: SpatialComputingManager {
        SpatialComputingManager.shared
    }

    public var spatialUI: SpatialUIManager {
        SpatialUIManager.shared
    }

    public var spatialGestures: SpatialGestureManager {
        SpatialGestureManager.shared
    }
    #endif

    /// Common features available on all platforms
    public var spotlight: SpotlightIntegration {
        SpotlightIntegration.shared
    }

    public var handoff: HandoffManager {
        HandoffManager.shared
    }

    public var universalClipboard: UniversalClipboardManager {
        UniversalClipboardManager.shared
    }

    public var liveActivities: TheaLiveActivityManager {
        TheaLiveActivityManager.shared
    }
}

// MARK: - Platform Enum

public enum Platform: String, CaseIterable {
    case macOS
    case iOS
    case iPadOS
    case watchOS
    case tvOS
    case visionOS
    case macCatalyst
    case unknown

    public var displayName: String {
        switch self {
        case .macOS: return "macOS"
        case .iOS: return "iPhone"
        case .iPadOS: return "iPad"
        case .watchOS: return "Apple Watch"
        case .tvOS: return "Apple TV"
        case .visionOS: return "Apple Vision Pro"
        case .macCatalyst: return "Mac (Catalyst)"
        case .unknown: return "Unknown"
        }
    }

    public var iconName: String {
        switch self {
        case .macOS, .macCatalyst: return "desktopcomputer"
        case .iOS: return "iphone"
        case .iPadOS: return "ipad"
        case .watchOS: return "applewatch"
        case .tvOS: return "appletv"
        case .visionOS: return "visionpro"
        case .unknown: return "questionmark.circle"
        }
    }
}

// MARK: - Platform Feature Enum

public enum PlatformFeature: String, CaseIterable {
    // Core
    case core

    // macOS
    case menuBar
    case globalHotkeys
    case touchBar
    case services
    case finderIntegration
    case appleScript

    // iOS/iPadOS
    case siriShortcuts
    case homeScreenQuickActions
    case widgets
    case liveActivities
    case shareExtension
    case pencilSupport
    case stageManager

    // Common
    case spotlight
    case handoff
    case universalClipboard
    case multiWindow
    case accessibility
    case haptics
    case faceID
    case healthKit
    case coreLocation
    case sharePlay

    // watchOS
    case complications
    case glances
    case digitalCrown
    case workoutKit

    // visionOS
    case immersiveSpaces
    case volumetricWindows
    case handTracking
    case eyeTracking
    case spatialAudio

    // tvOS
    case siriRemote
    case topShelf

    public var displayName: String {
        switch self {
        case .core: return "Core Features"
        case .menuBar: return "Menu Bar"
        case .globalHotkeys: return "Global Hotkeys"
        case .touchBar: return "Touch Bar"
        case .services: return "Services Menu"
        case .finderIntegration: return "Finder Integration"
        case .appleScript: return "AppleScript"
        case .siriShortcuts: return "Siri Shortcuts"
        case .homeScreenQuickActions: return "Quick Actions"
        case .widgets: return "Widgets"
        case .liveActivities: return "Live Activities"
        case .shareExtension: return "Share Extension"
        case .pencilSupport: return "Apple Pencil"
        case .stageManager: return "Stage Manager"
        case .spotlight: return "Spotlight Search"
        case .handoff: return "Handoff"
        case .universalClipboard: return "Universal Clipboard"
        case .multiWindow: return "Multi-Window"
        case .accessibility: return "Accessibility"
        case .haptics: return "Haptic Feedback"
        case .faceID: return "Face ID"
        case .healthKit: return "Health Integration"
        case .coreLocation: return "Location Services"
        case .sharePlay: return "SharePlay"
        case .complications: return "Complications"
        case .glances: return "Glances"
        case .digitalCrown: return "Digital Crown"
        case .workoutKit: return "Workout Tracking"
        case .immersiveSpaces: return "Immersive Spaces"
        case .volumetricWindows: return "Volumetric Windows"
        case .handTracking: return "Hand Tracking"
        case .eyeTracking: return "Eye Tracking"
        case .spatialAudio: return "Spatial Audio"
        case .siriRemote: return "Siri Remote"
        case .topShelf: return "Top Shelf"
        }
    }
}
