// ClipboardHistoryManager.swift
// Thea — Persistent Clipboard History & Pinboard Manager

import CryptoKit
import Foundation
import os.log
@preconcurrency import SwiftData

#if os(macOS)
    import AppKit
#elseif canImport(UIKit)
    import UIKit
#endif

private let clipLogger = Logger(subsystem: "ai.thea.app", category: "ClipboardHistory")

@MainActor
final class ClipboardHistoryManager: ObservableObject {
    static let shared = ClipboardHistoryManager()

    var modelContext: ModelContext?

    // MARK: - Published State

    @Published var recentEntries: [TheaClipEntry] = []
    @Published var pinboards: [TheaClipPinboard] = []
    @Published var isRecording: Bool = true
    @Published var pasteStack: [TheaClipEntry] = []

    // MARK: - Configuration (reads from SettingsManager)

    private var settings: SettingsManager { SettingsManager.shared }

    // MARK: - Privacy Patterns (reused from ClipboardMonitor)

    private let sensitivePatterns: [NSRegularExpression] = {
        let patterns = [
            "^(?=.*[A-Za-z])(?=.*\\d)[A-Za-z\\d@$!%*#?&]{8,}$",
            "\\b(?:\\d[ -]*?){13,16}\\b",
            "\\b\\d{3}-\\d{2}-\\d{4}\\b",
            "(?i)(api[_-]?key|apikey|secret[_-]?key|access[_-]?token)[\"']?\\s*[:=]\\s*[\"']?[a-zA-Z0-9_-]{20,}",
            "(?i)AKIA[0-9A-Z]{16}",
            "-----BEGIN (RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----"
        ]
        return patterns.compactMap { try? NSRegularExpression(pattern: $0) }
    }()

    private init() {}

    // MARK: - Setup

    func setModelContext(_ context: ModelContext) {
        modelContext = context
        loadRecentEntries()
        loadPinboards()
        isRecording = settings.clipboardHistoryEnabled

        // Configure iCloud sync
        TheaClipSyncService.shared.configure(modelContext: context)

        // Pull remote changes on startup
        Task { await TheaClipSyncService.shared.pullChanges() }

        #if os(macOS)
            connectToClipboardObserver()
        #endif

        clipLogger.info("ClipboardHistoryManager initialized")
    }

    #if os(macOS)
        private func connectToClipboardObserver() {
            ClipboardObserver.shared.onClipboardChanged = { [weak self] item in
                Task { @MainActor in
                    self?.handleClipboardChange(item)
                }
            }
        }

        private func handleClipboardChange(_ item: ClipboardItem) {
            guard isRecording, settings.clipboardHistoryEnabled else { return }

            // Check app exclusion
            if let sourceBundle = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
               settings.clipboardExcludedApps.contains(sourceBundle)
            {
                clipLogger.debug("Skipping excluded app: \(sourceBundle)")
                return
            }

            // Skip images if disabled
            if item.contentType == .image, !settings.clipboardRecordImages {
                return
            }

            // Map ClipboardItem to TheaClipEntry
            let contentType: TheaClipContentType
            switch item.contentType {
            case .text: contentType = .text
            case .richText: contentType = .richText
            case .html: contentType = .html
            case .url: contentType = .url
            case .image: contentType = .image
            case .file: contentType = .file
            }

            let textContent = item.textContent
            let imageData = item.imageData

            // Dedup: check against last entry
            let hash = TheaClipEntry.contentHash(
                text: textContent,
                imageData: imageData,
                fileNames: item.fileURLs?.map(\.lastPathComponent) ?? []
            )
            if let lastEntry = recentEntries.first,
               TheaClipEntry.contentHash(
                   text: lastEntry.textContent,
                   imageData: lastEntry.imageData,
                   fileNames: lastEntry.fileNames
               ) == hash
            {
                // Duplicate of last entry — update access time
                lastEntry.lastAccessedAt = Date()
                lastEntry.accessCount += 1
                saveContext()
                return
            }

            // Detect sensitivity
            let isSensitive = textContent.map { isSensitiveContent($0) } ?? false

            // Build preview
            let preview: String
            switch contentType {
            case .text, .richText, .html:
                preview = String((textContent ?? "").prefix(200))
            case .url:
                preview = textContent ?? "URL"
            case .image:
                preview = "[Image]"
            case .file:
                preview = item.fileURLs?.map(\.lastPathComponent).joined(separator: ", ") ?? "File"
            case .color:
                preview = "[Color]"
            }

            let entry = TheaClipEntry(
                contentType: contentType,
                textContent: textContent,
                htmlContent: item.contentType == .html ? textContent : nil,
                urlString: item.url?.absoluteString,
                imageData: imageData,
                fileNames: item.fileURLs?.map(\.lastPathComponent) ?? [],
                filePaths: item.fileURLs?.map(\.path) ?? [],
                sourceAppBundleID: NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
                sourceAppName: item.sourceApp,
                characterCount: textContent?.count ?? 0,
                byteCount: textContent?.utf8.count ?? (imageData?.count ?? 0),
                isPinned: false,
                isFavorite: false,
                isSensitive: isSensitive,
                sensitiveExpiresAt: isSensitive ? Date().addingTimeInterval(
                    TimeInterval(settings.clipboardSensitiveExpiryHours) * 3600
                ) : nil,
                previewText: preview
            )

            modelContext?.insert(entry)

            // AI categorization (if enabled)
            ClipboardIntelligence.shared.processEntry(entry)

            saveContext()
            recentEntries.insert(entry, at: 0)

            // Push to iCloud (non-sensitive only)
            if !entry.isSensitive {
                Task { await TheaClipSyncService.shared.pushEntry(entry) }
            }

            // Trim history
            trimHistory()

            clipLogger.debug("Recorded clipboard entry: \(contentType.rawValue)")
        }
    #endif

