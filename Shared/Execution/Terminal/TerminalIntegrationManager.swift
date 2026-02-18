#if os(macOS)
    import Combine
    import Foundation
    import SwiftUI

    /// Central manager for Terminal.app integration
    /// Provides unified interface for reading, writing, and monitoring terminal
    @MainActor
    final class TerminalIntegrationManager: ObservableObject {
        static let shared = TerminalIntegrationManager()

        // MARK: - Published State

        @Published var isEnabled: Bool = true
        @Published var sessions: [TerminalSession] = []
        @Published var currentSession: TerminalSession?
        @Published var lastOutput: String = ""
        @Published var lastError: String = ""
        @Published var isConnected: Bool = false
        @Published var terminalWindows: [WindowInfo] = []
        @Published var isMonitoring: Bool = false

        // MARK: - Configuration

        @Published var securityPolicy: TerminalSecurityPolicy = .default
        @Published var executionMode: ExecutionMode = .direct
        @Published var showOutputIn: OutputDisplay = .inline

        enum ExecutionMode: String, CaseIterable, Codable {
            case direct = "Direct"
            case terminalApp = "Terminal.app"
            case both = "Both"

            var description: String {
                switch self {
                case .direct: "Execute commands directly (faster, captures output)"
                case .terminalApp: "Execute in Terminal.app windows (interactive)"
                case .both: "Direct execution with Terminal.app fallback"
                }
            }
        }

        enum OutputDisplay: String, CaseIterable, Codable {
            case inline = "Inline"
            case floatingPanel = "Floating Panel"
            case terminalApp = "Terminal.app"
        }

        // MARK: - Internal Components

        // These are marked nonisolated(unsafe) because they are Sendable and thread-safe
        private let windowReader = TerminalWindowReader()
        nonisolated(unsafe) private var executor: TerminalCommandExecutor
        private var monitorTask: Task<Void, Never>?
        private var cancellables = Set<AnyCancellable>()
        private let commandHistoryURL: URL

        // MARK: - Quick Commands

        @Published var quickCommands: [QuickCommand] = QuickCommand.defaults

        // MARK: - Initialization

        private init() {
            executor = TerminalCommandExecutor(securityPolicy: .default)

            // Setup history storage
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            let theaFolder = appSupport.appendingPathComponent("Thea", isDirectory: true)
            try? FileManager.default.createDirectory(at: theaFolder, withIntermediateDirectories: true) // Safe: directory may already exist; error means history cannot be persisted (works in-memory)
            commandHistoryURL = theaFolder.appendingPathComponent("terminal_history.json")

            // Load saved configuration
            loadConfiguration()

            // Create default session
            let defaultSession = TerminalSession(name: "Default")
            sessions.append(defaultSession)
            currentSession = defaultSession

            // Check connection
            checkConnection()
        }

        // MARK: - Connection Management

        func checkConnection() {
            isConnected = windowReader.isTerminalRunning()
        }

        func refreshWindowList() async {
            do {
                terminalWindows = try await windowReader.getWindowList()
                isConnected = !terminalWindows.isEmpty || windowReader.isTerminalRunning()
            } catch {
                terminalWindows = []
                lastError = error.localizedDescription
            }
        }

        // MARK: - READ Terminal Content

        /// Read content from the front Terminal window
        func readTerminalContent() async throws -> String {
            let content = try await windowReader.readFrontWindowContent()
            lastOutput = content
            return content
        }

        /// Read content from specific window/tab
        func readTerminalContent(windowIndex: Int, tabIndex: Int) async throws -> String {
            let content = try await windowReader.readContent(windowIndex: windowIndex, tabIndex: tabIndex)
            lastOutput = content
            return content
        }

        /// Read full scrollback history
        func readTerminalHistory() async throws -> String {
            try await windowReader.readHistory()
        }

        /// Read history from specific window/tab
        func readTerminalHistory(windowIndex: Int, tabIndex: Int) async throws -> String {
            try await windowReader.readHistory(windowIndex: windowIndex, tabIndex: tabIndex)
        }

        /// Check if Terminal is busy (command running)
        func isTerminalBusy() async throws -> Bool {
            try await windowReader.isBusy()
        }

        /// Get current processes in Terminal
        func getCurrentProcesses() async throws -> [String] {
            try await windowReader.getCurrentProcesses()
        }

        // MARK: - WRITE/RUN Commands

        /// Execute a command based on current execution mode
        @discardableResult
        func execute(_ command: String, workingDirectory: URL? = nil) async throws -> ShellCommandResult {
            // Validate against security policy
            let validation = securityPolicy.isAllowed(command)
            switch validation {
            case let .blocked(reason):
                let error = TerminalCommandExecutor.ExecutorError.commandBlocked(reason)
                lastError = error.localizedDescription
                throw error
            case let .requiresConfirmation(reason):
                let error = TerminalCommandExecutor.ExecutorError.confirmationRequired(reason)
                lastError = error.localizedDescription
                throw error
            case .allowed:
                break
            }

            let dir = workingDirectory ?? currentSession?.workingDirectory

            switch executionMode {
            case .direct:
                return try await executeDirect(command, workingDirectory: dir)
            case .terminalApp:
                try await executeInTerminalApp(command)
                return ShellCommandResult(output: "", errorOutput: "", exitCode: 0, command: command, duration: 0)
            case .both:
                // Try direct first, fallback to Terminal.app for interactive
                do {
                    return try await executeDirect(command, workingDirectory: dir)
                } catch {
                    try await executeInTerminalApp(command)
                    return ShellCommandResult(output: "", errorOutput: "", exitCode: 0, command: command, duration: 0)
                }
            }
        }

        /// Execute command directly (Process/NSTask)
        @discardableResult
        func executeDirect(_ command: String, workingDirectory: URL? = nil) async throws -> ShellCommandResult {
            let result = try await executor.executeDirect(command, workingDirectory: workingDirectory)

            // Process output
            var output = result.output
            if securityPolicy.redactSensitiveOutput {
                output = TerminalOutputParser.redactSensitive(output)
            }

            let processedResult = ShellCommandResult(
                output: output,
                errorOutput: result.errorOutput,
                exitCode: result.exitCode,
                command: result.command,
                duration: result.duration
            )

            // Add to session history
            let terminalCommand = TerminalCommand(
                command: command,
                output: processedResult.output,
                errorOutput: processedResult.errorOutput,
                exitCode: processedResult.exitCode,
                duration: processedResult.duration,
                workingDirectory: workingDirectory ?? FileManager.default.homeDirectoryForCurrentUser
            )
            currentSession?.addCommand(terminalCommand)

            lastOutput = processedResult.combinedOutput
            if !processedResult.wasSuccessful {
                lastError = processedResult.errorOutput
            }

            // Save history if enabled
            if securityPolicy.logAllCommands {
                saveCommandHistory()
            }

            return processedResult
        }

        /// Execute command in Terminal.app
        func executeInTerminalApp(_ command: String) async throws {
            try await executor.executeInTerminalApp(command)

            // Add to session history (without output since we can't capture it)
            let terminalCommand = TerminalCommand(command: command)
            currentSession?.addCommand(terminalCommand)
        }

        /// Execute in specific Terminal tab
        func executeInTerminalTab(_ command: String, windowIndex: Int, tabIndex: Int) async throws {
            try await executor.executeInTerminalTab(command, windowIndex: windowIndex, tabIndex: tabIndex)
        }

        /// Execute a sequence of commands
        func executeSequence(_ commands: [String], stopOnError: Bool = true) async throws -> [ShellCommandResult] {
            try await executor.executeSequence(commands, workingDirectory: currentSession?.workingDirectory, stopOnError: stopOnError)
        }

        // MARK: - MONITOR Output

        /// Start monitoring Terminal output for changes
        func startMonitoring(interval: TimeInterval = 0.5, onChange: @escaping (String) -> Void) {
            stopMonitoring()

            isMonitoring = true
            monitorTask = Task {
                var lastContent = ""
                while !Task.isCancelled {
                    do {
                        let content = try await readTerminalContent()
                        if content != lastContent {
                            let newContent: String = if lastContent.isEmpty {
                                content
                            } else if content.hasPrefix(lastContent) {
                                String(content.dropFirst(lastContent.count))
                            } else {
                                content
                            }

                            if !newContent.isEmpty {
                                await MainActor.run {
                                    onChange(newContent)
                                }
                            }
                            lastContent = content
                        }
                        try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                    } catch {
                        if !Task.isCancelled {
                            await MainActor.run {
                                self.lastError = error.localizedDescription
                            }
                        }
                        break
                    }
                }
            }
        }

        /// Stop monitoring Terminal output
        func stopMonitoring() {
            monitorTask?.cancel()
            monitorTask = nil
            isMonitoring = false
        }

        /// Wait for Terminal to become idle (no command running)
        func waitForIdle(timeout: TimeInterval = 30, pollInterval: TimeInterval = 0.5) async throws {
            let startTime = Date()
            while Date().timeIntervalSince(startTime) < timeout {
                if try await !isTerminalBusy() {
                    return
                }
                try await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
            }
            throw TerminalCommandExecutor.ExecutorError.timeout
        }

        // MARK: - Terminal.app Control

        /// Open a new Terminal window
        func openNewWindow(withCommand command: String? = nil) async throws {
            try await executor.openNewWindow(withCommand: command)
            await refreshWindowList()
        }

        /// Open a new tab in front window
        func openNewTab(withCommand command: String? = nil) async throws {
            try await executor.openNewTab(withCommand: command)
            await refreshWindowList()
        }

        /// Clear the Terminal screen
        func clearTerminal() async throws {
            try await executor.clearTerminal()
        }

        // MARK: - Session Management

        func createSession(name: String, workingDirectory: URL? = nil) -> TerminalSession {
            let session = TerminalSession(
                name: name,
                workingDirectory: workingDirectory ?? FileManager.default.homeDirectoryForCurrentUser
            )
            sessions.append(session)
            return session
        }

        func deleteSession(_ session: TerminalSession) {
            sessions.removeAll { $0.id == session.id }
            if currentSession?.id == session.id {
                currentSession = sessions.first
            }
        }

        func switchToSession(_ session: TerminalSession) {
            currentSession = session
        }

        // MARK: - Quick Commands

        func executeQuickCommand(_ quickCommand: QuickCommand) async throws -> ShellCommandResult {
            try await execute(quickCommand.command, workingDirectory: currentSession?.workingDirectory)
        }

        func addQuickCommand(_ command: QuickCommand) {
            quickCommands.append(command)
            saveConfiguration()
        }

        func removeQuickCommand(_ command: QuickCommand) {
            quickCommands.removeAll { $0.id == command.id }
            saveConfiguration()
        }

        // MARK: - Configuration Persistence

        private func loadConfiguration() {
            let defaults = UserDefaults.standard

            if let modeRaw = defaults.string(forKey: "terminal.executionMode"),
               let mode = ExecutionMode(rawValue: modeRaw)
            {
                executionMode = mode
            }

            if let displayRaw = defaults.string(forKey: "terminal.outputDisplay"),
               let display = OutputDisplay(rawValue: displayRaw)
            {
                showOutputIn = display
            }

            if let policyData = defaults.data(forKey: "terminal.securityPolicy"),
               let policy = try? JSONDecoder().decode(TerminalSecurityPolicy.self, from: policyData)
            {
                securityPolicy = policy
                executor = TerminalCommandExecutor(securityPolicy: policy)
            }

            if let commandsData = defaults.data(forKey: "terminal.quickCommands"),
               let commands = try? JSONDecoder().decode([QuickCommand].self, from: commandsData)
            {
                quickCommands = commands
            }

            isEnabled = defaults.bool(forKey: "terminal.isEnabled")
            if !defaults.dictionaryRepresentation().keys.contains("terminal.isEnabled") {
                isEnabled = true
            }
        }

        func saveConfiguration() {
            let defaults = UserDefaults.standard

            defaults.set(executionMode.rawValue, forKey: "terminal.executionMode")
            defaults.set(showOutputIn.rawValue, forKey: "terminal.outputDisplay")
            defaults.set(isEnabled, forKey: "terminal.isEnabled")

            if let policyData = try? JSONEncoder().encode(securityPolicy) {
                defaults.set(policyData, forKey: "terminal.securityPolicy")
            }

            if let commandsData = try? JSONEncoder().encode(quickCommands) {
                defaults.set(commandsData, forKey: "terminal.quickCommands")
            }

            // Update executor with new policy
            executor = TerminalCommandExecutor(securityPolicy: securityPolicy)
        }

        private func saveCommandHistory() {
            guard let session = currentSession else { return }

            // Capture the data we need before entering the detached task
            let historyURL = commandHistoryURL
            let historyToSave = Array(session.commandHistory.suffix(1000))

            Task.detached {
                if let data = try? JSONEncoder().encode(historyToSave) {
                    try? data.write(to: historyURL)
                }
            }
        }

        func loadCommandHistory() -> [TerminalCommand] {
            guard let data = try? Data(contentsOf: commandHistoryURL),
                  let history = try? JSONDecoder().decode([TerminalCommand].self, from: data)
            else {
                return []
            }
            return history
        }
    }

    // MARK: - Quick Command

    struct QuickCommand: Identifiable, Codable, Equatable {
        let id: UUID
        var name: String
        var command: String
        var icon: String
        var category: Category

        enum Category: String, Codable, CaseIterable {
            case git = "Git"
            case build = "Build"
            case system = "System"
            case network = "Network"
            case custom = "Custom"

            var systemImage: String {
                switch self {
                case .git: "arrow.triangle.branch"
                case .build: "hammer"
                case .system: "gearshape"
                case .network: "network"
                case .custom: "star"
                }
            }
        }

        init(id: UUID = UUID(), name: String, command: String, icon: String = "terminal", category: Category = .custom) {
            self.id = id
            self.name = name
            self.command = command
            self.icon = icon
            self.category = category
        }

        static var defaults: [QuickCommand] {
            [
                QuickCommand(name: "Git Status", command: "git status", icon: "arrow.triangle.branch", category: .git),
                QuickCommand(name: "Git Pull", command: "git pull", icon: "arrow.down", category: .git),
                QuickCommand(name: "Git Push", command: "git push", icon: "arrow.up", category: .git),
                QuickCommand(name: "Git Log", command: "git log --oneline -10", icon: "list.bullet", category: .git),
                QuickCommand(name: "Swift Build", command: "swift build", icon: "hammer", category: .build),
                QuickCommand(name: "Xcode Build", command: "xcodebuild build", icon: "hammer.fill", category: .build),
                QuickCommand(name: "List Files", command: "ls -la", icon: "folder", category: .system),
                QuickCommand(name: "Disk Usage", command: "df -h", icon: "internaldrive", category: .system),
                QuickCommand(name: "Process List", command: "ps aux | head -20", icon: "cpu", category: .system),
                QuickCommand(name: "Network Info", command: "ifconfig | grep inet", icon: "network", category: .network),
                QuickCommand(name: "Ping Google", command: "ping -c 3 google.com", icon: "antenna.radiowaves.left.and.right", category: .network)
            ]
        }
    }
#endif
