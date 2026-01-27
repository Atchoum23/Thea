//
//  ShortcutsOrchestrator.swift
//  Thea
//
//  Created by Thea
//  Orchestrates iOS/macOS Shortcuts discovery and execution
//

import Foundation
import os.log

#if os(iOS) || os(macOS)
    import AppIntents
#endif

// MARK: - Shortcuts Orchestrator

/// Orchestrates Shortcuts discovery, execution, and multi-step automation chains
@MainActor
public final class ShortcutsOrchestrator: ObservableObject {
    public static let shared = ShortcutsOrchestrator()

    private let logger = Logger(subsystem: "app.thea.shortcuts", category: "ShortcutsOrchestrator")

    // MARK: - State

    @Published public private(set) var availableShortcuts: [ShortcutInfo] = []
    @Published public private(set) var recentShortcuts: [ShortcutInfo] = []
    @Published public private(set) var runningShortcuts: [String: ShortcutExecution] = [:]
    @Published public private(set) var isDiscovering = false

    // MARK: - Configuration

    public var maxConcurrentShortcuts = 3
    public var shortcutTimeout: TimeInterval = 300 // 5 minutes

    // MARK: - Callbacks

    public var onShortcutStarted: ((ShortcutInfo) -> Void)?
    public var onShortcutCompleted: ((ShortcutInfo, ShortcutResult) -> Void)?
    public var onShortcutFailed: ((ShortcutInfo, Error) -> Void)?

    private init() {
        loadRecentShortcuts()
    }

    // MARK: - Discovery

    /// Discover available shortcuts
    public func discoverShortcuts() async {
        isDiscovering = true
        defer { isDiscovering = false }

        // On iOS, we can use AppIntents to suggest shortcuts
        // On macOS, we can query the Shortcuts app

        // For now, we'll use a combination of:
        // 1. User-configured shortcuts
        // 2. Shortcuts that have been run before
        // 3. System shortcuts (if available)

        var discovered: [ShortcutInfo] = []

        // Load from user defaults (shortcuts the user has configured)
        if let data = UserDefaults.standard.data(forKey: "thea.shortcuts.available"),
           let shortcuts = try? JSONDecoder().decode([ShortcutInfo].self, from: data)
        {
            discovered.append(contentsOf: shortcuts)
        }

        // Add common/suggested shortcuts
        discovered.append(contentsOf: suggestedShortcuts())

        availableShortcuts = discovered
        logger.info("Discovered \(discovered.count) shortcuts")
    }

    private func suggestedShortcuts() -> [ShortcutInfo] {
        // Common shortcuts that users might have
        [
            ShortcutInfo(name: "Do Not Disturb", category: .focus, description: "Toggle Do Not Disturb"),
            ShortcutInfo(name: "Get Current Weather", category: .utility, description: "Get weather for current location"),
            ShortcutInfo(name: "Start Timer", category: .productivity, description: "Start a timer"),
            ShortcutInfo(name: "Send Message", category: .communication, description: "Send a message to a contact"),
            ShortcutInfo(name: "Play Playlist", category: .media, description: "Play a music playlist"),
            ShortcutInfo(name: "Home Automation", category: .home, description: "Control HomeKit devices"),
            ShortcutInfo(name: "Daily Briefing", category: .productivity, description: "Get your daily summary"),
            ShortcutInfo(name: "Log Health", category: .health, description: "Log health data")
        ]
    }

    // MARK: - Execution

    /// Run a shortcut by name
    public func runShortcut(named name: String, input: ShortcutInput? = nil) async throws -> ShortcutResult {
        guard runningShortcuts.count < maxConcurrentShortcuts else {
            throw ShortcutOrchestratorError.tooManyRunning
        }

        let shortcut = availableShortcuts.first { $0.name == name } ??
            ShortcutInfo(name: name, category: .custom, description: "")

        return try await executeShortcut(shortcut, input: input)
    }

    /// Run a shortcut
    public func runShortcut(_ shortcut: ShortcutInfo, input: ShortcutInput? = nil) async throws -> ShortcutResult {
        guard runningShortcuts.count < maxConcurrentShortcuts else {
            throw ShortcutOrchestratorError.tooManyRunning
        }

        return try await executeShortcut(shortcut, input: input)
    }