    // MARK: - CRUD

    func loadRecentEntries(limit: Int = 200) {
        guard let context = modelContext else { return }
        var descriptor = FetchDescriptor<TheaClipEntry>()
        descriptor.sortBy = [SortDescriptor(\.createdAt, order: .reverse)]
        descriptor.fetchLimit = limit
        do {
            recentEntries = try context.fetch(descriptor)
        } catch {
            clipLogger.error("Failed to load entries: \(error.localizedDescription)")
            recentEntries = []
        }
    }

    func loadPinboards() {
        guard let context = modelContext else { return }
        var descriptor = FetchDescriptor<TheaClipPinboard>()
        descriptor.sortBy = [SortDescriptor(\.sortOrder)]
        do {
            pinboards = try context.fetch(descriptor)
        } catch {
            clipLogger.error("Failed to load pinboards: \(error.localizedDescription)")
            pinboards = []
        }
    }

    func deleteEntry(_ entry: TheaClipEntry) {
        let entryID = entry.id
        modelContext?.delete(entry)
        saveContext()
        recentEntries.removeAll { $0.id == entryID }
        Task { await TheaClipSyncService.shared.deleteRemoteEntry(entryID) }
    }

    func togglePin(_ entry: TheaClipEntry) {
        entry.isPinned.toggle()
        saveContext()
        Task { await TheaClipSyncService.shared.pushEntry(entry) }
    }

    func toggleFavorite(_ entry: TheaClipEntry) {
        entry.isFavorite.toggle()
        saveContext()
        Task { await TheaClipSyncService.shared.pushEntry(entry) }
    }

    func clearHistory(keepPinned: Bool = true) {
        guard let context = modelContext else { return }
        let entriesToDelete = keepPinned ? recentEntries.filter { !$0.isPinned } : recentEntries
        for entry in entriesToDelete {
            let entryID = entry.id
            context.delete(entry)
            Task { await TheaClipSyncService.shared.deleteRemoteEntry(entryID) }
        }
        saveContext()
        recentEntries = keepPinned ? recentEntries.filter(\.isPinned) : []
        clipLogger.info("History cleared (keepPinned: \(keepPinned))")
    }

    func deleteExpiredSensitiveEntries() {
        guard let context = modelContext else { return }
        let now = Date()
        let expired = recentEntries.filter { entry in
            entry.isSensitive && entry.sensitiveExpiresAt != nil && entry.sensitiveExpiresAt! < now
        }
        for entry in expired {
            context.delete(entry)
        }
        if !expired.isEmpty {
            saveContext()
            recentEntries.removeAll { entry in
                expired.contains { $0.id == entry.id }
            }
            clipLogger.info("Deleted \(expired.count) expired sensitive entries")
        }
    }

    // MARK: - Pinboards

    func createPinboard(name: String, icon: String = "pin.fill", colorHex: String = "#F5A623") -> TheaClipPinboard {
        let pinboard = TheaClipPinboard(
            name: name,
            icon: icon,
            colorHex: colorHex,
            sortOrder: pinboards.count
        )
        modelContext?.insert(pinboard)
        saveContext()
        pinboards.append(pinboard)
        Task { await TheaClipSyncService.shared.pushPinboard(pinboard) }
        return pinboard
    }

    func deletePinboard(_ pinboard: TheaClipPinboard) {
        let pinboardID = pinboard.id
        modelContext?.delete(pinboard)
        saveContext()
        Task { await TheaClipSyncService.shared.deleteRemotePinboard(pinboardID) }
        pinboards.removeAll { $0.id == pinboard.id }
    }

    func addToPinboard(_ entry: TheaClipEntry, pinboard: TheaClipPinboard) {
        // Avoid duplicate junction entries
        let existing = entry.pinboardEntries.contains { $0.pinboard?.id == pinboard.id }
        guard !existing else { return }

        let junction = TheaClipPinboardEntry(
            sortOrder: pinboard.entries.count,
            clipEntry: entry,
            pinboard: pinboard
        )
        modelContext?.insert(junction)
        saveContext()
        Task { await TheaClipSyncService.shared.pushPinboard(pinboard) }
    }

