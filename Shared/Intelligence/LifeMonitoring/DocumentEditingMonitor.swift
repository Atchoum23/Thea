// DocumentEditingMonitor.swift
// Thea V2 - Document Editing Activity Monitoring
//
// Monitors document editing activity from TextEdit and other apps:
// - Documents opened, created, saved
// - File types being edited (.txt, .rtf, .rtfd, .md, etc.)
// - Time spent editing specific documents
// - Auto-save events
//
// Uses NSWorkspace notifications and FSEvents for comprehensive tracking.

import Combine
import Foundation
import os.log

#if os(macOS)
    import AppKit
#endif

// MARK: - Document Editing Monitor

/// Monitors document editing activity across text editors
@MainActor
public final class DocumentEditingMonitor: ObservableObject {
    public static let shared = DocumentEditingMonitor()

    private let logger = Logger(subsystem: "ai.thea.app", category: "DocumentEditingMonitor")

    // MARK: - Published State

    @Published public private(set) var isMonitoring = false
    @Published public private(set) var currentDocument: MonitoredDocumentInfo?
    @Published public private(set) var recentDocuments: [DocumentEditRecord] = []
    @Published public private(set) var todayStats: DocumentEditingStats = .empty

    // MARK: - Internal State

    private var currentSessionStart: Date?
    private var observers: [Any] = []
    private var sessionTimer: Timer?

    // MARK: - Tracked Apps

    /// Bundle identifiers for document editing apps
    private let trackedEditorApps: Set<String> = [
        "com.apple.TextEdit",
        "com.apple.Notes",
        "com.apple.Pages",
        "com.microsoft.Word",
        "com.google.Docs",
        "md.obsidian",
        "com.multimarkdown.composer",
        "com.ulyssesapp.mac",
        "com.bear-writer.bear",
        "com.iawriter.mac",
        "net.ia.ia-writer",
        "com.typora.typora",
        "abnerworks.Typora",
        "org.vim.MacVim"
    ]

    /// File extensions we're interested in tracking
    private let trackedExtensions: Set<String> = [
        "txt", "rtf", "rtfd", "md", "markdown",
        "doc", "docx", "pages",
        "tex", "latex", "org", "rst",
        "json", "xml", "yaml", "yml", "toml"
    ]

    // MARK: - Initialization

    private init() {
        logger.info("DocumentEditingMonitor initialized")
    }

    // MARK: - Lifecycle

