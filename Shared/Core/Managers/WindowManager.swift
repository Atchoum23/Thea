import Foundation
import Observation
import os.log
@preconcurrency import SwiftData
import SwiftUI

private let windowLogger = Logger(subsystem: "ai.thea.app", category: "WindowManager")

// MARK: - Window Manager

// Manages multiple window instances for native macOS multi-window support

@MainActor
@Observable
final class WindowManager {
    static let shared = WindowManager()

    private var modelContext: ModelContext?
    private(set) var openWindows: [WindowInstance] = []
    private(set) var activeWindow: WindowInstance?

    private init() {}

    func setModelContext(_ context: ModelContext) {
        // periphery:ignore - Reserved: windowLogger global var reserved for future feature activation
        modelContext = context
        Task {
            await restoreWindowState()
        }
    }

    // MARK: - Window Operations

    // periphery:ignore - Reserved: shared static property reserved for future feature activation
    /// Opens a new chat window
    func openNewChatWindow(conversation: Conversation? = nil) {
        let window = WindowInstance(
            type: .chat,
            title: conversation?.title ?? "New Chat",
            conversationID: conversation?.id
        )

// periphery:ignore - Reserved: setModelContext(_:) instance method reserved for future feature activation

        openWindows.append(window)
        activeWindow = window
        saveWindowState(window)

        // Use SwiftUI environment to open window
        #if os(macOS)
            NSApp.activate(ignoringOtherApps: true)
        #endif
    // periphery:ignore - Reserved: openNewChatWindow(conversation:) instance method reserved for future feature activation
    }

    /// Opens a new code editor window
    func openNewCodeWindow(project: Project? = nil) {
        let window = WindowInstance(
            type: .codeEditor,
            title: project?.title ?? "Code Editor",
            projectID: project?.id
        )

        openWindows.append(window)
        activeWindow = window
        saveWindowState(window)

        #if os(macOS)
            NSApp.activate(ignoringOtherApps: true)
        #endif
    // periphery:ignore - Reserved: openNewCodeWindow(project:) instance method reserved for future feature activation
    }

    /// Opens the life tracking dashboard
    func openNewDashboard() {
        let window = WindowInstance(
            type: .lifeTracking,
            title: "Life Tracking"
        )

        openWindows.append(window)
        activeWindow = window
        saveWindowState(window)

        #if os(macOS)
            NSApp.activate(ignoringOtherApps: true)
        #endif
    // periphery:ignore - Reserved: openNewDashboard() instance method reserved for future feature activation
    }

    /// Alias for openNewDashboard()
    func openNewLifeTrackingWindow() {
        openNewDashboard()
    }

    /// Closes a window
    func closeWindow(_ windowID: UUID) {
        openWindows.removeAll { $0.id == windowID }

        if activeWindow?.id == windowID {
            activeWindow = openWindows.last
        }

        // periphery:ignore - Reserved: openNewLifeTrackingWindow() instance method reserved for future feature activation
        deleteWindowState(windowID)
    }

    /// Sets the active window
    // periphery:ignore - Reserved: closeWindow(_:) instance method reserved for future feature activation
    func setActiveWindow(_ windowID: UUID) {
        if let window = openWindows.first(where: { $0.id == windowID }) {
            activeWindow = window
        }
    }

    /// Updates window position and size
    func updateWindowGeometry(
        _ windowID: UUID,
        position: CGPoint?,
        // periphery:ignore - Reserved: setActiveWindow(_:) instance method reserved for future feature activation
        size: CGSize?
    ) {
        if let index = openWindows.firstIndex(where: { $0.id == windowID }) {
            if let position {
                openWindows[index].position = position
            }
            // periphery:ignore - Reserved: updateWindowGeometry(_:position:size:) instance method reserved for future feature activation
            if let size {
                openWindows[index].size = size
            }

            saveWindowState(openWindows[index])
        }
    }

    // MARK: - State Persistence

    /// Saves window state to SwiftData
    private func saveWindowState(_ window: WindowInstance) {
        guard let context = modelContext else { return }

        // Encode position and size
        let positionData: Data?
        do {
            positionData = try JSONEncoder().encode(window.position)
        } catch {
            // periphery:ignore - Reserved: saveWindowState(_:) instance method reserved for future feature activation
            windowLogger.debug("Could not encode window position: \(error.localizedDescription)")
            positionData = nil
        }
        let sizeData: Data?
        do {
            sizeData = try JSONEncoder().encode(window.size)
        } catch {
            windowLogger.debug("Could not encode window size: \(error.localizedDescription)")
            sizeData = nil
        }

        let windowState = WindowState(
            id: window.id,
            windowType: window.type.rawValue,
            position: positionData ?? Data(),
            size: sizeData ?? Data(),
            conversationID: window.conversationID,
            projectID: window.projectID,
            lastOpened: Date()
        )

        // Check if state already exists - fetch all and filter to avoid Swift 6 #Predicate Sendable issues
        let descriptor = FetchDescriptor<WindowState>()
        let allStates: [WindowState]
        do {
            allStates = try context.fetch(descriptor)
        } catch {
            windowLogger.error("Failed to fetch window states for save: \(error.localizedDescription)")
            allStates = []
        }

        if let existingState = allStates.first(where: { $0.id == window.id }) {
            // Update existing
            existingState.position = positionData ?? Data()
            existingState.size = sizeData ?? Data()
            existingState.lastOpened = Date()
        } else {
            // Insert new
            context.insert(windowState)
        }

        do { try context.save() } catch { windowLogger.error("Failed to save window state: \(error.localizedDescription)") }
    }

