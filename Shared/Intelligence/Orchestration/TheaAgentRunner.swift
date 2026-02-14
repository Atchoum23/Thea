//
//  TheaAgentRunner.swift
//  Thea
//
//  Executes sub-agent tasks by calling AI providers.
//  Replaces the stub executeTask() in EnhancedSubagentSystem with real provider calls.
//  Includes context monitoring and preemptive summarization.
//

import Foundation
import os.log

// MARK: - TheaAgentRunner

/// Actor that executes sub-agent sessions against real AI providers.
/// Handles streaming, context pressure monitoring, and summarization.
actor TheaAgentRunner {
    private let logger = Logger(subsystem: "app.thea", category: "AgentRunner")

    // MARK: - Execute

    /// Run a session against the given provider and model.
    func execute(session: TheaAgentSession, provider: AIProvider, model: String) async {
        await MainActor.run { session.transition(to: .planning) }

        // Build system prompt from agent type
        let systemPrompt = session.agentType.systemPrompt

        let systemMessage = AIMessage(
            id: UUID(),
            conversationID: session.parentConversationID,
            role: .system,
            content: .text(systemPrompt),
            timestamp: Date(),
            model: model
        )

        let userMessage = AIMessage(
            id: UUID(),
            conversationID: session.parentConversationID,
            role: .user,
            content: .text(session.taskDescription),
            timestamp: Date(),
            model: model
        )

        await MainActor.run {
            session.appendMessage(TheaAgentMessage(role: .system, content: systemPrompt))
            session.appendMessage(TheaAgentMessage(role: .user, content: session.taskDescription))
            session.transition(to: .working)
            session.statusMessage = "Generating response..."
        }

        // Send status via AgentCommunicationBus
        await AgentCommunicationBus.shared.send(BusAgentMessage(
            id: UUID(),
            timestamp: Date(),
            senderAgentId: session.id,
            recipientAgentId: nil,
            messageType: .statusUpdate,
            payload: .text("Started working on: \(session.taskDescription.prefix(100))"),
            priority: .normal,
            correlationId: session.parentConversationID
        ))

        do {
            let stream = try await provider.chat(
                messages: [systemMessage, userMessage],
                model: model,
                stream: true
            )

            var fullResponse = ""
            var totalTokens = 0

            for try await chunk in stream {
                // Check if cancelled
                let currentState = await MainActor.run { session.state }
                guard currentState == .working else { break }

                switch chunk.type {
                case let .delta(text):
                    fullResponse += text
                    await MainActor.run {
                        session.statusMessage = "Generating response..."
                    }

                case let .complete(msg):
                    if case let .text(completeText) = msg.content {
                        fullResponse = completeText
                    }
                    if let usage = msg.tokenCount {
                        totalTokens = usage
                    }

                case .error:
                    break
                }
            }

            // Update session with results
            await MainActor.run {
                session.appendMessage(TheaAgentMessage(role: .agent, content: fullResponse))
                session.tokensUsed += totalTokens > 0 ? totalTokens : estimateTokens(fullResponse)
                session.updateContextPressure()
                session.confidence = estimateConfidence(fullResponse)
                session.statusMessage = "Completed"
                session.transition(to: .completed)
            }

            // Extract artifacts if response contains code blocks
            let artifacts = extractArtifacts(from: fullResponse)
            if !artifacts.isEmpty {
                await MainActor.run {
                    for artifact in artifacts {
                        session.addArtifact(artifact)
                    }
                }
            }

            // Broadcast completion
            await AgentCommunicationBus.shared.broadcastResult(
                from: session.id,
                taskId: session.id,
                output: String(fullResponse.prefix(500)),
                success: true,
                metadata: ["tokensUsed": "\(session.tokensUsed)"],
                correlationId: session.parentConversationID
            )

            // Check if context pressure warrants summarization
            let pressure = await MainActor.run { session.contextPressure }
            if pressure >= .elevated {
                await summarizeContext(session: session, provider: provider, model: model)
            }

            logger.info("Agent \(session.id.uuidString.prefix(8)) completed: \(fullResponse.count) chars, \(totalTokens) tokens")

        } catch {
            await MainActor.run {
                session.error = error.localizedDescription
                session.statusMessage = "Failed: \(error.localizedDescription)"
                session.transition(to: .failed)
            }

            await AgentCommunicationBus.shared.send(BusAgentMessage(
                id: UUID(),
                timestamp: Date(),
                senderAgentId: session.id,
                recipientAgentId: nil,
                messageType: .errorNotification,
                payload: .text(error.localizedDescription),
                priority: .high,
                correlationId: session.parentConversationID
            ))

            logger.error("Agent \(session.id.uuidString.prefix(8)) failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Context Summarization

    /// Compress older messages into a summary to free context window.
    func summarizeContext(session: TheaAgentSession, provider: AIProvider, model: String) async {
        let messages = await MainActor.run { session.messages }
        guard messages.count > 3 else { return }

        // Build summarization prompt
        let conversationText = messages.dropLast(2).map { "\($0.role.rawValue): \($0.content)" }.joined(separator: "\n")
        let summarizationPrompt = "Summarize the key findings, decisions, and artifacts from this conversation in under 200 words:\n\n\(conversationText)"

        let summaryMessage = AIMessage(
            id: UUID(),
            conversationID: session.parentConversationID,
            role: .user,
            content: .text(summarizationPrompt),
            timestamp: Date(),
            model: model
        )

        do {
            let stream = try await provider.chat(messages: [summaryMessage], model: model, stream: false)
            var summaryText = ""

            for try await chunk in stream {
                switch chunk.type {
                case let .delta(text): summaryText += text
                case let .complete(msg):
                    if case let .text(text) = msg.content { summaryText = text }
                default: break
                }
            }

            guard !summaryText.isEmpty else { return }

            await MainActor.run {
                // Keep last 2 messages, replace everything before with summary
                let recentMessages = Array(session.messages.suffix(2))
                session.messages = [
                    TheaAgentMessage(role: .system, content: "[Context Summary]\n\(summaryText)")
                ] + recentMessages
                session.summarizationCount += 1
                session.lastSummarizedAt = Date()
                session.updateContextPressure()
            }

            logger.info("Summarized context for agent \(session.id.uuidString.prefix(8)), compression #\(await MainActor.run { session.summarizationCount })")

        } catch {
            logger.warning("Context summarization failed for agent \(session.id.uuidString.prefix(8)): \(error.localizedDescription)")
        }
    }

    /// Distill a completed session's findings into a compact summary for the supervisor.
    func distillAndRelease(session: TheaAgentSession) async -> String {
        let messages = await MainActor.run { session.messages }
        let agentOutput = messages
            .filter { $0.role == .agent }
            .map(\.content)
            .joined(separator: "\n\n")

        let artifacts = await MainActor.run { session.artifacts }
        let artifactSummary = artifacts.map { "\($0.type.rawValue): \($0.title)" }.joined(separator: ", ")

        var distilled = "[\(session.agentType.rawValue)] \(agentOutput.prefix(1000))"
        if !artifactSummary.isEmpty {
            distilled += "\nArtifacts: \(artifactSummary)"
        }

        return distilled
    }

    // MARK: - Helpers

    private func estimateTokens(_ text: String) -> Int {
        // Rough estimate: ~4 chars per token
        text.count / 4
    }

    private func estimateConfidence(_ response: String) -> Float {
        // Basic heuristic: longer, structured responses = higher confidence
        let length = response.count
        let hasCodeBlocks = response.contains("```")
        let hasHeaders = response.contains("##") || response.contains("**")

        var score: Float = 0.5
        if length > 200 { score += 0.1 }
        if length > 500 { score += 0.1 }
        if hasCodeBlocks { score += 0.1 }
        if hasHeaders { score += 0.1 }
        return min(score, 1.0)
    }

    private func extractArtifacts(from response: String) -> [TheaAgentArtifact] {
        var artifacts: [TheaAgentArtifact] = []

        // Extract fenced code blocks
        let pattern = "```(\\w+)?\\n([\\s\\S]*?)```"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return artifacts }

        let nsResponse = response as NSString
        let matches = regex.matches(in: response, range: NSRange(location: 0, length: nsResponse.length))

        for (index, match) in matches.enumerated() {
            let language = match.range(at: 1).location != NSNotFound
                ? nsResponse.substring(with: match.range(at: 1))
                : "code"
            let code = nsResponse.substring(with: match.range(at: 2))

            let artifact = TheaAgentArtifact(
                title: "Code Block \(index + 1) (\(language))",
                type: .code,
                content: code
            )
            artifacts.append(artifact)
        }

        return artifacts
    }
}
