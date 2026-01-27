//
//  FinderSync.swift
//  TheaFinderSyncExtension
//
//  Created by Thea
//

#if os(macOS)
    import Cocoa
    import FinderSync

    /// Finder Sync Extension for Thea
    /// Adds Thea context menu items to Finder
    class FinderSync: FIFinderSync {
        // MARK: - Properties

        private let appGroupID = "group.app.thea"

        // Watched folders
        private var monitoredDirectories: Set<URL> = []

        // MARK: - Initialization

        override init() {
            super.init()

            // Set up the directory we are syncing
            // By default, monitor the home directory and common locations
            let homeURL = FileManager.default.homeDirectoryForCurrentUser

            FIFinderSyncController.default().directoryURLs = [
                homeURL,
                homeURL.appendingPathComponent("Documents"),
                homeURL.appendingPathComponent("Desktop"),
                homeURL.appendingPathComponent("Downloads")
            ]

            // Load additional monitored directories from preferences
            loadMonitoredDirectories()
        }

        // MARK: - Primary Finder Sync Protocol Methods

        override func menu(for menuKind: FIMenuKind) -> NSMenu {
            let menu = NSMenu(title: "Thea")

            switch menuKind {
            case .contextualMenuForItems:
                // Contextual menu for selected items
                addItemMenuItems(to: menu)

            case .contextualMenuForContainer:
                // Contextual menu for the current folder
                addContainerMenuItems(to: menu)

            case .contextualMenuForSidebar:
                // Sidebar contextual menu
                addSidebarMenuItems(to: menu)

            case .toolbarItemMenu:
                // Toolbar menu
                addToolbarMenuItems(to: menu)

            @unknown default:
                break
            }

            return menu
        }

        override func requestBadgeIdentifier(for url: URL) {
            // Provide badge identifiers for files/folders
            // This is called for items in monitored directories

            // Check if the file has been processed by Thea
            if isProcessedByThea(url: url) {
                FIFinderSyncController.default().setBadgeIdentifier("thea.processed", for: url)
            } else if isTrackedByThea(url: url) {
                FIFinderSyncController.default().setBadgeIdentifier("thea.tracked", for: url)
            }
        }

        // MARK: - Menu Items

        private func addItemMenuItems(to menu: NSMenu) {
            // Ask Thea about this file
            let askItem = NSMenuItem(
                title: "Ask Thea About This",
                action: #selector(askTheaAboutItem(_:)),
                keyEquivalent: ""
            )
            askItem.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: nil)
            menu.addItem(askItem)

            // Summarize document
            let summarizeItem = NSMenuItem(
                title: "Summarize with Thea",
                action: #selector(summarizeItem(_:)),
                keyEquivalent: ""
            )
            summarizeItem.image = NSImage(systemSymbolName: "doc.text", accessibilityDescription: nil)
            menu.addItem(summarizeItem)

            menu.addItem(NSMenuItem.separator())

            // Add to Thea memory
            let memoryItem = NSMenuItem(
                title: "Add to Thea Memory",
                action: #selector(addToMemory(_:)),
                keyEquivalent: ""
            )
            memoryItem.image = NSImage(systemSymbolName: "brain.head.profile", accessibilityDescription: nil)
            menu.addItem(memoryItem)

            // Create artifact from file
            let artifactItem = NSMenuItem(
                title: "Create Thea Artifact",
                action: #selector(createArtifact(_:)),
                keyEquivalent: ""
            )
            artifactItem.image = NSImage(systemSymbolName: "cube", accessibilityDescription: nil)
            menu.addItem(artifactItem)

            menu.addItem(NSMenuItem.separator())

            // Track with Thea
            let trackItem = NSMenuItem(
                title: "Track with Thea",
                action: #selector(trackItem(_:)),
                keyEquivalent: ""
            )
            trackItem.image = NSImage(systemSymbolName: "eye", accessibilityDescription: nil)
            menu.addItem(trackItem)
        }

        private func addContainerMenuItems(to menu: NSMenu) {
            // Create new document with Thea
            let newDocItem = NSMenuItem(
                title: "New Document with Thea",
                action: #selector(createNewDocument(_:)),
                keyEquivalent: ""
            )
            newDocItem.image = NSImage(systemSymbolName: "doc.badge.plus", accessibilityDescription: nil)
            menu.addItem(newDocItem)

            // Monitor this folder
            let monitorItem = NSMenuItem(
                title: "Monitor Folder with Thea",
                action: #selector(monitorFolder(_:)),
                keyEquivalent: ""
            )
            monitorItem.image = NSImage(systemSymbolName: "folder.badge.gearshape", accessibilityDescription: nil)
            menu.addItem(monitorItem)
        }

        private func addSidebarMenuItems(to menu: NSMenu) {
            let openTheaItem = NSMenuItem(
                title: "Open in Thea",
                action: #selector(openInThea(_:)),
                keyEquivalent: ""
            )
            openTheaItem.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: nil)
            menu.addItem(openTheaItem)
        }

        private func addToolbarMenuItems(to menu: NSMenu) {
            let quickPromptItem = NSMenuItem(
                title: "Quick Prompt",
                action: #selector(openQuickPrompt(_:)),
                keyEquivalent: ""
            )
            quickPromptItem.image = NSImage(systemSymbolName: "text.bubble", accessibilityDescription: nil)
            menu.addItem(quickPromptItem)
        }

        // MARK: - Actions

        @objc private func askTheaAboutItem(_: AnyObject?) {
            guard let items = FIFinderSyncController.default().selectedItemURLs() else { return }

            for url in items {
                sendToThea(action: "ask", url: url)
            }

            openThea(with: "ask")
        }

        @objc private func summarizeItem(_: AnyObject?) {
            guard let items = FIFinderSyncController.default().selectedItemURLs() else { return }

            for url in items {
                sendToThea(action: "summarize", url: url)
            }

            openThea(with: "summarize")
        }

        @objc private func addToMemory(_: AnyObject?) {
            guard let items = FIFinderSyncController.default().selectedItemURLs() else { return }

            for url in items {
                sendToThea(action: "memory", url: url)
            }

            openThea(with: "memory")
        }

        @objc private func createArtifact(_: AnyObject?) {
            guard let items = FIFinderSyncController.default().selectedItemURLs() else { return }

            for url in items {
                sendToThea(action: "artifact", url: url)
            }

            openThea(with: "artifact")
        }

        @objc private func trackItem(_: AnyObject?) {
            guard let items = FIFinderSyncController.default().selectedItemURLs() else { return }

            for url in items {
                addToTrackedFiles(url: url)
                FIFinderSyncController.default().setBadgeIdentifier("thea.tracked", for: url)
            }
        }

        @objc private func createNewDocument(_: AnyObject?) {
            guard let containerURL = FIFinderSyncController.default().targetedURL() else { return }

            sendToThea(action: "newDocument", url: containerURL)
            openThea(with: "newDocument")
        }

        @objc private func monitorFolder(_: AnyObject?) {
            guard let containerURL = FIFinderSyncController.default().targetedURL() else { return }

            addToMonitoredDirectories(url: containerURL)

            // Update watched directories
            var directories = FIFinderSyncController.default().directoryURLs ?? Set<URL>()
            directories.insert(containerURL)
            FIFinderSyncController.default().directoryURLs = directories
        }

        @objc private func openInThea(_: AnyObject?) {
            guard let items = FIFinderSyncController.default().selectedItemURLs() else { return }

            for url in items {
                sendToThea(action: "open", url: url)
            }

            openThea(with: nil)
        }

        @objc private func openQuickPrompt(_: AnyObject?) {
            openThea(with: "quickPrompt")
        }

        // MARK: - Helper Methods

        private func sendToThea(action: String, url: URL) {
            guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
                return
            }

            let requestDir = containerURL.appendingPathComponent("FinderRequests", isDirectory: true)
            try? FileManager.default.createDirectory(at: requestDir, withIntermediateDirectories: true)

            let request: [String: Any] = [
                "action": action,
                "url": url.path,
                "timestamp": Date().timeIntervalSince1970
            ]

            let requestPath = requestDir.appendingPathComponent("\(UUID().uuidString).json")
            if let data = try? JSONSerialization.data(withJSONObject: request) {
                try? data.write(to: requestPath)
            }

            // Notify main app
            let notificationName = CFNotificationName("app.thea.FinderRequest" as CFString)
            CFNotificationCenterPostNotification(
                CFNotificationCenterGetDarwinNotifyCenter(),
                notificationName,
                nil,
                nil,
                true
            )
        }

        private func openThea(with action: String?) {
            var urlString = "thea://"
            if let action {
                urlString += "finder/\(action)"
            }

            if let url = URL(string: urlString) {
                NSWorkspace.shared.open(url)
            }
        }

        private func isProcessedByThea(url: URL) -> Bool {
            guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
                return false
            }

            let processedPath = containerURL.appendingPathComponent("processed_files.json")
            guard let data = try? Data(contentsOf: processedPath),
                  let processed = try? JSONSerialization.jsonObject(with: data) as? [String]
            else {
                return false
            }

            return processed.contains(url.path)
        }

        private func isTrackedByThea(url: URL) -> Bool {
            guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
                return false
            }

            let trackedPath = containerURL.appendingPathComponent("tracked_files.json")
            guard let data = try? Data(contentsOf: trackedPath),
                  let tracked = try? JSONSerialization.jsonObject(with: data) as? [String]
            else {
                return false
            }

            return tracked.contains(url.path)
        }

        private func addToTrackedFiles(url: URL) {
            guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
                return
            }

            let trackedPath = containerURL.appendingPathComponent("tracked_files.json")
            var tracked: [String] = []

            if let data = try? Data(contentsOf: trackedPath),
               let existing = try? JSONSerialization.jsonObject(with: data) as? [String]
            {
                tracked = existing
            }

            if !tracked.contains(url.path) {
                tracked.append(url.path)
                if let data = try? JSONSerialization.data(withJSONObject: tracked) {
                    try? data.write(to: trackedPath)
                }
            }
        }

        private func loadMonitoredDirectories() {
            guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
                return
            }

            let monitorsPath = containerURL.appendingPathComponent("monitored_directories.json")
            guard let data = try? Data(contentsOf: monitorsPath),
                  let paths = try? JSONSerialization.jsonObject(with: data) as? [String]
            else {
                return
            }

            let urls = Set(paths.compactMap { URL(fileURLWithPath: $0) })
            var directories = FIFinderSyncController.default().directoryURLs ?? Set<URL>()
            directories.formUnion(urls)
            FIFinderSyncController.default().directoryURLs = directories
        }

        private func addToMonitoredDirectories(url: URL) {
            guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
                return
            }

            let monitorsPath = containerURL.appendingPathComponent("monitored_directories.json")
            var paths: [String] = []

            if let data = try? Data(contentsOf: monitorsPath),
               let existing = try? JSONSerialization.jsonObject(with: data) as? [String]
            {
                paths = existing
            }

            if !paths.contains(url.path) {
                paths.append(url.path)
                if let data = try? JSONSerialization.data(withJSONObject: paths) {
                    try? data.write(to: monitorsPath)
                }
            }
        }
    }
#endif
