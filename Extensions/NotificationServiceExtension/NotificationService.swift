//
//  NotificationService.swift
//  TheaNotificationServiceExtension
//
//  Created by Thea
//

@preconcurrency import UserNotifications

/// Notification Service Extension for Thea
/// Intercepts push notifications to add AI-powered enhancements
class NotificationService: UNNotificationServiceExtension {
    // MARK: - Properties

    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var bestAttemptContent: UNMutableNotificationContent?

    // App Group for shared data
    private let appGroupID = "group.app.theathe"

    // MARK: - Service Extension Methods

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)

        guard let bestAttemptContent else {
            contentHandler(request.content)
            return
        }

        // Capture references for async callback
        nonisolated(unsafe) let handler = contentHandler
        nonisolated(unsafe) let weakSelf = self

        // Process the notification
        processNotification(bestAttemptContent, request: request) { processedContent in
            // Log the notification for Thea's awareness
            weakSelf.logNotification(request: request, content: processedContent)

            // Deliver the notification
            handler(processedContent)
        }
    }

    override func serviceExtensionTimeWillExpire() {
        // Called just before the extension will be terminated by the system.
        // Use this as an opportunity to deliver your "best attempt" at modified content.
        if let contentHandler, let bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }

    // MARK: - Notification Processing

    private func processNotification(
        _ content: UNMutableNotificationContent,
        request _: UNNotificationRequest,
        completion: @escaping @Sendable (UNMutableNotificationContent) -> Void
    ) {
        // Get notification type from userInfo
        let userInfo = content.userInfo

        // Check if this is a Thea notification
        if let theaType = userInfo["thea_type"] as? String {
            processTheaNotification(content, type: theaType, completion: completion)
            return
        }

        // Process third-party notifications
        processThirdPartyNotification(content, completion: completion)
    }

    private func processTheaNotification(
        _ content: UNMutableNotificationContent,
        type: String,
        completion: @escaping @Sendable (UNMutableNotificationContent) -> Void
    ) {
        // Handle different Thea notification types
        switch type {
        case "ai_response":
            // AI response completed - add summary
            if let summary = content.userInfo["summary"] as? String {
                content.subtitle = summary
            }

        case "user_input_required":
            // Mark as requiring action
            content.interruptionLevel = .timeSensitive

        case "context_insight":
            // Contextual insight - add category for actions
            content.categoryIdentifier = "THEA_INSIGHT"

        case "reminder":
            // Smart reminder
            content.interruptionLevel = .passive

        default:
            break
        }

        completion(content)
    }

    private func processThirdPartyNotification(
        _ content: UNMutableNotificationContent,
        completion: @escaping @Sendable (UNMutableNotificationContent) -> Void
    ) {
        // Load user preferences for notification enhancement
        let prefs = loadNotificationPreferences()

        // Check if smart summarization is enabled
        if prefs.enableSmartSummary {
            // Attempt to summarize long notification body
            if content.body.count > 100 {
                let summarized = summarizeText(content.body)
                content.body = summarized
            }
        }

        // Check if smart grouping is enabled
        if prefs.enableSmartGrouping {
            // Add threading identifier based on content analysis
            let threadId = generateThreadId(for: content)
            content.threadIdentifier = threadId
        }

        // Check if priority inference is enabled
        if prefs.enablePriorityInference {
            let priority = inferPriority(from: content)
            content.interruptionLevel = priority
        }

        // Add download attachments if present
        downloadAttachments(for: content) { updatedContent in
            completion(updatedContent)
        }
    }

    // MARK: - Smart Features

    private func summarizeText(_ text: String) -> String {
        // Simple summarization (would use ML model in production)
        if text.count > 200 {
            let sentences = text.components(separatedBy: ". ")
            if sentences.count > 2 {
                return sentences.prefix(2).joined(separator: ". ") + "..."
            }
        }
        return text
    }

    private func generateThreadId(for content: UNNotificationContent) -> String {
        // Generate thread ID based on content characteristics
        let title = content.title.lowercased()

        // Keywords for common notification categories
        let categories: [String: [String]] = [
            "messages": ["message", "chat", "text", "reply"],
            "email": ["email", "mail", "inbox"],
            "social": ["like", "comment", "follow", "mention"],
            "calendar": ["event", "reminder", "meeting"],
            "shopping": ["order", "delivery", "shipped"]
        ]

        for (category, keywords) in categories {
            if keywords.contains(where: { title.contains($0) }) {
                return "thea-\(category)"
            }
        }

        return "thea-general"
    }

    private func inferPriority(from content: UNNotificationContent) -> UNNotificationInterruptionLevel {
        let text = (content.title + " " + content.body).lowercased()

        // High priority keywords
        let urgentKeywords = ["urgent", "emergency", "important", "asap", "critical", "immediate"]
        if urgentKeywords.contains(where: { text.contains($0) }) {
            return .timeSensitive
        }

        // Low priority keywords
        let passiveKeywords = ["reminder", "weekly", "digest", "summary", "newsletter"]
        if passiveKeywords.contains(where: { text.contains($0) }) {
            return .passive
        }

        return .active
    }

    private func downloadAttachments(
        for content: UNMutableNotificationContent,
        completion: @escaping @Sendable (UNMutableNotificationContent) -> Void
    ) {
        guard let attachmentURLString = content.userInfo["attachment_url"] as? String,
              let attachmentURL = URL(string: attachmentURLString)
        else {
            completion(content)
            return
        }

        // Download attachment
        let task = URLSession.shared.downloadTask(with: attachmentURL) { [content] localURL, _, error in
            guard error == nil, let localURL else {
                DispatchQueue.main.async {
                    completion(content)
                }
                return
            }

            // Move to temp location with proper extension
            let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(attachmentURL.pathExtension)

            do {
                try FileManager.default.moveItem(at: localURL, to: tempURL)
                let attachment = try UNNotificationAttachment(identifier: "attachment", url: tempURL)
                content.attachments = [attachment]
            } catch {
                // Failed to create attachment
            }

            DispatchQueue.main.async {
                completion(content)
            }
        }
        task.resume()
    }

    // MARK: - Logging

    private func logNotification(request: UNNotificationRequest, content: UNNotificationContent) {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            return
        }

        let logDir = containerURL.appendingPathComponent("NotificationLogs", isDirectory: true)
        try? FileManager.default.createDirectory(at: logDir, withIntermediateDirectories: true)

        let entry: [String: Any] = [
            "id": request.identifier,
            "title": content.title,
            "body": content.body,
            "timestamp": Date().timeIntervalSince1970,
            "categoryIdentifier": content.categoryIdentifier,
            "threadIdentifier": content.threadIdentifier
        ]

        // Append to log file
        let logPath = logDir.appendingPathComponent("notifications.jsonl")

        if let data = try? JSONSerialization.data(withJSONObject: entry),
           let line = String(data: data, encoding: .utf8)
        {
            let handle = try? FileHandle(forWritingTo: logPath)
            if let handle {
                handle.seekToEndOfFile()
                handle.write((line + "\n").data(using: .utf8)!)
                try? handle.close()
            } else {
                try? (line + "\n").write(to: logPath, atomically: true, encoding: .utf8)
            }
        }
    }

    // MARK: - Preferences

    private struct NotificationPreferences {
        var enableSmartSummary: Bool = true
        var enableSmartGrouping: Bool = true
        var enablePriorityInference: Bool = true
    }

    private func loadNotificationPreferences() -> NotificationPreferences {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            return NotificationPreferences()
        }

        let prefsPath = containerURL.appendingPathComponent("notification_prefs.json")

        guard let data = try? Data(contentsOf: prefsPath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return NotificationPreferences()
        }

        return NotificationPreferences(
            enableSmartSummary: json["smartSummary"] as? Bool ?? true,
            enableSmartGrouping: json["smartGrouping"] as? Bool ?? true,
            enablePriorityInference: json["priorityInference"] as? Bool ?? true
        )
    }
}
