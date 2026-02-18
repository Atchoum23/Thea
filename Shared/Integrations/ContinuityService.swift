//
//  ContinuityService.swift
//  Thea
//
//  Universal Links, Handoff, and Continuity Camera support
//

import Combine
import Foundation
import Network
import OSLog
import SwiftUI

#if canImport(UIKit)
    import UIKit
#endif
#if canImport(AppKit)
    import AppKit
#endif

// MARK: - Continuity Service

/// Service for managing Handoff, Universal Links, and Continuity features
@MainActor
public class ContinuityService: ObservableObject {
    public static let shared = ContinuityService()

    // MARK: - Published State

    @Published public private(set) var activeActivity: NSUserActivity?
    @Published public private(set) var availableActivities: [ContinuityActivity] = []
    @Published public private(set) var isHandoffEnabled = true
    @Published public private(set) var connectedDevices: [ContinuityDevice] = []

    // MARK: - Activity Types

    public enum ActivityType: String {
        case viewConversation = "app.thea.view-conversation"
        case editProject = "app.thea.edit-project"
        case askQuestion = "app.thea.ask-question"
        case viewKnowledge = "app.thea.view-knowledge"
        case codeGeneration = "app.thea.code-generation"
        case focusSession = "app.thea.focus-session"
    }

    // MARK: - Universal Link Paths

    private let universalLinkHost = "thea.app"

    // MARK: - Initialization

    private init() {
        setupHandoff()
    }

    // MARK: - Handoff

    private func setupHandoff() {
        // Register activity types
        #if os(iOS)
            UIApplication.shared.registerForRemoteNotifications()
        #endif
    }

    /// Start a Handoff activity
    public func startActivity(
        type: ActivityType,
        title: String,
        userInfo: [String: Any],
        webpageURL: URL? = nil
    ) -> NSUserActivity {
        let activity = NSUserActivity(activityType: type.rawValue)
        activity.title = title
        activity.userInfo = userInfo as [AnyHashable: Any]
        activity.isEligibleForHandoff = true
        activity.isEligibleForSearch = true
        #if os(iOS)
            activity.isEligibleForPrediction = true
        #endif

        // Add content attributes for Spotlight
        activity.contentAttributeSet = createAttributeSet(title: title, type: type)

        // Set webpage URL for universal links
        if let webpageURL {
            activity.webpageURL = webpageURL
        } else {
            activity.webpageURL = createUniversalLink(for: type, userInfo: userInfo)
        }

        // Required keys for Handoff
        activity.requiredUserInfoKeys = Set(userInfo.keys)

        activity.becomeCurrent()
        activeActivity = activity

        return activity
    }

    /// Update the current activity
    public func updateActivity(userInfo: [String: Any]) {
        guard let activity = activeActivity else { return }
        activity.addUserInfoEntries(from: userInfo as [AnyHashable: Any])
        activity.needsSave = true
    }

    /// End the current activity
    public func endActivity() {
        activeActivity?.invalidate()
        activeActivity = nil
    }

    // MARK: - Activity Restoration

    /// Continue an activity from another device
    public func continueActivity(_ activity: NSUserActivity) -> ContinuityResult? {
        guard let type = ActivityType(rawValue: activity.activityType) else {
            return nil
        }

        let userInfo = activity.userInfo as? [String: Any] ?? [:]

        switch type {
        case .viewConversation:
            return .conversation(id: userInfo["conversationId"] as? String ?? "")
        case .editProject:
            return .project(path: userInfo["projectPath"] as? String ?? "")
        case .askQuestion:
            return .question(text: userInfo["questionText"] as? String ?? "")
        case .viewKnowledge:
            return .knowledge(id: userInfo["knowledgeId"] as? String ?? "")
        case .codeGeneration:
            return .codeGeneration(context: userInfo["context"] as? String ?? "")
        case .focusSession:
            return .focusSession(duration: userInfo["duration"] as? Int ?? 25)
        }
    }

    // MARK: - Universal Links

    /// Create a universal link for an activity
    private func createUniversalLink(for type: ActivityType, userInfo: [String: Any]) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = universalLinkHost

        switch type {
        case .viewConversation:
            components.path = "/conversation/\(userInfo["conversationId"] as? String ?? "")"
        case .editProject:
            components.path = "/project"
            components.queryItems = [URLQueryItem(name: "path", value: userInfo["projectPath"] as? String)]
        case .askQuestion:
            components.path = "/ask"
            components.queryItems = [URLQueryItem(name: "q", value: userInfo["questionText"] as? String)]
        case .viewKnowledge:
            components.path = "/knowledge/\(userInfo["knowledgeId"] as? String ?? "")"
        case .codeGeneration:
            components.path = "/code"
        case .focusSession:
            components.path = "/focus"
            components.queryItems = [URLQueryItem(name: "duration", value: "\(userInfo["duration"] as? Int ?? 25)")]
        }