    func removeFromPinboard(_ entry: TheaClipEntry, pinboard: TheaClipPinboard) {
        guard let junction = entry.pinboardEntries.first(where: { $0.pinboard?.id == pinboard.id }) else { return }
        modelContext?.delete(junction)
        saveContext()
        Task { await TheaClipSyncService.shared.pushPinboard(pinboard) }
    }

    // MARK: - Search

    func search(query: String, contentType: TheaClipContentType? = nil, dateRange: ClosedRange<Date>? = nil) -> [TheaClipEntry] {
        guard let context = modelContext else { return [] }

        var descriptor = FetchDescriptor<TheaClipEntry>()
        descriptor.sortBy = [SortDescriptor(\.createdAt, order: .reverse)]

        do {
            var results = try context.fetch(descriptor)

            // Filter by query
            if !query.isEmpty {
                let lowered = query.lowercased()
                results = results.filter { entry in
                    entry.textContent?.lowercased().contains(lowered) == true
                        || entry.previewText.lowercased().contains(lowered)
                        || entry.sourceAppName?.lowercased().contains(lowered) == true
                        || entry.tags.contains { $0.lowercased().contains(lowered) }
                }
            }

            // Filter by content type
            if let contentType {
                results = results.filter { $0.contentType == contentType }
            }

            // Filter by date range
            if let dateRange {
                results = results.filter { dateRange.contains($0.createdAt) }
            }

            return results
        } catch {
            clipLogger.error("Search failed: \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - Paste

    #if os(macOS)
        func pasteEntry(_ entry: TheaClipEntry) {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()

            switch entry.contentType {
            case .text, .richText:
                if let text = entry.textContent {
                    pasteboard.setString(text, forType: .string)
                }
            case .html:
                if let html = entry.htmlContent {
                    pasteboard.setString(html, forType: .html)
                }
                if let text = entry.textContent {
                    pasteboard.setString(text, forType: .string)
                }
            case .url:
                if let urlString = entry.urlString {
                    pasteboard.setString(urlString, forType: .string)
                    if let url = URL(string: urlString) {
                        pasteboard.setString(url.absoluteString, forType: .URL)
                    }
                }
            case .image:
                if let data = entry.imageData {
                    pasteboard.setData(data, forType: .tiff)
                }
            case .file:
                let urls = entry.filePaths.map { URL(fileURLWithPath: $0) }
                pasteboard.writeObjects(urls as [NSURL])
            case .color:
                break
            }

            // Update access metrics
            entry.lastAccessedAt = Date()
            entry.accessCount += 1
            saveContext()

            clipLogger.debug("Pasted entry: \(entry.contentType.rawValue)")
        }
    #endif

    // MARK: - Paste Stack

    func addToStack(_ entry: TheaClipEntry) {
        pasteStack.append(entry)
    }

    func pasteNextFromStack() -> TheaClipEntry? {
        guard !pasteStack.isEmpty else { return nil }
        let entry = pasteStack.removeFirst()
        #if os(macOS)
            pasteEntry(entry)
        #endif
        return entry
    }

    func clearStack() {
        pasteStack.removeAll()
    }

    // MARK: - Retention

    private func trimHistory() {
        guard let context = modelContext else { return }
        let maxItems = settings.clipboardMaxHistory
        let retentionDays = settings.clipboardRetentionDays

        // Trim by count (keep pinned)
        if recentEntries.count > maxItems {
            let excess = recentEntries.suffix(from: maxItems).filter { !$0.isPinned }
            for entry in excess {
                context.delete(entry)
            }
        }

        // Trim by age
        let cutoff = Date().addingTimeInterval(-TimeInterval(retentionDays) * 86400)
        let oldEntries = recentEntries.filter { $0.createdAt < cutoff && !$0.isPinned }
        for entry in oldEntries {
            context.delete(entry)
        }

        if !oldEntries.isEmpty {
            saveContext()
            loadRecentEntries()
        }
    }

    // MARK: - Sensitivity Detection

    private func isSensitiveContent(_ text: String) -> Bool {
        let range = NSRange(text.startIndex..., in: text)
        for pattern in sensitivePatterns {
            if pattern.firstMatch(in: text, range: range) != nil {
                return true
            }
        }
        return false
    }

    // MARK: - Statistics

    var totalEntryCount: Int {
        guard let context = modelContext else { return 0 }
        let descriptor = FetchDescriptor<TheaClipEntry>()
        return (try? context.fetchCount(descriptor)) ?? 0
    }

    var favoriteCount: Int {
        recentEntries.filter(\.isFavorite).count
    }

    var pinnedCount: Int {
        recentEntries.filter(\.isPinned).count
    }

    // MARK: - Helpers

    private func saveContext(operation: String = #function) {
        do {
            try modelContext?.save()
        } catch {
            clipLogger.error("Save failed in \(operation): \(error.localizedDescription)")
        }
    }
}