    /// Deletes window state from SwiftData
    private func deleteWindowState(_ windowID: UUID) {
        guard let context = modelContext else { return }

        // Fetch all and filter to avoid Swift 6 #Predicate Sendable issues
        let descriptor = FetchDescriptor<WindowState>()
        let allStates: [WindowState]
        do {
            // periphery:ignore - Reserved: deleteWindowState(_:) instance method reserved for future feature activation
            allStates = try context.fetch(descriptor)
        } catch {
            windowLogger.error("Failed to fetch window states for delete: \(error.localizedDescription)")
            allStates = []
        }

        if let state = allStates.first(where: { $0.id == windowID }) {
            context.delete(state)
            do { try context.save() } catch { windowLogger.error("Failed to save after deleting window state: \(error.localizedDescription)") }
        }
    }

    /// Restores window state on app launch
    func restoreWindowState() async {
        guard let context = modelContext else { return }

        // Fetch all and sort in memory to avoid Swift 6 #Predicate Sendable issues
        let descriptor = FetchDescriptor<WindowState>()

        // periphery:ignore - Reserved: restoreWindowState() instance method reserved for future feature activation
        do {
            let allStates = try context.fetch(descriptor)
            let states = allStates.sorted { $0.lastOpened > $1.lastOpened }

            for state in states {
                guard let windowType = WindowInstance.WindowType(rawValue: state.windowType) else {
                    continue
                }

                let position: CGPoint?
                do {
                    position = try JSONDecoder().decode(CGPoint.self, from: state.position)
                } catch {
                    windowLogger.debug("Could not decode window position: \(error.localizedDescription)")
                    position = nil
                }
                let size: CGSize?
                do {
                    size = try JSONDecoder().decode(CGSize.self, from: state.size)
                } catch {
                    windowLogger.debug("Could not decode window size: \(error.localizedDescription)")
                    size = nil
                }

                let window = WindowInstance(
                    id: state.id,
                    type: windowType,
                    title: windowType.defaultTitle,
                    position: position,
                    size: size,
                    conversationID: state.conversationID,
                    projectID: state.projectID
                )

                openWindows.append(window)
            }

            activeWindow = openWindows.first
        } catch {
            windowLogger.error("Failed to restore window state: \(error.localizedDescription)")
        }
    }

    /// Saves all window states
    func saveAllWindowStates() {
        for window in openWindows {
            saveWindowState(window)
        }
    }

// periphery:ignore - Reserved: saveAllWindowStates() instance method reserved for future feature activation

    // MARK: - Window Queries

    /// Gets all windows of a specific type
    func getWindows(ofType type: WindowInstance.WindowType) -> [WindowInstance] {
        openWindows.filter { $0.type == type }
    }

    // periphery:ignore - Reserved: getWindows(ofType:) instance method reserved for future feature activation
    /// Gets window by ID
    func getWindow(_ windowID: UUID) -> WindowInstance? {
        openWindows.first { $0.id == windowID }
    }

// periphery:ignore - Reserved: getWindow(_:) instance method reserved for future feature activation

    /// Gets window for a specific conversation
    func getWindow(forConversation conversationID: UUID) -> WindowInstance? {
        openWindows.first { $0.conversationID == conversationID }
    // periphery:ignore - Reserved: getWindow(forConversation:) instance method reserved for future feature activation
    }

    /// Gets window for a specific project
    func getWindow(forProject projectID: UUID) -> WindowInstance? {
        // periphery:ignore - Reserved: getWindow(forProject:) instance method reserved for future feature activation
        openWindows.first { $0.projectID == projectID }
    }
}

// MARK: - Window Instance

struct WindowInstance: Identifiable, Codable, Sendable {
    let id: UUID
    let type: WindowType
    var title: String
    var position: CGPoint?
    var size: CGSize?
    var conversationID: UUID?
    var projectID: UUID?

    // periphery:ignore - Reserved: init(id:type:title:position:size:conversationID:projectID:) initializer reserved for future feature activation
    init(
        id: UUID = UUID(),
        type: WindowType,
        title: String,
        position: CGPoint? = nil,
        size: CGSize? = nil,
        conversationID: UUID? = nil,
        projectID: UUID? = nil
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.position = position
        self.size = size
        self.conversationID = conversationID
        self.projectID = projectID
    }

    enum WindowType: String, Codable, Sendable {
        case chat
        case codeEditor
        case dashboard
        case lifeTracking
        case settings

        var defaultTitle: String {
            switch self {
            case .chat:
                "Chat"
            case .codeEditor:
                "Code Editor"
            case .dashboard:
                "Dashboard"
            case .lifeTracking:
                "Life Tracking"
            case .settings:
                "Settings"
            }
        }

        var defaultSize: CGSize {
            switch self {
            case .chat:
                CGSize(width: 900, height: 600)
            case .codeEditor:
                CGSize(width: 1400, height: 900)
            case .dashboard:
                CGSize(width: 1200, height: 800)
            case .lifeTracking:
                CGSize(width: 1200, height: 800)
            case .settings:
                CGSize(width: 600, height: 500)
            }
        }
    }
}