    private func executeShortcut(_ shortcut: ShortcutInfo, input: ShortcutInput?) async throws -> ShortcutResult {
        let executionId = UUID().uuidString
        let execution = ShortcutExecution(id: executionId, shortcut: shortcut, startedAt: Date())
        runningShortcuts[executionId] = execution

        logger.info("Running shortcut: \(shortcut.name)")
        onShortcutStarted?(shortcut)

        defer {
            runningShortcuts.removeValue(forKey: executionId)
        }

        do {
            // Build the shortcuts URL
            let result = try await runViaURLScheme(shortcut: shortcut, input: input)

            // Record success
            recordShortcutRun(shortcut)
            onShortcutCompleted?(shortcut, result)

            return result

        } catch {
            logger.error("Shortcut failed: \(shortcut.name) - \(error)")
            onShortcutFailed?(shortcut, error)
            throw error
        }
    }

    /// Run shortcut via URL scheme
    private func runViaURLScheme(shortcut: ShortcutInfo, input: ShortcutInput?) async throws -> ShortcutResult {
        // Build shortcuts:// URL
        let encodedName = shortcut.name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? shortcut.name
        var urlString = "shortcuts://run-shortcut?name=\(encodedName)"

        if let input {
            if let text = input.text {
                let encodedText = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                urlString += "&input=text&text=\(encodedText)"
            } else if let clipboardInput = input.useClipboard, clipboardInput {
                urlString += "&input=clipboard"
            }
        }

        guard let url = URL(string: urlString) else {
            throw ShortcutOrchestratorError.invalidShortcut
        }

        #if os(iOS)
            await UIApplication.shared.open(url)
        #elseif os(macOS)
            NSWorkspace.shared.open(url)
        #endif

        // Since shortcuts:// runs asynchronously, we return success
        // The actual result would need x-callback-url to retrieve
        return ShortcutResult(success: true, output: nil)
    }

    // MARK: - Automation Chains

    /// Run multiple shortcuts in sequence
    public func runChain(_ shortcuts: [ShortcutInfo], passOutput: Bool = true) async throws -> [ShortcutResult] {
        var results: [ShortcutResult] = []
        var lastOutput: String?

        for shortcut in shortcuts {
            let input: ShortcutInput? = if passOutput, let output = lastOutput {
                ShortcutInput(text: output)
            } else {
                nil
            }

            let result = try await runShortcut(shortcut, input: input)
            results.append(result)
            lastOutput = result.output
        }

        return results
    }

    /// Run shortcuts in parallel
    public func runParallel(_ shortcuts: [ShortcutInfo]) async throws -> [ShortcutResult] {
        try await withThrowingTaskGroup(of: ShortcutResult.self) { group in
            for shortcut in shortcuts {
                group.addTask {
                    try await self.runShortcut(shortcut)
                }
            }

            var results: [ShortcutResult] = []
            for try await result in group {
                results.append(result)
            }
            return results
        }
    }

    // MARK: - Context-Aware Suggestions

    /// Get suggested shortcuts based on context
    public func getSuggestions(for context: ShortcutContext) -> [ShortcutInfo] {
        var suggestions: [ShortcutInfo] = []

        // Filter by category based on context
        switch context.situationType {
        case .morning:
            suggestions.append(contentsOf: availableShortcuts.filter {
                $0.category == .productivity || $0.category == .health
            })

        case .commute:
            suggestions.append(contentsOf: availableShortcuts.filter {
                $0.category == .media || $0.category == .communication
            })

        case .work:
            suggestions.append(contentsOf: availableShortcuts.filter {
                $0.category == .productivity || $0.category == .focus
            })

        case .home:
            suggestions.append(contentsOf: availableShortcuts.filter {
                $0.category == .home || $0.category == .media
            })

        case .bedtime:
            suggestions.append(contentsOf: availableShortcuts.filter {
                $0.category == .focus || $0.category == .health
            })

        case .custom:
            suggestions = Array(recentShortcuts.prefix(5))
        }

        // Boost recently used shortcuts
        let recentNames = Set(recentShortcuts.prefix(10).map(\.name))
        suggestions.sort { recentNames.contains($0.name) && !recentNames.contains($1.name) }

        return Array(suggestions.prefix(5))
    }

    // MARK: - Recent Shortcuts

    private func recordShortcutRun(_ shortcut: ShortcutInfo) {
        // Remove if already in recents
        recentShortcuts.removeAll { $0.name == shortcut.name }

        // Add to front
        recentShortcuts.insert(shortcut, at: 0)

        // Keep only last 20
        if recentShortcuts.count > 20 {
            recentShortcuts = Array(recentShortcuts.prefix(20))
        }

        saveRecentShortcuts()
    }

    private func loadRecentShortcuts() {
        if let data = UserDefaults.standard.data(forKey: "thea.shortcuts.recent"),
           let shortcuts = try? JSONDecoder().decode([ShortcutInfo].self, from: data)
        {
            recentShortcuts = shortcuts
        }
    }

