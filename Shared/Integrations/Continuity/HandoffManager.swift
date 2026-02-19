// HandoffManager.swift
// Handoff support for seamless conversation continuity across Apple devices

import Foundation
import OSLog
#if canImport(UIKit)
    import UIKit
#endif
#if canImport(AppKit)
    import AppKit
#endif

// MARK: - Handoff Manager

/// Manages Handoff for seamless conversation continuity across Apple devices
@MainActor
public final class HandoffManager: ObservableObject {
    public static let shared = HandoffManager()

    private let logger = Logger(subsystem: "com.thea.app", category: "Handoff")

    // Activity types
    private let conversationActivityType = "com.thea.app.conversation"
    private let compositionActivityType = "com.thea.app.composition"
    private let artifactActivityType = "com.thea.app.artifact"
    private let browsingActivityType = "com.thea.app.browsing"

// periphery:ignore - Reserved: browsingActivityType property reserved for future feature activation

    // MARK: - Published State

    @Published public private(set) var isHandoffEnabled = true
    @Published public private(set) var currentActivity: NSUserActivity?
    @Published public private(set) var incomingActivity: IncomingHandoff?

    // MARK: - Initialization

    private init() {
        checkHandoffAvailability()
    }

    private func checkHandoffAvailability() {
        #if os(macOS)
            // Handoff is always available on macOS
            isHandoffEnabled = true
        #elseif os(iOS)
            // Check if Handoff is enabled on iOS
            isHandoffEnabled = true // Assume enabled; system handles restrictions
        #endif
    }

    // MARK: - Create Activities

    /// Start a conversation Handoff activity
    public func startConversationActivity(
        conversationId: String,
        title: String,
        preview: String,
        agentId: String? = nil
    ) {
        guard isHandoffEnabled else { return }

        let activity = NSUserActivity(activityType: conversationActivityType)
        activity.title = title
        activity.isEligibleForHandoff = true
        activity.isEligibleForSearch = true
        #if !os(macOS)
            activity.isEligibleForPrediction = true
        #endif

        // User info for state restoration
        var userInfo: [String: Any] = [
            "conversationId": conversationId,
            "title": title,
            "preview": preview,
            "timestamp": Date().timeIntervalSince1970
        ]

        if let agentId {
            userInfo["agentId"] = agentId
        }

        activity.userInfo = userInfo

        // Keywords for Spotlight
        activity.keywords = Set(["conversation", "chat", "ai", "thea"])

        // Required content attribute
        activity.requiredUserInfoKeys = Set(["conversationId"])

        // Enable continuation streams for large data
        activity.supportsContinuationStreams = true

        // Become current
        activity.becomeCurrent()
        currentActivity = activity

        logger.info("Started Handoff activity for conversation: \(conversationId)")
    }

    /// Start a composition Handoff activity (for drafts)
    public func startCompositionActivity(
        draftId: String,
        title: String,
        content: String,
        contentType: CompositionType
    ) {
        guard isHandoffEnabled else { return }

        let activity = NSUserActivity(activityType: compositionActivityType)
        activity.title = "Composing: \(title)"
        activity.isEligibleForHandoff = true
        activity.isEligibleForSearch = false

        activity.userInfo = [
            "draftId": draftId,
            "title": title,
            "content": content,
            "contentType": contentType.rawValue,
            "timestamp": Date().timeIntervalSince1970
        ]

        activity.requiredUserInfoKeys = Set(["draftId", "content"])
        activity.supportsContinuationStreams = true

        activity.becomeCurrent()
        currentActivity = activity

        logger.info("Started Handoff for composition: \(draftId)")
    }

    /// Start an artifact viewing activity
    public func startArtifactActivity(
        artifactId: String,
        title: String,
        language: String,
        preview: String
    ) {
        guard isHandoffEnabled else { return }

        let activity = NSUserActivity(activityType: artifactActivityType)
        activity.title = "Viewing: \(title)"
        activity.isEligibleForHandoff = true
        activity.isEligibleForSearch = true

        activity.userInfo = [
            "artifactId": artifactId,
            "title": title,
            "language": language,
            "preview": preview
        ]

        activity.keywords = Set(["artifact", "code", language.lowercased()])
        activity.requiredUserInfoKeys = Set(["artifactId"])

        activity.becomeCurrent()
        currentActivity = activity

        logger.info("Started Handoff for artifact: \(artifactId)")
    }

