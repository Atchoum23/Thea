// ClipboardMonitor.swift
// Thea V2 - Clipboard Monitoring Service
//
// Monitors the system clipboard for changes and captures content
// for THEA's life monitoring system.

#if os(macOS)

import AppKit
import Foundation
import os.log

// MARK: - Clipboard Monitor Protocol

/// Delegate that receives notifications when the system clipboard content changes.
public protocol ClipboardMonitorDelegate: AnyObject, Sendable {
    nonisolated func clipboardMonitor(_ _monitor: ClipboardMonitor, didCapture content: MonitoredClipboardContent)
}

// MARK: - Clipboard Monitor

/// Monitors clipboard changes on macOS
public actor ClipboardMonitor {
    private let logger = Logger(subsystem: "ai.thea.app", category: "ClipboardMonitor")

    public weak var delegate: ClipboardMonitorDelegate?

    /// Set the delegate (for use from MainActor contexts)
    public func setDelegate(_ delegate: ClipboardMonitorDelegate?) {
        self.delegate = delegate
    }

    private var isRunning = false
    private var monitorTask: Task<Void, Never>?
    private var lastChangeCount: Int = 0

    // Configuration — base 5s, scaled by EnergyAdaptiveThrottler at runtime
    private let baseIntervalSeconds: Double = 5.0 // Was 500ms, now 5s for battery efficiency
    private let maxContentLength = 10000 // Max chars to capture

    // Privacy - patterns to skip
    private let sensitivePatterns: [NSRegularExpression] = {
        let patterns = [
            // Passwords
            "^(?=.*[A-Za-z])(?=.*\\d)[A-Za-z\\d@$!%*#?&]{8,}$",
            // Credit cards
            "\\b(?:\\d[ -]*?){13,16}\\b",
            // SSN
            "\\b\\d{3}-\\d{2}-\\d{4}\\b",
            // API keys (common patterns)
            "(?i)(api[_-]?key|apikey|secret[_-]?key|access[_-]?token)[\"']?\\s*[:=]\\s*[\"']?[a-zA-Z0-9_-]{20,}",
            // AWS keys
            "(?i)AKIA[0-9A-Z]{16}",
            // Private keys
            "-----BEGIN (RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----"
        ]
        return patterns.compactMap { try? NSRegularExpression(pattern: $0) }
    }()

    public init() {}

    // MARK: - Lifecycle

    public func start() async {
        guard !isRunning else {
            logger.warning("Clipboard monitor already running")
            return
        }

        isRunning = true
        lastChangeCount = NSPasteboard.general.changeCount

        monitorTask = Task { [weak self] in
            await self?.monitorLoop()
        }

        logger.info("Clipboard monitor started")
    }

    public func stop() async {
        isRunning = false
        monitorTask?.cancel()
        monitorTask = nil
        logger.info("Clipboard monitor stopped")
    }

    // MARK: - Monitoring Loop

    private func monitorLoop() async {
        while isRunning && !Task.isCancelled {
            let currentChangeCount = await MainActor.run {
                NSPasteboard.general.changeCount
            }

            if currentChangeCount != lastChangeCount {
                lastChangeCount = currentChangeCount
                await captureMonitoredClipboardContent()
            }

            let multiplier = await MainActor.run { EnergyAdaptiveThrottler.shared.intervalMultiplier }
            let interval = baseIntervalSeconds * multiplier
            try? await Task.sleep(for: .seconds(interval))
        }
    }

    private func captureMonitoredClipboardContent() async {
        // Get all clipboard data and source app on main actor
        let clipboardData = await MainActor.run {
            let pasteboard = NSPasteboard.general
            let sourceApp = NSWorkspace.shared.frontmostApplication?.localizedName

            // Capture clipboard data
            return ClipboardData(
                textContent: pasteboard.string(forType: .string),
                urlContent: pasteboard.string(forType: .URL),
                fileURLs: pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
                hasImage: pasteboard.data(forType: .tiff) != nil || pasteboard.data(forType: .png) != nil,
                sourceApp: sourceApp
            )
        }

        // Determine content type and extract
        var content: MonitoredClipboardContent?

        // Check for text
        if let string = clipboardData.textContent {
            // Check if it's sensitive
            if isSensitiveContent(string) {
                logger.debug("Skipping sensitive clipboard content")
                return
            }

            // Truncate if too long
            let truncated = String(string.prefix(maxContentLength))
            let preview = String(string.prefix(200))

            content = MonitoredClipboardContent(
                type: .text,
                preview: preview,
                fullContent: truncated,
                characterCount: string.count,
                sourceApp: clipboardData.sourceApp
            )
        }
        // Check for URL
        else if let url = clipboardData.urlContent {
            content = MonitoredClipboardContent(
                type: .url,
                preview: url,
                fullContent: url,
                sourceApp: clipboardData.sourceApp
            )
        }
        // Check for file URLs
        else if let fileURLs = clipboardData.fileURLs, !fileURLs.isEmpty {
            let paths = fileURLs.map(\.lastPathComponent).joined(separator: ", ")
            content = MonitoredClipboardContent(
                type: .files,
                preview: paths,
                fullContent: fileURLs.map(\.path).joined(separator: "\n"),
                fileCount: fileURLs.count,
                sourceApp: clipboardData.sourceApp
            )
        }
        // Check for image
        else if clipboardData.hasImage {
            content = MonitoredClipboardContent(
                type: .image,
                preview: "[Image]",
                sourceApp: clipboardData.sourceApp
            )
        }

        if let content {
            delegate?.clipboardMonitor(self, didCapture: content)
        }
    }

    /// Helper struct to capture clipboard data on main actor
    private struct ClipboardData: Sendable {
        let textContent: String?
        let urlContent: String?
        let fileURLs: [URL]?
        let hasImage: Bool
        let sourceApp: String?
    }

    // MARK: - Privacy

    private func isSensitiveContent(_ text: String) -> Bool {
        // Check against sensitive patterns
        let range = NSRange(text.startIndex..., in: text)

        for pattern in sensitivePatterns {
            if pattern.firstMatch(in: text, range: range) != nil {
                return true
            }
        }

        // Check for common sensitive keywords
        let sensitiveKeywords = [
            "password", "passwd", "secret", "token", "api_key", "apikey",
            "private_key", "ssh_key", "credentials"
        ]

        let lowercased = text.lowercased()
        for keyword in sensitiveKeywords {
            if lowercased.contains(keyword) {
                return true
            }
        }

        return false
    }

}

// MARK: - Clipboard Monitor Content
// Note: These types are specific to ClipboardMonitor and prefixed to avoid conflict
// with ClipboardContextSnapshot types in ContextSnapshot.swift

public struct MonitoredClipboardContent: Sendable {
    public let type: MonitoredClipboardContentType
    public let preview: String
    public let fullContent: String?
    public let characterCount: Int?
    public let fileCount: Int?
    public let sourceApp: String?
    public let timestamp: Date

    public init(
        type: MonitoredClipboardContentType,
        preview: String,
        fullContent: String? = nil,
        characterCount: Int? = nil,
        fileCount: Int? = nil,
        sourceApp: String? = nil,
        timestamp: Date = Date()
    ) {
        self.type = type
        self.preview = preview
        self.fullContent = fullContent
        self.characterCount = characterCount
        self.fileCount = fileCount
        self.sourceApp = sourceApp
        self.timestamp = timestamp
    }
}

public enum MonitoredClipboardContentType: String, Codable, Sendable {
    case text
    case url
    case image
    case files
    case other
}


#endif