    private func saveRecentShortcuts() {
        if let data = try? JSONEncoder().encode(recentShortcuts) {
            UserDefaults.standard.set(data, forKey: "thea.shortcuts.recent")
        }
    }

    // MARK: - User Configuration

    /// Add a custom shortcut
    public func addShortcut(_ shortcut: ShortcutInfo) {
        if !availableShortcuts.contains(where: { $0.name == shortcut.name }) {
            availableShortcuts.append(shortcut)
            saveAvailableShortcuts()
        }
    }

    /// Remove a shortcut
    public func removeShortcut(named name: String) {
        availableShortcuts.removeAll { $0.name == name }
        saveAvailableShortcuts()
    }

    private func saveAvailableShortcuts() {
        if let data = try? JSONEncoder().encode(availableShortcuts) {
            UserDefaults.standard.set(data, forKey: "thea.shortcuts.available")
        }
    }
}

// MARK: - Models

public struct ShortcutInfo: Identifiable, Codable, Sendable {
    public var id: String { name }
    public let name: String
    public let category: ShortcutCategory
    public let description: String
    public var parameters: [ShortcutParameter]

    public init(
        name: String,
        category: ShortcutCategory,
        description: String,
        parameters: [ShortcutParameter] = []
    ) {
        self.name = name
        self.category = category
        self.description = description
        self.parameters = parameters
    }
}

public enum ShortcutCategory: String, Codable, Sendable, CaseIterable {
    case productivity
    case communication
    case media
    case home
    case health
    case focus
    case utility
    case custom

    public var displayName: String {
        switch self {
        case .productivity: "Productivity"
        case .communication: "Communication"
        case .media: "Media"
        case .home: "Home"
        case .health: "Health"
        case .focus: "Focus"
        case .utility: "Utility"
        case .custom: "Custom"
        }
    }

    public var icon: String {
        switch self {
        case .productivity: "briefcase.fill"
        case .communication: "message.fill"
        case .media: "play.fill"
        case .home: "house.fill"
        case .health: "heart.fill"
        case .focus: "moon.fill"
        case .utility: "wrench.fill"
        case .custom: "star.fill"
        }
    }
}

public struct ShortcutParameter: Codable, Sendable {
    public let name: String
    public let type: ParameterType
    public var value: String?

    public enum ParameterType: String, Codable, Sendable {
        case text
        case number
        case url
        case file
        case boolean
    }
}

public struct ShortcutInput: Sendable {
    public let text: String?
    public let data: Data?
    public let url: URL?
    public let useClipboard: Bool?

    public init(text: String? = nil, data: Data? = nil, url: URL? = nil, useClipboard: Bool? = nil) {
        self.text = text
        self.data = data
        self.url = url
        self.useClipboard = useClipboard
    }
}

public struct ShortcutResult: Sendable {
    public let success: Bool
    public let output: String?
    public let outputData: Data?
    public let error: String?
    public let completedAt: Date

    public init(success: Bool, output: String? = nil, outputData: Data? = nil, error: String? = nil) {
        self.success = success
        self.output = output
        self.outputData = outputData
        self.error = error
        completedAt = Date()
    }
}

public struct ShortcutExecution: Sendable {
    public let id: String
    public let shortcut: ShortcutInfo
    public let startedAt: Date
}

public struct ShortcutContext: Sendable {
    public let situationType: SituationType
    public let location: String?
    public let timeOfDay: TimeOfDay
    public let recentApps: [String]

    public enum SituationType: String, Sendable {
        case morning
        case commute
        case work
        case home
        case bedtime
        case custom
    }

    public enum TimeOfDay: String, Sendable {
        case morning
        case afternoon
        case evening
        case night
    }

    public init(
        situationType: SituationType,
        location: String? = nil,
        timeOfDay: TimeOfDay = .afternoon,
        recentApps: [String] = []
    ) {
        self.situationType = situationType
        self.location = location
        self.timeOfDay = timeOfDay
        self.recentApps = recentApps
    }
}

// MARK: - Errors

public enum ShortcutOrchestratorError: Error, LocalizedError {
    case tooManyRunning
    case shortcutNotFound
    case invalidShortcut
    case executionFailed(String)
    case timeout

    public var errorDescription: String? {
        switch self {
        case .tooManyRunning:
            "Too many shortcuts running concurrently"
        case .shortcutNotFound:
            "Shortcut not found"
        case .invalidShortcut:
            "Invalid shortcut configuration"
        case let .executionFailed(message):
            "Shortcut execution failed: \(message)"
        case .timeout:
            "Shortcut timed out"
        }
    }
}