    /// Update current activity with new state
    public func updateCurrentActivity(userInfo: [String: Any]) {
        guard let activity = currentActivity else { return }

        var updatedInfo = activity.userInfo ?? [:]
        for (key, value) in userInfo {
            updatedInfo[key] = value
        }
        updatedInfo["lastUpdated"] = Date().timeIntervalSince1970

        activity.userInfo = updatedInfo
        activity.needsSave = true

        logger.debug("Updated Handoff activity")
    }

    /// Invalidate current activity
    public func invalidateCurrentActivity() {
        currentActivity?.invalidate()
        currentActivity = nil
        logger.debug("Invalidated Handoff activity")
    }

    // MARK: - Handle Incoming Handoff

    /// Handle incoming Handoff activity
    public func handleIncomingActivity(_ activity: NSUserActivity) -> Bool {
        guard let userInfo = activity.userInfo else { return false }

        switch activity.activityType {
        case conversationActivityType:
            return handleConversationHandoff(userInfo: userInfo, activity: activity)

        case compositionActivityType:
            return handleCompositionHandoff(userInfo: userInfo, activity: activity)

        case artifactActivityType:
            return handleArtifactHandoff(userInfo: userInfo, activity: activity)

        default:
            logger.warning("Unknown activity type: \(activity.activityType)")
            return false
        }
    }

    private func handleConversationHandoff(userInfo: [AnyHashable: Any], activity: NSUserActivity) -> Bool {
        guard let conversationId = userInfo["conversationId"] as? String else {
            return false
        }

        let handoff = IncomingHandoff(
            type: .conversation,
            id: conversationId,
            title: userInfo["title"] as? String,
            userInfo: userInfo,
            sourceActivity: activity
        )

        incomingActivity = handoff
        logger.info("Received conversation Handoff: \(conversationId)")

        // Request continuation stream for large data if needed
        if activity.supportsContinuationStreams {
            activity.getContinuationStreams { inputStream, outputStream, error in
                if error != nil {
                    // Stream error - logged but not critical
                    return
                }
                // Handle stream data transfer synchronously within callback
                // InputStream/OutputStream are not Sendable so must be handled here
                guard let input = inputStream, let output = outputStream else { return }
                input.open()
                output.open()
                // Process continuation stream data if needed
                // Close streams when done
                input.close()
                output.close()
            }
        }

        return true
    }

    private func handleCompositionHandoff(userInfo: [AnyHashable: Any], activity: NSUserActivity) -> Bool {
        guard let draftId = userInfo["draftId"] as? String,
              userInfo["content"] is String
        else {
            return false
        }

        // contentType available for future type-specific handling
        _ = CompositionType(rawValue: userInfo["contentType"] as? String ?? "") ?? .text

        let handoff = IncomingHandoff(
            type: .composition,
            id: draftId,
            title: userInfo["title"] as? String,
            userInfo: userInfo,
            sourceActivity: activity
        )

        incomingActivity = handoff
        logger.info("Received composition Handoff: \(draftId)")

        return true
    }

    private func handleArtifactHandoff(userInfo: [AnyHashable: Any], activity: NSUserActivity) -> Bool {
        guard let artifactId = userInfo["artifactId"] as? String else {
            return false
        }

        let handoff = IncomingHandoff(
            type: .artifact,
            id: artifactId,
            title: userInfo["title"] as? String,
            userInfo: userInfo,
            sourceActivity: activity
        )

        incomingActivity = handoff
        logger.info("Received artifact Handoff: \(artifactId)")

        return true
    }

    // periphery:ignore - Reserved: handleContinuationStream(input:output:) instance method reserved for future feature activation
    private func handleContinuationStream(input _: InputStream?, output _: OutputStream?) {
        // Handle large data transfer via continuation streams
        // This is useful for transferring full conversation history
    }

    // MARK: - Clear Incoming

    public func clearIncomingHandoff() {
        incomingActivity = nil
    }
}

// MARK: - Incoming Handoff

public struct IncomingHandoff: Identifiable {
    public let id: String
    public let type: ContinuityHandoffType
    public let title: String?
    public let userInfo: [AnyHashable: Any]
    public let sourceActivity: NSUserActivity

