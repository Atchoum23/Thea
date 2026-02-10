// AppClipManager.swift
// App Clip support for instant experiences

import Combine
import CoreLocation
import Foundation
import OSLog
#if canImport(AppClip)
    import AppClip
#endif
#if canImport(StoreKit)
    import StoreKit
#endif
#if canImport(UIKit)
    import UIKit
#endif
#if os(macOS)
    import AppKit
#endif

// MARK: - App Clip Manager

/// Manages App Clip experience and full app promotion
@MainActor
public final class AppClipManager: ObservableObject {
    public static let shared = AppClipManager()

    private let logger = Logger(subsystem: "com.thea.app", category: "AppClip")

    // MARK: - Published State

    @Published public private(set) var isAppClip: Bool = false
    @Published public private(set) var invocationURL: URL?
    @Published public private(set) var clipExperience: ClipExperience?
    @Published public private(set) var hasFullApp: Bool = false

    // MARK: - Configuration

    private let appStoreId = "123456789" // Replace with actual App Store ID
    // MARK: - Initialization

    private init() {
        detectEnvironment()
        checkFullAppInstalled()
    }

    private func detectEnvironment() {
        // Check if running as App Clip
        #if APPCLIP
            isAppClip = true
            logger.info("Running as App Clip")
        #else
            isAppClip = false
        #endif
    }

    private func checkFullAppInstalled() {
        // Check if full app is installed
        #if canImport(UIKit) && !os(macOS)
            if let fullAppURL = URL(string: "thea://"),
               UIApplication.shared.canOpenURL(fullAppURL)
            {
                hasFullApp = true
            }
        #endif
    }

    // MARK: - Invocation Handling

    /// Handle App Clip invocation
    public func handleInvocation(url: URL) {
        invocationURL = url
        logger.info("App Clip invoked with URL: \(url.absoluteString)")

        // Parse URL to determine experience
        clipExperience = parseExperience(from: url)

        // Track invocation
        AnalyticsManager.shared.track("app_clip_invocation", properties: [
            "url": url.absoluteString,
            "experience": clipExperience?.type.rawValue ?? "unknown"
        ])

        // Handle experience
        if let experience = clipExperience {
            Task {
                await handleExperience(experience)
            }
        }
    }

