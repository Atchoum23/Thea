import Foundation

/// Represents a terminal session with command history and state
@Observable
final class TerminalSession: Identifiable, Codable {
    let id: UUID
    var name: String
    var workingDirectory: URL
    var commandHistory: [TerminalCommand]
    var isActive: Bool
    var createdAt: Date
    var lastActivityAt: Date
    var shellType: ShellType
    var environment: [String: String]

    enum ShellType: String, Codable, CaseIterable {
        case zsh = "/bin/zsh"
        case bash = "/bin/bash"
        case fish = "/opt/homebrew/bin/fish"
        case sh = "/bin/sh"

        var displayName: String {
            switch self {
            case .zsh: return "Zsh"
            case .bash: return "Bash"
            case .fish: return "Fish"
            case .sh: return "POSIX Shell"
            }
        }
    }

    init(
        id: UUID = UUID(),
        name: String = "Terminal",
        workingDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        shellType: ShellType = .zsh
    ) {
        self.id = id
        self.name = name
        self.workingDirectory = workingDirectory
        self.commandHistory = []
        self.isActive = true
        self.createdAt = Date()
        self.lastActivityAt = Date()
        self.shellType = shellType
        self.environment = ProcessInfo.processInfo.environment
    }

    func addCommand(_ command: TerminalCommand) {
        commandHistory.append(command)
        lastActivityAt = Date()
    }

    enum CodingKeys: String, CodingKey {
        case id, name, workingDirectory, commandHistory, isActive, createdAt, lastActivityAt, shellType, environment
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        workingDirectory = try container.decode(URL.self, forKey: .workingDirectory)
        commandHistory = try container.decode([TerminalCommand].self, forKey: .commandHistory)
        isActive = try container.decode(Bool.self, forKey: .isActive)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        lastActivityAt = try container.decode(Date.self, forKey: .lastActivityAt)
        shellType = try container.decode(ShellType.self, forKey: .shellType)
        environment = try container.decode([String: String].self, forKey: .environment)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(workingDirectory, forKey: .workingDirectory)
        try container.encode(commandHistory, forKey: .commandHistory)
        try container.encode(isActive, forKey: .isActive)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(lastActivityAt, forKey: .lastActivityAt)
        try container.encode(shellType, forKey: .shellType)
        try container.encode(environment, forKey: .environment)
    }
}

/// Represents a single terminal command with its result
struct TerminalCommand: Identifiable, Codable {
    let id: UUID
    let command: String
    var output: String
    var errorOutput: String
    var exitCode: Int32
    var executedAt: Date
    var duration: TimeInterval
    var workingDirectory: URL
    var wasSuccessful: Bool { exitCode == 0 }

    init(
        id: UUID = UUID(),
        command: String,
        output: String = "",
        errorOutput: String = "",
        exitCode: Int32 = 0,
        executedAt: Date = Date(),
        duration: TimeInterval = 0,
        workingDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) {
        self.id = id
        self.command = command
        self.output = output
        self.errorOutput = errorOutput
        self.exitCode = exitCode
        self.executedAt = executedAt
        self.duration = duration
        self.workingDirectory = workingDirectory
    }
}

/// Result of a command execution
struct CommandResult: Sendable {
    let output: String
    let errorOutput: String
    let exitCode: Int32
    let command: String
    let duration: TimeInterval

    var wasSuccessful: Bool { exitCode == 0 }
    var combinedOutput: String {
        if errorOutput.isEmpty { return output }
        if output.isEmpty { return errorOutput }
        return output + "\n" + errorOutput
    }
}

/// State of Terminal.app windows
struct TerminalState {
    let windowCount: Int
    let tabs: [TabInfo]

    struct TabInfo {
        let windowIndex: Int
        let tabIndex: Int
        let isBusy: Bool
        let processes: [String]
        let ttyName: String
    }
}