    /// Start monitoring document editing activity
    public func start() async {
        guard !isMonitoring else { return }

        logger.info("Starting document editing monitoring...")

        #if os(macOS)
            await startMacOSMonitoring()
        #else
            logger.info("Document editing monitoring not available on this platform")
        #endif

        // Start session timer (update every 30 seconds)
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateCurrentSession()
            }
        }

        isMonitoring = true
        logger.info("Document editing monitoring started")
    }

    /// Stop monitoring
    public func stop() async {
        guard isMonitoring else { return }

        sessionTimer?.invalidate()
        sessionTimer = nil

        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
            #if os(macOS)
                NSWorkspace.shared.notificationCenter.removeObserver(observer)
            #endif
        }
        observers.removeAll()

        // End current session
        if let doc = currentDocument {
            endSession(for: doc)
        }

        isMonitoring = false
        logger.info("Document editing monitoring stopped")
    }

    // MARK: - macOS Monitoring

    #if os(macOS)
        private func startMacOSMonitoring() async {
            // Monitor app activation to detect when TextEdit or other editors become active
            let activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.didActivateApplicationNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                else { return }

                Task { @MainActor [weak self] in
                    self?.handleAppActivation(app)
                }
            }
            observers.append(activationObserver)

            // Monitor app deactivation
            let deactivationObserver = NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.didDeactivateApplicationNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                else { return }

                Task { @MainActor [weak self] in
                    self?.handleAppDeactivation(app)
                }
            }
            observers.append(deactivationObserver)

            // Monitor file open events via Apple Events (document-specific tracking)
            let openObserver = NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.willLaunchApplicationNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                else { return }

                Task { @MainActor [weak self] in
                    self?.handleAppLaunch(app)
                }
            }
            observers.append(openObserver)

            // Use DistributedNotificationCenter for document-level events
            DistributedNotificationCenter.default().addObserver(
                forName: NSNotification.Name("com.apple.Carbon.TISNotifySelectedKeyboardInputSourceChanged"),
                object: nil,
                queue: .main
            ) { [weak self] _ in
                // Keyboard layout change can indicate typing activity
                Task { @MainActor [weak self] in
                    self?.handleTypingActivity()
                }
            }

            // Check if a tracked editor is already frontmost
            if let frontmost = NSWorkspace.shared.frontmostApplication {
                handleAppActivation(frontmost)
            }

            logger.info("macOS document editing monitoring configured")
        }

        private func handleAppActivation(_ app: NSRunningApplication) {
            guard let bundleId = app.bundleIdentifier,
                  trackedEditorApps.contains(bundleId)
            else {
                // Not a tracked editor - end any current session
                if let doc = currentDocument {
                    endSession(for: doc)
                }
                return
            }

            let appName = app.localizedName ?? "Unknown Editor"

            // Try to get the current document from the app
            let documentInfo = getActiveDocument(for: app) ?? MonitoredDocumentInfo(
                path: nil,
                name: "Untitled",
                fileType: .plainText,
                appBundleId: bundleId,
                appName: appName
            )

            // End previous session if different document
            if let current = currentDocument,
               current.path != documentInfo.path || current.appBundleId != documentInfo.appBundleId
            {
                endSession(for: current)
            }

            // Start new session
            if currentDocument?.path != documentInfo.path {
                startSession(for: documentInfo)
            }
        }

        private func handleAppDeactivation(_ app: NSRunningApplication) {
            guard let bundleId = app.bundleIdentifier,
                  trackedEditorApps.contains(bundleId)
            else { return }

            // End current session when leaving a tracked editor
            if let doc = currentDocument, doc.appBundleId == bundleId {
                endSession(for: doc)
            }
        }

        private func handleAppLaunch(_ app: NSRunningApplication) {
            guard let bundleId = app.bundleIdentifier,
                  trackedEditorApps.contains(bundleId)
            else { return }

            logger.debug("Tracked editor launched: \(app.localizedName ?? bundleId)")
        }

        private func handleTypingActivity() {
            // Record typing activity for current document session
            if currentDocument != nil {
                // This indicates active editing is happening
                logger.debug("Typing activity detected in document editor")
            }
        }

        /// Attempt to get the active document from a running application
        private func getActiveDocument(for app: NSRunningApplication) -> MonitoredDocumentInfo? {
            guard let bundleId = app.bundleIdentifier else { return nil }
            let appName = app.localizedName ?? "Unknown"

            // Use AppleScript to query the frontmost document
            // This works for TextEdit and other scriptable apps
            let script = """
                tell application "\(appName)"
                    try
                        set docPath to path of front document
                        set docName to name of front document
                        return docPath & "|" & docName
                    on error
                        return ""
                    end try
                end tell
                """

            var error: NSDictionary?
            if let appleScript = NSAppleScript(source: script) {
                let result = appleScript.executeAndReturnError(&error)
                if let output = result.stringValue, !output.isEmpty {
                    let parts = output.components(separatedBy: "|")
                    if parts.count >= 2 {
                        let path = parts[0]
                        let name = parts[1]
                        let fileType = DocumentFileType(from: URL(fileURLWithPath: path).pathExtension)

                        return MonitoredDocumentInfo(
                            path: path,
                            name: name,
                            fileType: fileType,
                            appBundleId: bundleId,
                            appName: appName
                        )
                    }
                }
            }

            // Fallback: Return generic document info
            return nil
        }
    #endif

    // MARK: - Session Management

    private func startSession(for doc: MonitoredDocumentInfo) {
        currentDocument = doc
        currentSessionStart = Date()

        logger.debug("Started editing session: \(doc.name) in \(doc.appName)")

        // Emit start event
        let event = LifeEvent(
            type: .documentActivity,
            source: .appUsage,
            summary: "Started editing \(doc.name) in \(doc.appName)",
            data: [
                "action": "open",
                "documentName": doc.name,
                "documentPath": doc.path ?? "unsaved",
                "fileType": doc.fileType.rawValue,
                "app": doc.appName,
                "appBundleId": doc.appBundleId
            ],
            significance: .minor
        )
        LifeMonitoringCoordinator.shared.submitEvent(event)
    }

    private func endSession(for doc: MonitoredDocumentInfo) {
        guard let start = currentSessionStart else { return }

        let duration = Date().timeIntervalSince(start)

        // Only record sessions longer than 5 seconds
        guard duration >= 5 else {
            currentDocument = nil
            currentSessionStart = nil
            return
        }

        let record = DocumentEditRecord(
            id: UUID(),
            document: doc,
            startTime: start,
            endTime: Date(),
            duration: duration,
            estimatedWordCount: nil
        )

        // Add to recent documents
        recentDocuments.insert(record, at: 0)

        // Trim history
        if recentDocuments.count > 100 {
            recentDocuments = Array(recentDocuments.prefix(100))
        }

        // Update today's stats
        updateTodayStats(with: record)

        // Emit end event
        let event = LifeEvent(
            type: .documentActivity,
            source: .appUsage,
            summary: "Edited \(doc.name) for \(formatDuration(duration))",
            data: [
                "action": "close",
                "documentName": doc.name,
                "documentPath": doc.path ?? "unsaved",
                "fileType": doc.fileType.rawValue,
                "app": doc.appName,
                "appBundleId": doc.appBundleId,
                "durationSeconds": String(Int(duration))
            ],
            significance: duration > 300 ? .moderate : .minor
        )
        LifeMonitoringCoordinator.shared.submitEvent(event)

        currentDocument = nil
        currentSessionStart = nil

        logger.debug("Ended editing session for \(doc.name): \(Int(duration))s")
    }

    private func updateCurrentSession() {
        guard currentDocument != nil, currentSessionStart != nil else { return }
        // Periodic update - could track word count changes here
    }

    private func updateTodayStats(with record: DocumentEditRecord) {
        var stats = todayStats

        // Reset if new day
        if !Calendar.current.isDateInToday(stats.date) {
            stats = .empty
        }

        stats.date = Date()
        stats.totalEditingTime += record.duration
        stats.documentsEdited += 1
        stats.editsByFileType[record.document.fileType, default: 0] += 1
        stats.editsByApp[record.document.appName, default: 0] += record.duration

        todayStats = stats
    }

    // MARK: - Analytics

    /// Get editing statistics for a time period
    public func getStats(for period: StatsPeriod) -> DocumentEditingStats {
        let cutoff: Date
        switch period {
        case .today:
            cutoff = Calendar.current.startOfDay(for: Date())
        case .week:
            cutoff = Date().addingTimeInterval(-7 * 24 * 3600)
        case .month:
            cutoff = Date().addingTimeInterval(-30 * 24 * 3600)
        }

        let relevantRecords = recentDocuments.filter { $0.startTime >= cutoff }

        var stats = DocumentEditingStats.empty
        stats.date = Date()

        for record in relevantRecords {
            stats.totalEditingTime += record.duration
            stats.documentsEdited += 1
            stats.editsByFileType[record.document.fileType, default: 0] += 1
            stats.editsByApp[record.document.appName, default: 0] += record.duration
        }

        return stats
    }

    /// Get most edited documents
    public func getMostEditedDocuments(limit: Int = 10) -> [DocumentEditSummary] {
        // Aggregate by document path
        var docTotals: [String: (doc: MonitoredDocumentInfo, duration: TimeInterval, sessions: Int)] = [:]

        for record in recentDocuments {
            let key = record.document.path ?? record.document.name
            if var existing = docTotals[key] {
                existing.duration += record.duration
                existing.sessions += 1
                docTotals[key] = existing
            } else {
                docTotals[key] = (record.document, record.duration, 1)
            }
        }

        return docTotals.values
            .map { DocumentEditSummary(document: $0.doc, totalDuration: $0.duration, sessionCount: $0.sessions) }
            .sorted { $0.totalDuration > $1.totalDuration }
            .prefix(limit)
            .map { $0 }
    }

    // MARK: - Manual Events

    /// Record a document save event (can be called from file monitoring)
    public func recordDocumentSave(path: String, appBundleId: String?) {
        let url = URL(fileURLWithPath: path)
        let name = url.lastPathComponent
        let fileType = DocumentFileType(from: url.pathExtension)

        let event = LifeEvent(
            type: .documentActivity,
            source: .appUsage,
            summary: "Saved document: \(name)",
            data: [
                "action": "save",
                "documentName": name,
                "documentPath": path,
                "fileType": fileType.rawValue,
                "appBundleId": appBundleId ?? "unknown"
            ],
            significance: .minor
        )
        LifeMonitoringCoordinator.shared.submitEvent(event)

        logger.debug("Document saved: \(name)")
    }

    // MARK: - Helpers

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "\(Int(seconds))s"
        }
    }

    public enum StatsPeriod {
        case today
        case week
        case month
    }
}