    private func parseExperience(from url: URL) -> ClipExperience? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }

        let path = components.path
        let queryParams = components.queryItems?.reduce(into: [String: String]()) { result, item in
            result[item.name] = item.value
        } ?? [:]

        // Parse different experiences
        if path.contains("quick-ask") || path.contains("ask") {
            let query = queryParams["q"] ?? queryParams["query"] ?? ""
            return ClipExperience(
                type: .quickAsk,
                parameters: ["query": query]
            )
        }

        if path.contains("scan") {
            return ClipExperience(
                type: .scan,
                parameters: [:]
            )
        }

        if path.contains("voice") {
            return ClipExperience(
                type: .voice,
                parameters: [:]
            )
        }

        if path.contains("demo") {
            return ClipExperience(
                type: .demo,
                parameters: [:]
            )
        }

        // Default experience
        return ClipExperience(
            type: .quickAsk,
            parameters: [:]
        )
    }

    private func handleExperience(_ experience: ClipExperience) async {
        switch experience.type {
        case .quickAsk:
            // Show quick ask interface
            NotificationCenter.default.post(
                name: .appClipShowQuickAsk,
                object: nil,
                userInfo: experience.parameters
            )

        case .scan:
            // Show scan interface
            NotificationCenter.default.post(
                name: .appClipShowScan,
                object: nil
            )

        case .voice:
            // Show voice interface
            NotificationCenter.default.post(
                name: .appClipShowVoice,
                object: nil
            )

        case .demo:
            // Show demo/preview
            NotificationCenter.default.post(
                name: .appClipShowDemo,
                object: nil
            )
        }
    }

    // MARK: - Location Verification

    #if canImport(AppClip)
        /// Verify user location for physical App Clip codes
        nonisolated public func verifyLocation(for activity: NSUserActivity) async -> LocationVerificationResult {
            guard let payload = activity.appClipActivationPayload else {
                return LocationVerificationResult(verified: false, reason: "No activation payload")
            }

            // Define expected regions for your App Clip codes
            let expectedRegions: [CLRegion] = [
                // Add your expected regions here
                // CLCircularRegion(center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194), radius: 100, identifier: "SF-Office")
            ]

            for region in expectedRegions {
                do {
                    try await payload.confirmAcquired(in: region)
                    logger.info("Location verified for region: \(region.identifier)")
                    return LocationVerificationResult(verified: true, region: region.identifier)
                } catch {
                    logger.debug("Location not in region: \(region.identifier)")
                }
            }

            return LocationVerificationResult(verified: false, reason: "Location not in expected region")
        }
    #endif

    // MARK: - Full App Promotion

    /// Show overlay to promote full app download
    #if canImport(StoreKit) && canImport(UIKit) && !os(macOS)
        public func promoteFullApp() async {
            guard isAppClip else { return }

            // Use SKOverlay for smooth promotion
            let configuration = SKOverlay.AppClipConfiguration(position: .bottom)
            let overlay = SKOverlay(configuration: configuration)

            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                overlay.present(in: windowScene)

                AnalyticsManager.shared.track("app_clip_full_app_promotion_shown")
            }
        }

        /// Dismiss full app promotion overlay
        public func dismissPromotion() {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                SKOverlay.dismiss(in: windowScene)
            }
        }
    #endif

    /// Open full app in App Store
    public func openAppStore() {
        if let url = URL(string: "https://apps.apple.com/app/id\(appStoreId)") {
            #if canImport(UIKit) && !os(macOS)
                UIApplication.shared.open(url)
            #elseif os(macOS)
                NSWorkspace.shared.open(url)
            #endif

            AnalyticsManager.shared.track("app_clip_open_app_store")
        }
    }

    // MARK: - Data Migration

    /// Prepare data for migration to full app
    public func prepareDataForMigration() -> AppClipData {
        // Collect any data that should be migrated
        let conversations = UserDefaults.standard.array(forKey: "appclip.conversations") as? [[String: Any]] ?? []
        let preferences = [
            "preferredModel": UserDefaults.standard.string(forKey: "appclip.preferredModel") ?? "",
            "voiceEnabled": UserDefaults.standard.bool(forKey: "appclip.voiceEnabled")
        ] as [String: Any]

        return AppClipData(
            conversations: conversations,
            preferences: preferences,
            timestamp: Date()
        )
    }

    /// Save data to shared container for migration
    public func saveDataForMigration() {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.thea.app"
        ) else {
            logger.warning("Could not access shared container")
            return
        }

        let data = prepareDataForMigration()
        let migrationURL = containerURL.appendingPathComponent("AppClipMigration.json")

        do {
            let jsonData = try JSONEncoder().encode(data)
            try jsonData.write(to: migrationURL)
            logger.info("Migration data saved")
        } catch {
            logger.error("Failed to save migration data: \(error.localizedDescription)")
        }
    }

    /// Import migrated data in full app
    public func importMigratedData() -> AppClipData? {
        guard !isAppClip else { return nil }

        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.thea.app"
        ) else {
            return nil
        }

        let migrationURL = containerURL.appendingPathComponent("AppClipMigration.json")

        guard FileManager.default.fileExists(atPath: migrationURL.path) else {
            return nil
        }

        do {
            let jsonData = try Data(contentsOf: migrationURL)
            let data = try JSONDecoder().decode(AppClipData.self, from: jsonData)

            // Clean up migration file
            try? FileManager.default.removeItem(at: migrationURL)

            logger.info("Migration data imported")
            return data
        } catch {
            logger.error("Failed to import migration data: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Usage Limits

    /// Check if App Clip usage limit is reached
    public func checkUsageLimit() -> UsageLimitStatus {
        guard isAppClip else {
            return UsageLimitStatus(limited: false, remaining: -1)
        }

        let maxQueries = 10
        let usedQueries = UserDefaults.standard.integer(forKey: "appclip.queryCount")

        if usedQueries >= maxQueries {
            return UsageLimitStatus(
                limited: true,
                remaining: 0,
                message: "You've reached the App Clip limit. Download the full app for unlimited access!"
            )
        }

        return UsageLimitStatus(
            limited: false,
            remaining: maxQueries - usedQueries
        )
    }

    /// Increment usage counter
    public func incrementUsage() {
        guard isAppClip else { return }

        let count = UserDefaults.standard.integer(forKey: "appclip.queryCount") + 1
        UserDefaults.standard.set(count, forKey: "appclip.queryCount")

        // Check if limit reached
        let status = checkUsageLimit()
        if status.limited {
            NotificationCenter.default.post(name: .appClipUsageLimitReached, object: nil)
        }
    }
}

// MARK: - Types

public struct ClipExperience {
    public let type: ExperienceType
    public let parameters: [String: String]

    public enum ExperienceType: String {
        case quickAsk
        case scan
        case voice
        case demo
    }
}

public struct LocationVerificationResult {
    public let verified: Bool
    public let region: String?
    public let reason: String?

    public init(verified: Bool, region: String? = nil, reason: String? = nil) {
        self.verified = verified
        self.region = region
        self.reason = reason
    }
}

public struct AppClipData: Codable {
    public let conversations: [[String: AnyCodable]]
    public let preferences: [String: AnyCodable]
    public let timestamp: Date

    public init(conversations: [[String: Any]], preferences: [String: Any], timestamp: Date) {
        self.conversations = conversations.map { dict in
            dict.mapValues { AnyCodable($0) }
        }
        self.preferences = preferences.mapValues { AnyCodable($0) }
        self.timestamp = timestamp
    }
}

public struct UsageLimitStatus {
    public let limited: Bool
    public let remaining: Int
    public let message: String?

    public init(limited: Bool, remaining: Int, message: String? = nil) {
        self.limited = limited
        self.remaining = remaining
        self.message = message
    }
}

// MARK: - Notifications

public extension Notification.Name {
    static let appClipShowQuickAsk = Notification.Name("thea.appClip.showQuickAsk")
    static let appClipShowScan = Notification.Name("thea.appClip.showScan")
    static let appClipShowVoice = Notification.Name("thea.appClip.showVoice")
    static let appClipShowDemo = Notification.Name("thea.appClip.showDemo")
    static let appClipUsageLimitReached = Notification.Name("thea.appClip.usageLimitReached")
}

// MARK: - App Clip Views

import SwiftUI

/// Main App Clip view
public struct AppClipMainView: View {
    @ObservedObject var manager = AppClipManager.shared
    @State private var query = ""
    @State private var isProcessing = false

    public init() {}

    public var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 60))
                        .foregroundStyle(.tint)

                    Text("Thea")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("AI Assistant")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 40)

                Spacer()

                // Query input
                VStack(spacing: 16) {
                    TextField("Ask anything...", text: $query, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3 ... 6)

                    Button(action: submitQuery) {
                        HStack {
                            if isProcessing {
                                ProgressView()
                                    .progressViewStyle(.circular)
                            } else {
                                Image(systemName: "paperplane.fill")
                            }
                            Text("Ask Thea")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(query.isEmpty || isProcessing)
                }
                .padding()

                // Usage limit
                let status = manager.checkUsageLimit()
                if status.remaining >= 0 {
                    Text("\(status.remaining) free queries remaining")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Full app promotion
                VStack(spacing: 12) {
                    Text("Want unlimited access?")
                        .font(.headline)

                    Button("Get the Full App") {
                        manager.openAppStore()
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
            }
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
    }

    private func submitQuery() {
        guard !query.isEmpty else { return }

        isProcessing = true
        manager.incrementUsage()

        // Handle query
        Task {
            // Process with AI
            // ...

            isProcessing = false
        }
    }
}

/// App Clip usage limit view
public struct AppClipLimitView: View {
    @ObservedObject var manager = AppClipManager.shared

    public init() {}

    public var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "sparkles.rectangle.stack")
                .font(.system(size: 80))
                .foregroundStyle(.orange)

            Text("You've Reached the Limit")
                .font(.title)
                .fontWeight(.bold)

            Text("Download the full Thea app for unlimited AI conversations, custom agents, and more!")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            VStack(spacing: 12) {
                Button(action: { manager.openAppStore() }) {
                    HStack {
                        Image(systemName: "arrow.down.app")
                        Text("Download Full App")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                #if canImport(StoreKit) && canImport(UIKit) && !os(macOS)
                    Button("Show in App Store") {
                        Task {
                            await manager.promoteFullApp()
                        }
                    }
                    .buttonStyle(.bordered)
                #endif
            }
            .padding()
        }
        .padding()
    }
}
