import Foundation
import Observation
@preconcurrency import SwiftData
import SwiftUI

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
        self.modelContext = context
        Task {
            await restoreWindowState()
        }
    }

    // MARK: - Window Operations

    /// Opens a new chat window
    func openNewChatWindow(conversation: Conversation? = nil) {
        let window = WindowInstance(
            type: .chat,
            title: conversation?.title ?? "New Chat",
            conversationID: conversation?.id
        )

        openWindows.append(window)
        activeWindow = window
        saveWindowState(window)

        // Use SwiftUI environment to open window
        #if os(macOS)
        NSApp.activate(ignoringOtherApps: true)
        #endif
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

        deleteWindowState(windowID)
    }

    /// Sets the active window
    func setActiveWindow(_ windowID: UUID) {
        if let window = openWindows.first(where: { $0.id == windowID }) {
            activeWindow = window
        }
    }

    /// Updates window position and size
    func updateWindowGeometry(
        _ windowID: UUID,
        position: CGPoint?,
        size: CGSize?
    ) {
        if let index = openWindows.firstIndex(where: { $0.id == windowID }) {
            if let position = position {
                openWindows[index].position = position
            }
            if let size = size {
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
        let positionData = try? JSONEncoder().encode(window.position)
        let sizeData = try? JSONEncoder().encode(window.size)

        let windowState = WindowState(
            id: window.id,
            windowType: window.type.rawValue,
            position: positionData ?? Data(),
            size: sizeData ?? Data(),
            conversationID: window.conversationID,
            projectID: window.projectID,
            lastOpened: Date()
        )

        // Check if state already exists
        let descriptor = FetchDescriptor<WindowState>(
            predicate: #Predicate { $0.id == window.id }
        )

        if let existingState = try? context.fetch(descriptor).first {
            // Update existing
            existingState.position = positionData ?? Data()
            existingState.size = sizeData ?? Data()
            existingState.lastOpened = Date()
        } else {
            // Insert new
            context.insert(windowState)
        }

        try? context.save()
    }

    /// Deletes window state from SwiftData
    private func deleteWindowState(_ windowID: UUID) {
        guard let context = modelContext else { return }

        let descriptor = FetchDescriptor<WindowState>(
            predicate: #Predicate { $0.id == windowID }
        )

        if let state = try? context.fetch(descriptor).first {
            context.delete(state)
            try? context.save()
        }
    }

    /// Restores window state on app launch
    func restoreWindowState() async {
        guard let context = modelContext else { return }

        let descriptor = FetchDescriptor<WindowState>(
            sortBy: [SortDescriptor(\.lastOpened, order: .reverse)]
        )

        do {
            let states = try context.fetch(descriptor)

            for state in states {
                guard let windowType = WindowInstance.WindowType(rawValue: state.windowType) else {
                    continue
                }

                let position = try? JSONDecoder().decode(CGPoint.self, from: state.position)
                let size = try? JSONDecoder().decode(CGSize.self, from: state.size)

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
            print("Error restoring window state: \(error)")
        }
    }

    /// Saves all window states
    func saveAllWindowStates() {
        for window in openWindows {
            saveWindowState(window)
        }
    }

    // MARK: - Window Queries

    /// Gets all windows of a specific type
    func getWindows(ofType type: WindowInstance.WindowType) -> [WindowInstance] {
        openWindows.filter { $0.type == type }
    }

    /// Gets window by ID
    func getWindow(_ windowID: UUID) -> WindowInstance? {
        openWindows.first { $0.id == windowID }
    }

    /// Gets window for a specific conversation
    func getWindow(forConversation conversationID: UUID) -> WindowInstance? {
        openWindows.first { $0.conversationID == conversationID }
    }

    /// Gets window for a specific project
    func getWindow(forProject projectID: UUID) -> WindowInstance? {
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
                return "Chat"
            case .codeEditor:
                return "Code Editor"
            case .dashboard:
                return "Dashboard"
            case .lifeTracking:
                return "Life Tracking"
            case .settings:
                return "Settings"
            }
        }

        var defaultSize: CGSize {
            switch self {
            case .chat:
                return CGSize(width: 900, height: 600)
            case .codeEditor:
                return CGSize(width: 1_400, height: 900)
            case .dashboard:
                return CGSize(width: 1_200, height: 800)
            case .lifeTracking:
                return CGSize(width: 1_200, height: 800)
            case .settings:
                return CGSize(width: 600, height: 500)
            }
        }
    }
}