// MARK: - Supporting Types

/// Information about a monitored document
public struct MonitoredDocumentInfo: Codable, Sendable, Equatable {
    public let path: String?
    public let name: String
    public let fileType: DocumentFileType
    public let appBundleId: String
    public let appName: String

    public init(path: String?, name: String, fileType: DocumentFileType, appBundleId: String, appName: String) {
        self.path = path
        self.name = name
        self.fileType = fileType
        self.appBundleId = appBundleId
        self.appName = appName
    }
}

/// Document file type categories
public enum DocumentFileType: String, Codable, CaseIterable, Sendable {
    case plainText = "txt"
    case richText = "rtf"
    case markdown = "md"
    case wordDocument = "doc"
    case pages = "pages"
    case latex = "tex"
    case json = "json"
    case xml = "xml"
    case yaml = "yaml"
    case other = "other"

    public init(from pathExtension: String) {
        switch pathExtension.lowercased() {
        case "txt", "text":
            self = .plainText
        case "rtf", "rtfd":
            self = .richText
        case "md", "markdown", "mdown":
            self = .markdown
        case "doc", "docx":
            self = .wordDocument
        case "pages":
            self = .pages
        case "tex", "latex":
            self = .latex
        case "json":
            self = .json
        case "xml", "html", "xhtml":
            self = .xml
        case "yaml", "yml":
            self = .yaml
        default:
            self = .other
        }
    }