        return components.url
    }

    /// Handle an incoming universal link
    public func handleUniversalLink(_ url: URL) -> ContinuityResult? {
        guard url.host == universalLinkHost else { return nil }

        let path = url.path
        let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []

        if path.hasPrefix("/conversation/") {
            let id = String(path.dropFirst("/conversation/".count))
            return .conversation(id: id)
        } else if path == "/project" {
            let projectPath = queryItems.first { $0.name == "path" }?.value ?? ""
            return .project(path: projectPath)
        } else if path == "/ask" {
            let question = queryItems.first { $0.name == "q" }?.value ?? ""
            return .question(text: question)
        } else if path.hasPrefix("/knowledge/") {
            let id = String(path.dropFirst("/knowledge/".count))
            return .knowledge(id: id)
        } else if path == "/code" {
            return .codeGeneration(context: "")
        } else if path == "/focus" {
            let duration = Int(queryItems.first { $0.name == "duration" }?.value ?? "25") ?? 25
            return .focusSession(duration: duration)
        }

        return nil
    }

    // MARK: - Continuity Camera

    #if os(macOS)
        /// Configure Continuity Camera for document scanning
        public func configureContinuityCamera(for _: NSView) {
            // Continuity Camera menu integration
        }

        /// Insert scanned document
        public func handleScannedDocument(_ data: Data, type: ContinuityScanType) async -> ContinuityScanResult {
            switch type {
            case .document:
                await processDocumentScan(data)
            case .photo:
                await processPhotoScan(data)
            case .sketch:
                await processSketchScan(data)
            }
        }

        private func processDocumentScan(_ data: Data) async -> ContinuityScanResult {
            // OCR processing for documents
            ContinuityScanResult(
                type: .document,
                imageData: data,
                extractedText: nil,
                confidence: 0
            )
        }

        private func processPhotoScan(_ data: Data) async -> ContinuityScanResult {
            ContinuityScanResult(
                type: .photo,
                imageData: data,
                extractedText: nil,
                confidence: 0
            )
        }

        private func processSketchScan(_ data: Data) async -> ContinuityScanResult {
            ContinuityScanResult(
                type: .sketch,
                imageData: data,
                extractedText: nil,
                confidence: 0
            )
        }
    #endif

    // MARK: - Helper Methods

    private func createAttributeSet(title: String, type: ActivityType) -> CSSearchableItemAttributeSet {
        let attributeSet = CSSearchableItemAttributeSet(contentType: .item)
        attributeSet.title = title

        switch type {
        case .viewConversation:
            attributeSet.contentDescription = "View AI conversation"
        case .editProject:
            attributeSet.contentDescription = "Edit code project"
        case .askQuestion:
            attributeSet.contentDescription = "Ask Thea AI"
        case .viewKnowledge:
            attributeSet.contentDescription = "View knowledge item"
        case .codeGeneration:
            attributeSet.contentDescription = "Generate code"
        case .focusSession:
            attributeSet.contentDescription = "Focus session"
        }

        return attributeSet
    }

    // MARK: - Device Discovery

    /// Discover nearby devices for Handoff via Bonjour
    public func discoverDevices() async {
        #if os(macOS) || os(iOS)
        let browser = NWBrowser(for: .bonjour(type: "_thea-sync._tcp.", domain: nil), using: .tcp)
        browser.stateUpdateHandler = { state in
            if case .failed(let error) = state {
                Logger(subsystem: "app.thea", category: "Continuity")
                    .error("Device discovery failed: \(error.localizedDescription)")
            }
        }
        browser.browseResultsChangedHandler = { results, _ in
            let devices = results.map { String(describing: $0.endpoint) }
            Logger(subsystem: "app.thea", category: "Continuity")
                .info("Discovered \(devices.count) Thea device(s)")
        }
        browser.start(queue: .main)

        // Browse for 5 seconds then stop
        do {
            try await Task.sleep(for: .seconds(5))
        } catch {
            Logger(subsystem: "ai.thea.app", category: "ContinuityService")
                .warning("Continuity browse sleep cancelled: \(error)")
        }
        browser.cancel()
        #endif
    }
}

// MARK: - Supporting Types

import CoreSpotlight
import UniformTypeIdentifiers

public enum ContinuityResult: Sendable {
    case conversation(id: String)
    case project(path: String)
    case question(text: String)
    case knowledge(id: String)
    case codeGeneration(context: String)
    case focusSession(duration: Int)
}

public struct ContinuityActivity: Identifiable, Sendable {
    public let id: UUID
    public let type: String
    public let title: String
    public let deviceName: String
    public let timestamp: Date

    public init(id: UUID = UUID(), type: String, title: String, deviceName: String, timestamp: Date = Date()) {
        self.id = id
        self.type = type
        self.title = title
        self.deviceName = deviceName
        self.timestamp = timestamp
    }
}

public struct ContinuityDevice: Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let type: DeviceType
    public let isNearby: Bool

    public enum DeviceType: String, Sendable {
        case mac = "Mac"
        case iphone = "iPhone"
        case ipad = "iPad"
        case watch = "Apple Watch"
        case tv = "Apple TV"
    }

    public init(id: UUID = UUID(), name: String, type: DeviceType, isNearby: Bool = true) {
        self.id = id
        self.name = name
        self.type = type
        self.isNearby = isNearby
    }
}

public enum ContinuityScanType: Sendable {
    case document
    case photo
    case sketch
}

public struct ContinuityScanResult: Sendable {
    public let type: ContinuityScanType
    public let imageData: Data
    public let extractedText: String?
    public let confidence: Double

    public init(type: ContinuityScanType, imageData: Data, extractedText: String?, confidence: Double) {
        self.type = type
        self.imageData = imageData
        self.extractedText = extractedText
        self.confidence = confidence
    }
}

// MARK: - SwiftUI View Modifier

public struct HandoffModifier: ViewModifier {
    let activityType: ContinuityService.ActivityType
    let title: String
    let userInfo: [String: Any]

    public func body(content: Content) -> some View {
        content
            .onAppear {
                _ = ContinuityService.shared.startActivity(
                    type: activityType,
                    title: title,
                    userInfo: userInfo
                )
            }
            .onDisappear {
                ContinuityService.shared.endActivity()
            }
    }
}

public extension View {
    func handoff(
        type: ContinuityService.ActivityType,
        title: String,
        userInfo: [String: Any] = [:]
    ) -> some View {
        modifier(HandoffModifier(activityType: type, title: title, userInfo: userInfo))
    }
}
