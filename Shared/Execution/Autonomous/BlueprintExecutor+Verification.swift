// BlueprintExecutor+Verification.swift
// Thea V2
//
// Verification, condition evaluation, error recovery, and logging
// for BlueprintExecutor.

import Foundation

// MARK: - Verification & Recovery

extension BlueprintExecutor {

    func runVerification(_ check: BlueprintVerificationCheck) async -> BlueprintStepResult {
        switch check {
        case .buildSucceeds(let scheme):
            let result = await buildVerifier.verifyBuild(scheme: scheme)
            if result.success {
                return BlueprintStepResult(step: "Build \(scheme)", success: true)
            } else {
                let errorSummary = result.errors.map { $0.message }.joined(separator: "\n")
                return BlueprintStepResult(step: "Build \(scheme)", success: false, error: errorSummary)
            }

        case .testsPass(let target):
            let result = await buildVerifier.runTests(target: target)
            return BlueprintStepResult(
                step: "Tests \(target ?? "all")",
                success: result.success,
                error: result.success ? nil : "Tests failed"
            )

        case .fileExists(let path):
            let exists = FileManager.default.fileExists(atPath: path)
            return BlueprintStepResult(step: "File exists \(path)", success: exists)

        case .commandSucceeds(let command):
            return await executeCommand(command)

        case .custom(let description, let check):
            let success = await check()
            return BlueprintStepResult(step: description, success: success)
        }
    }

    func evaluateCondition(_ condition: BlueprintCondition) async -> Bool {
        switch condition {
        case .fileExists(let path):
            return FileManager.default.fileExists(atPath: path)

        case .commandSucceeds(let command):
            let result = await executeCommand(command)
            return result.success

        case .always:
            return true

        case .never:
            return false
        }
    }

    func attemptRecovery(step: BlueprintStep, error: String) async -> String? {
        // Analyze error and suggest fix
        if error.contains("cannot find type") {
            return "Missing import - will add required import statement"
        } else if error.contains("no such file") {
            return "File not found - will create required file"
        } else if error.contains("permission denied") {
            return "Permission issue - will request elevated permissions"
        }

        // Use AI for complex recovery
        guard let provider = ProviderRegistry.shared.getDefaultProvider() else {
            return nil
        }

        let prompt = """
        An error occurred during automated execution:
        Step: \(step.description)
        Error: \(error)

        Suggest a brief recovery action (1 line).
        """

        do {
            let model = await DynamicConfig.shared.bestModel(for: .classification)
            let messages = [AIMessage(
                id: UUID(), conversationID: UUID(), role: .user,
                content: .text(prompt), timestamp: Date(), model: model
            )]
            let stream = try await provider.chat(messages: messages, model: model, stream: false)
            var suggestion = ""
            for try await chunk in stream {
                switch chunk.type {
                case .delta(let text): suggestion += text
                case .thinkingDelta: break
                case .complete(let msg): suggestion = msg.content.textValue
                case .error(let err): throw err
                }
            }
            return suggestion.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        } catch {
            return nil
        }
    }

    func extractErrorMessage(from output: String) -> String {
        // Find first error line
        let lines = output.components(separatedBy: .newlines)
        for line in lines {
            if line.contains("error:") || line.contains("Error:") {
                return line.trimmingCharacters(in: .whitespaces)
            }
        }
        return "Unknown error"
    }

    func log(_ message: String, level: BlueprintLogLevel = .info) {
        let entry = BlueprintLogEntry(timestamp: Date(), level: level, message: message)
        executionLog.append(entry)

        // Prevent unbounded log growth using dynamic limit
        let maxEntries = maxLogEntries
        if executionLog.count > maxEntries {
            executionLog.removeFirst(executionLog.count - maxEntries)
        }

        switch level {
        case .info:
            logger.info("\(message)")
        case .warning:
            logger.warning("\(message)")
        case .error:
            logger.error("\(message)")
        }
    }
}
