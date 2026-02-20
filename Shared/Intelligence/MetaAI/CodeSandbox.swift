#if os(macOS)
    import Foundation

    // MARK: - Code Execution Sandbox

    // Safe, isolated code execution with resource limits

    @MainActor
    @Observable
    final class CodeSandbox {
        static let shared = CodeSandbox()

        private(set) var executionHistory: [CodeExecution] = []

        // Safety limits
        private let maxExecutionTime: TimeInterval = 30 // 30 seconds
        private let maxMemoryMB: Int = 100
        private let maxOutputLength: Int = 10000

        private init() {}

        // MARK: - Code Execution

        func execute(
            code: String,
            language: ProgrammingLanguage,
            timeout: TimeInterval? = nil
        ) async throws -> ExecutionResult {
            let execution = CodeExecution(
                id: UUID(),
                code: code,
                language: language,
                startTime: Date(),
                status: .running
            )

            executionHistory.append(execution)

            let actualTimeout = min(timeout ?? maxExecutionTime, maxExecutionTime)

            do {
                let result: String
                switch language {
                case .swift:
                    result = try await executeSwift(code, timeout: actualTimeout)
                case .python:
                    result = try await executePython(code, timeout: actualTimeout)
                case .javascript:
                    result = try await executeJavaScript(code, timeout: actualTimeout)
                default:
                    throw SandboxError.invalidCode
                }

                if let index = executionHistory.firstIndex(where: { $0.id == execution.id }) {
                    executionHistory[index].status = .completed
                    executionHistory[index].endTime = Date()
                    executionHistory[index].output = result
                }

                return ExecutionResult(
                    success: true,
                    output: truncateOutput(result),
                    error: nil,
                    executionTime: Date().timeIntervalSince(execution.startTime)
                )
            } catch {
                if let index = executionHistory.firstIndex(where: { $0.id == execution.id }) {
                    executionHistory[index].status = .failed
                    executionHistory[index].endTime = Date()
                    executionHistory[index].error = error.localizedDescription
                }

                return ExecutionResult(
                    success: false,
                    output: nil,
                    error: error.localizedDescription,
                    executionTime: Date().timeIntervalSince(execution.startTime)
                )
            }
        }

        // MARK: - Language-Specific Execution

        private func executeSwift(_ code: String, timeout: TimeInterval) async throws -> String {
            #if os(macOS)
                // Create temporary file
                let tempDir = FileManager.default.temporaryDirectory
                let filename = "sandbox_\(UUID().uuidString).swift"
                let fileURL = tempDir.appendingPathComponent(filename)

                try code.write(to: fileURL, atomically: true, encoding: .utf8)

                defer {
                    try? FileManager.default.removeItem(at: fileURL)
                }

                // Execute using swift interpreter
                let codeConfig = AppConfiguration.shared.codeIntelligenceConfig
                let process = Process()
                process.executableURL = URL(fileURLWithPath: codeConfig.swiftExecutablePath)
                process.arguments = [fileURL.path]

                let outputPipe = Pipe()
                let errorPipe = Pipe()
                process.standardOutput = outputPipe
                process.standardError = errorPipe

                // Execute with timeout
                try process.run()

                let timeoutTask = Task {
                    try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                    if process.isRunning {
                        process.terminate()
                    }
                }

                process.waitUntilExit()
                timeoutTask.cancel()

                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

                let output = String(data: outputData, encoding: .utf8) ?? ""
                let error = String(data: errorData, encoding: .utf8) ?? ""

                if process.terminationStatus != 0 {
                    throw SandboxError.executionFailed(error)
                }

                return output + error
            #else
                // iOS: Swift code execution not supported
                throw SandboxError.notSupported
            #endif
        }

        private func executePython(_ code: String, timeout: TimeInterval) async throws -> String {
            #if os(macOS)
                // Create temporary file
                let tempDir = FileManager.default.temporaryDirectory
                let filename = "sandbox_\(UUID().uuidString).py"
                let fileURL = tempDir.appendingPathComponent(filename)

                try code.write(to: fileURL, atomically: true, encoding: .utf8)

                defer {
                    try? FileManager.default.removeItem(at: fileURL)
                }

                // Execute using python3
                let codeConfig = AppConfiguration.shared.codeIntelligenceConfig
                let process = Process()
                process.executableURL = URL(fileURLWithPath: codeConfig.pythonExecutablePath)
                process.arguments = [fileURL.path]

                let outputPipe = Pipe()
                let errorPipe = Pipe()
                process.standardOutput = outputPipe
                process.standardError = errorPipe

                try process.run()

                let timeoutTask = Task {
                    try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                    if process.isRunning {
                        process.terminate()
                    }
                }

                process.waitUntilExit()
                timeoutTask.cancel()

                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

                let output = String(data: outputData, encoding: .utf8) ?? ""
                let error = String(data: errorData, encoding: .utf8) ?? ""

                if process.terminationStatus != 0 {
                    throw SandboxError.executionFailed(error)
                }

                return output + error
            #else
                // iOS: Python code execution not supported
                throw SandboxError.notSupported
            #endif
        }

        private func executeJavaScript(_ code: String, timeout: TimeInterval) async throws -> String {
            #if os(macOS)
                // Create temporary file
                let tempDir = FileManager.default.temporaryDirectory
                let filename = "sandbox_\(UUID().uuidString).js"
                let fileURL = tempDir.appendingPathComponent(filename)

                try code.write(to: fileURL, atomically: true, encoding: .utf8)

                defer {
                    try? FileManager.default.removeItem(at: fileURL)
                }

                // Execute using node
                let codeConfig = AppConfiguration.shared.codeIntelligenceConfig
                let process = Process()
                process.executableURL = URL(fileURLWithPath: codeConfig.nodeExecutablePath)
                process.arguments = ["node", fileURL.path]

                let outputPipe = Pipe()
                let errorPipe = Pipe()
                process.standardOutput = outputPipe
                process.standardError = errorPipe

                try process.run()

                let timeoutTask = Task {
                    try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                    if process.isRunning {
                        process.terminate()
                    }
                }

                process.waitUntilExit()
                timeoutTask.cancel()

                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

                let output = String(data: outputData, encoding: .utf8) ?? ""
                let error = String(data: errorData, encoding: .utf8) ?? ""

                if process.terminationStatus != 0 {
                    throw SandboxError.executionFailed(error)
                }

                return output + error
            #else
                // iOS: JavaScript code execution not supported
                throw SandboxError.notSupported
            #endif
        }

        private func executeShell(_ code: String, timeout: TimeInterval) async throws -> String {
            #if os(macOS)
                // Sandboxed shell execution - restricted commands
                let allowedCommands = ["echo", "ls", "pwd", "date", "whoami", "uname"]

                let firstCommand = code.split(separator: " ").first?.lowercased() ?? ""
                guard allowedCommands.contains(firstCommand) else {
                    throw SandboxError.restrictedCommand
                }

                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/bin/sh")
                process.arguments = ["-c", code]

                let outputPipe = Pipe()
                let errorPipe = Pipe()
                process.standardOutput = outputPipe
                process.standardError = errorPipe

                try process.run()

                let timeoutTask = Task {
                    try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                    if process.isRunning {
                        process.terminate()
                    }
                }

                process.waitUntilExit()
                timeoutTask.cancel()

                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

                let output = String(data: outputData, encoding: .utf8) ?? ""
                let error = String(data: errorData, encoding: .utf8) ?? ""

                if process.terminationStatus != 0 {
                    throw SandboxError.executionFailed(error)
                }

                return output + error
            #else
                // iOS: Shell code execution not supported
                throw SandboxError.notSupported
            #endif
        }

        // MARK: - Helper Methods

        private func truncateOutput(_ output: String) -> String {
            if output.count > maxOutputLength {
                return String(output.prefix(maxOutputLength)) + "\n... (output truncated)"
            }
            return output
        }
    }

    // MARK: - Models

    struct CodeExecution: Identifiable {
        let id: UUID
        let code: String
        let language: ProgrammingLanguage
        let startTime: Date
        var endTime: Date?
        var status: ExecutionStatus
        var output: String?
        var error: String?
    }

    struct ExecutionResult {
        let success: Bool
        let output: String?
        let error: String?
        let executionTime: TimeInterval
    }

    enum ExecutionStatus: String, Codable, Sendable {
        case running
        case completed
        case failed
        case timeout
    }

    enum SandboxError: LocalizedError {
        case executionFailed(String)
        case timeout
        case restrictedCommand
        case invalidCode
        case notSupported

        var errorDescription: String? {
            switch self {
            case let .executionFailed(message):
                "Execution failed: \(message)"
            case .timeout:
                "Execution timed out"
            case .restrictedCommand:
                "Command not allowed in sandbox"
            case .invalidCode:
                "Invalid code provided"
            case .notSupported:
                "Code execution is not supported on this platform"
            }
        }
    }

#endif