    public var displayName: String {
        switch self {
        case .plainText: return "Plain Text"
        case .richText: return "Rich Text"
        case .markdown: return "Markdown"
        case .wordDocument: return "Word Document"
        case .pages: return "Pages"
        case .latex: return "LaTeX"
        case .json: return "JSON"
        case .xml: return "XML"
        case .yaml: return "YAML"
        case .other: return "Other"
        }
    }
}

/// Record of a document editing session
public struct DocumentEditRecord: Identifiable, Sendable {
    public let id: UUID
    public let document: MonitoredDocumentInfo
    public let startTime: Date
    public let endTime: Date
    public let duration: TimeInterval
    public let estimatedWordCount: Int?

    public var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

/// Summary of editing activity for a specific document
public struct DocumentEditSummary: Identifiable, Sendable {
    public var id: String { document.path ?? document.name }
    public let document: MonitoredDocumentInfo
    public let totalDuration: TimeInterval
    public let sessionCount: Int

    public var formattedDuration: String {
        let hours = Int(totalDuration) / 3600
        let minutes = (Int(totalDuration) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

/// Daily document editing statistics
public struct DocumentEditingStats: Sendable {
    public var date: Date
    public var totalEditingTime: TimeInterval
    public var documentsEdited: Int
    public var editsByFileType: [DocumentFileType: Int]
    public var editsByApp: [String: TimeInterval]

    public static var empty: DocumentEditingStats {
        DocumentEditingStats(
            date: Date(),
            totalEditingTime: 0,
            documentsEdited: 0,
            editsByFileType: [:],
            editsByApp: [:]
        )
    }

    public var formattedEditingTime: String {
        let hours = Int(totalEditingTime) / 3600
        let minutes = (Int(totalEditingTime) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}