    public init(type: ContinuityHandoffType, id: String, title: String?, userInfo: [AnyHashable: Any], sourceActivity: NSUserActivity) {
        self.id = id
        self.type = type
        self.title = title
        self.userInfo = userInfo
        self.sourceActivity = sourceActivity
    }
}

// MARK: - Handoff Types

public enum ContinuityHandoffType: String {
    case conversation
    case composition
    case artifact
    case browsing
}

public enum CompositionType: String {
    case text
    case email
    case code
    case document
}

// MARK: - Universal Clipboard Manager

/// Manages Universal Clipboard for sharing content across devices
@MainActor
public final class UniversalClipboardManager: ObservableObject {
    public static let shared = UniversalClipboardManager()

    private let logger = Logger(subsystem: "com.thea.app", category: "UniversalClipboard")

    // MARK: - Published State

    @Published public private(set) var lastCopiedContent: ClipboardContent?
    @Published public private(set) var isUniversalClipboardEnabled = true

    // MARK: - Initialization

    private init() {}

    // MARK: - Copy Content

    /// Copy text to Universal Clipboard
    public func copyText(_ text: String, source: String = "Thea") {
        #if os(macOS)
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
        #elseif os(iOS)
            UIPasteboard.general.string = text
        #endif

        lastCopiedContent = ClipboardContent(
            type: .text,
            text: text,
            source: source,
            timestamp: Date()
        )

        logger.info("Copied text to clipboard (\(text.count) chars)")
    }

    /// Copy code with syntax highlighting hint
    public func copyCode(_ code: String, language: String, source: String = "Thea") {
        #if os(macOS)
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(code, forType: .string)

        // Also set as RTF with syntax highlighting if possible
        // This would require a syntax highlighter
        #elseif os(iOS)
            UIPasteboard.general.string = code
        #endif

        lastCopiedContent = ClipboardContent(
            type: .code,
            text: code,
            language: language,
            source: source,
            timestamp: Date()
        )

        logger.info("Copied \(language) code to clipboard")
    }

    /// Copy image to clipboard
    public func copyImage(_ imageData: Data, source: String = "Thea") {
        #if os(macOS)
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()

            if let image = NSImage(data: imageData) {
                pasteboard.writeObjects([image])
            }
        #elseif os(iOS)
            if let image = UIImage(data: imageData) {
                UIPasteboard.general.image = image
            }
        #endif

        lastCopiedContent = ClipboardContent(
            type: .image,
            imageData: imageData,
            source: source,
            timestamp: Date()
        )

        logger.info("Copied image to clipboard")
    }

    /// Copy URL to clipboard
    public func copyURL(_ url: URL, title: String? = nil, source: String = "Thea") {
        #if os(macOS)
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(url.absoluteString, forType: .URL)
            pasteboard.setString(url.absoluteString, forType: .string)
        #elseif os(iOS)
            UIPasteboard.general.url = url
            UIPasteboard.general.string = url.absoluteString
        #endif

        lastCopiedContent = ClipboardContent(
            type: .url,
            text: url.absoluteString,
            title: title,
            source: source,
            timestamp: Date()
        )

        logger.info("Copied URL to clipboard")
    }

    // MARK: - Read Content

    /// Get current clipboard text
    public func getText() -> String? {
        #if os(macOS)
            return NSPasteboard.general.string(forType: .string)
        #elseif os(iOS)
            return UIPasteboard.general.string
        #else
            return nil
        #endif
    }

    /// Get current clipboard URL
    public func getURL() -> URL? {
        #if os(macOS)
            if let urlString = NSPasteboard.general.string(forType: .URL) {
                return URL(string: urlString)
            }
            return nil
        #elseif os(iOS)
            return UIPasteboard.general.url
        #else
            return nil
        #endif
    }

    /// Check if clipboard has content
    public func hasContent() -> Bool {
        #if os(macOS)
            return NSPasteboard.general.pasteboardItems?.isEmpty == false
        #elseif os(iOS)
            return UIPasteboard.general.hasStrings || UIPasteboard.general.hasURLs || UIPasteboard.general.hasImages
        #else
            return false
        #endif
    }
}

// MARK: - Clipboard Content

public struct ClipboardContent: Identifiable {
    public let id = UUID()
    public let type: ClipboardContentType
    public var text: String?
    public var imageData: Data?
    public var language: String?
    public var title: String?
    public let source: String
    public let timestamp: Date
}

public enum ClipboardContentType {
    case text
    case code
    case image
    case url
    case file
}
