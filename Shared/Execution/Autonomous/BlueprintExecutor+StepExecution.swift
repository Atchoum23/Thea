// BlueprintExecutor+StepExecution.swift
// Thea V2
//
// Step execution methods for BlueprintExecutor.
// Handles command execution, file operations, and AI tasks.

import Foundation

// MARK: - Step Execution

extension BlueprintExecutor {

    func executeStep(_ step: BlueprintStep) async -> BlueprintStepResult {
        switch step.type {
        case .command(let command):
            return await executeCommand(command)

        case .fileOperation(let operation):
            return await executeFileOperation(operation)

        case .aiTask(let task):
            return await executeAITask(task)

        case .verification(let check):
            return await runVerification(check)

        case .conditional(let condition, let thenSteps, let elseSteps):
            let conditionMet = await evaluateCondition(condition)
            let steps = conditionMet ? thenSteps : elseSteps
            for subStep in steps {
                let result = await executeStep(subStep)
                if !result.success {
                    return result
                }
            }
            return BlueprintStepResult(step: step.description, success: true)
        }
    }

    func executeCommand(_ command: String) async -> BlueprintStepResult {
        log("Executing command: \(command)")

        #if os(macOS)
        do {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = ["-c", command]

            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            try process.run()
            process.waitUntilExit()

            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

            let output = String(data: outputData, encoding: .utf8) ?? ""
            let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
            let combinedOutput = output + errorOutput

            log("Command output: \(combinedOutput.prefix(500))...")

            // Check for common error patterns
            if process.terminationStatus != 0 || combinedOutput.contains("error:") || combinedOutput.contains("FAILED") {
                let errorMessage = extractErrorMessage(from: combinedOutput)
                errors.append(BlueprintExecutionError(
                    type: .commandFailed,
                    message: errorMessage,
                    context: command
                ))
                return BlueprintStepResult(step: command, success: false, error: errorMessage, output: combinedOutput)
            }

            return BlueprintStepResult(step: command, success: true, output: combinedOutput)
        } catch {
            let errorMsg = error.localizedDescription
            errors.append(BlueprintExecutionError(
                type: .commandFailed,
                message: errorMsg,
                context: command
            ))
            return BlueprintStepResult(step: command, success: false, error: errorMsg)
        }
        #else
        // Command execution not supported on iOS/watchOS/tvOS
        return BlueprintStepResult(step: command, success: false, error: "Command execution not available on this platform")
        #endif
    }

    func executeFileOperation(_ operation: BlueprintFileOperation) async -> BlueprintStepResult {
        switch operation {
        case .read(let path):
            do {
                let content = try String(contentsOfFile: path, encoding: .utf8)
                return BlueprintStepResult(step: "Read \(path)", success: true, output: content)
            } catch {
                return BlueprintStepResult(step: "Read \(path)", success: false, error: error.localizedDescription)
            }

        case .write(let path, let content):
            do {
                try content.write(toFile: path, atomically: true, encoding: .utf8)
                return BlueprintStepResult(step: "Write \(path)", success: true)
            } catch {
                return BlueprintStepResult(step: "Write \(path)", success: false, error: error.localizedDescription)
            }

        case .delete(let path):
            do {
                try FileManager.default.removeItem(atPath: path)
                return BlueprintStepResult(step: "Delete \(path)", success: true)
            } catch {
                return BlueprintStepResult(step: "Delete \(path)", success: false, error: error.localizedDescription)
            }

        case .move(let from, let to):
            do {
                try FileManager.default.moveItem(atPath: from, toPath: to)
                return BlueprintStepResult(step: "Move \(from) to \(to)", success: true)
            } catch {
                return BlueprintStepResult(step: "Move \(from) to \(to)", success: false, error: error.localizedDescription)
            }

        case .exists(let path):
            let exists = FileManager.default.fileExists(atPath: path)
            return BlueprintStepResult(step: "Check exists \(path)", success: exists, output: exists ? "exists" : "not found")
        }
    }

    func executeAITask(_ task: BlueprintAITask) async -> BlueprintStepResult {
        guard let provider = ProviderRegistry.shared.getDefaultProvider() else {
            return BlueprintStepResult(step: task.description, success: false, error: "No AI provider available")
        }

        do {
            let model: String
            if let specifiedModel = task.model {
                model = specifiedModel
            } else {
                model = await DynamicConfig.shared.bestModel(for: .codeGeneration)
            }

            var messages: [AIMessage] = []
            if let systemPrompt = task.systemPrompt, !systemPrompt.isEmpty {
                messages.append(AIMessage(
                    id: UUID(), conversationID: UUID(), role: .system,
                    content: .text(systemPrompt), timestamp: Date(), model: model
                ))
            }
            messages.append(AIMessage(
                id: UUID(), conversationID: UUID(), role: .user,
                content: .text(task.prompt), timestamp: Date(), model: model
            ))

            let stream = try await provider.chat(messages: messages, model: model, stream: false)
            var result = ""
            for try await chunk in stream {
                switch chunk.type {
                case .delta(let text): result += text
                case .complete(let msg): result = msg.content.textValue
                case .error(let err): throw err
                }
            }

            return BlueprintStepResult(step: task.description, success: true, output: result)
        } catch {
            return BlueprintStepResult(step: task.description, success: false, error: error.localizedDescription)
        }
    }
}
