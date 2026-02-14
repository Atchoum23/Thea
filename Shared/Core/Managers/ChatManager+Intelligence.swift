// ChatManager+Intelligence.swift
// Thea V4 — Orchestrator integration, prompt engineering, branching
//
// Extracted from ChatManager.swift for file size compliance.

import Foundation
import os.log

#if canImport(AppKit)
    import AppKit
#elseif canImport(UIKit)
    import UIKit
#endif

private let intLogger = Logger(subsystem: "ai.thea.app", category: "ChatManager+Intelligence")

extension ChatManager {

    // MARK: - Message Branching

    /// Edit a user message and create a new branch — re-sends to AI
    func editMessageAndBranch(
        _ message: Message,
        newContent: String,
        in conversation: Conversation
    ) async throws {
        guard let context = modelContext else { throw ChatError.noModelContext }
        guard message.messageRole == .user else { return }

        // Count existing branches for this parent
        let parentId = message.parentMessageId ?? message.id
        let existingBranches = conversation.messages.filter {
            $0.parentMessageId == parentId || $0.id == parentId
        }
        let branchIndex = existingBranches.count

        // Create branched message
        let branchedMessage = message.createBranch(
            newContent: .text(newContent),
            branchIndex: branchIndex
        )
        conversation.messages.append(branchedMessage)
        context.insert(branchedMessage)

        // Delete assistant messages that followed the original in the same branch
        let messagesAfter = conversation.messages.filter {
            $0.orderIndex > message.orderIndex && $0.branchIndex == message.branchIndex
        }
        for msg in messagesAfter {
            context.delete(msg)
        }

        try context.save()

        // Re-send to get a new AI response for the branched message
        try await sendMessage(newContent, in: conversation)
    }

    /// Get all branches (sibling messages) for a given message
    func getBranches(for message: Message, in conversation: Conversation) -> [Message] {
        let parentId = message.parentMessageId ?? message.id
        return conversation.messages
            .filter { $0.id == parentId || $0.parentMessageId == parentId }
            .sorted { $0.branchIndex < $1.branchIndex }
    }

    /// Switch the visible branch for a message position
    func switchToBranch(
        _ branchIndex: Int,
        for message: Message,
        in conversation: Conversation
    ) -> Message? {
        let branches = getBranches(for: message, in: conversation)
        guard branchIndex >= 0, branchIndex < branches.count else { return nil }
        return branches[branchIndex]
    }

    // MARK: - Plan Mode Integration

    /// Detect whether a user message during plan execution is modifying the plan
    func detectPlanModificationIntent(_ text: String) -> Bool {
        let lower = text.lowercased()
        let modifiers = [
            "also ", "additionally ", "add ", "don't forget ",
            "skip ", "remove ", "change ", "update ",
            "instead ", "actually ", "wait ", "hold on",
            "before that", "after that", "and also"
        ]
        return modifiers.contains { lower.contains($0) }
    }

    // MARK: - Orchestrator Integration

    /// Select provider and model using TaskClassifier + ModelRouter orchestration (macOS).
    /// Returns the classification result for automatic prompt engineering.
    func selectProviderAndModel(for query: String) async throws -> (AIProvider, String, TaskType?) {
        #if os(macOS)
        do {
            let classification = try await TaskClassifier.shared.classify(query)
            let decision = ModelRouter.shared.route(classification: classification)
            if let provider = ProviderRegistry.shared.getProvider(id: decision.model.provider) {
                return (provider, decision.model.id, classification.taskType)
            }
        } catch {
            intLogger.debug("⚠️ Orchestrator fallback: \(error.localizedDescription)")
        }
        #else
        _ = query
        #endif
        let (provider, model) = try getDefaultProviderAndModel()
        return (provider, model, nil)
    }

    /// Fallback: get default provider and model (original behavior)
    func getDefaultProviderAndModel() throws -> (AIProvider, String) {
        guard let provider = ProviderRegistry.shared.getDefaultProvider() else {
            throw ChatError.providerNotAvailable
        }
        let model = AppConfiguration.shared.providerConfig.defaultModel
        return (provider, model)
    }

    // MARK: - Auto-Delegation

    /// Determine if a task should be auto-delegated to a sub-agent
    func shouldAutoDelegate(taskType: TaskType?, text: String) -> Bool {
        guard SettingsManager.shared.agentDelegationEnabled,
              SettingsManager.shared.agentAutoDelegateComplexTasks,
              let taskType else {
            return false
        }

        // Tasks that are both complex (benefit from reasoning) and actionable are delegation candidates
        let isComplex = taskType.benefitsFromReasoning && taskType.isActionable
        // Multi-step requests (containing "and then", "also", "after that") suggest delegation
        let lower = text.lowercased()
        let isMultiStep = lower.contains(" and then ") || lower.contains(" after that ")
            || lower.contains(" also ") || lower.contains(" in parallel ")
            || lower.contains(", then ")

        return isComplex || isMultiStep
    }

    /// Delegate a task to the sub-agent orchestrator. Returns the session for UI tracking.
    func delegateToAgent(
        text: String,
        conversationID: UUID,
        taskType: TaskType?
    ) async -> TheaAgentSession? {
        let orchestrator = TheaAgentOrchestrator.shared
        let session = await orchestrator.delegateTask(
            description: text,
            from: conversationID,
            explicitAgentType: nil
        )
        intLogger.info("Auto-delegated task to agent: \(session.name) [\(session.agentType.rawValue)]")
        return session
    }

    // MARK: - Vision OCR for Image Attachments

    #if os(macOS) || os(iOS)
    /// Extracts text from image parts in a multimodal message using VisionOCR.
    func extractOCRFromImageParts(_ parts: [ContentPart]) async -> [String] {
        var ocrTexts: [String] = []
        for part in parts {
            if case let .image(imageData) = part.type {
                guard let cgImage = Self.cgImageFromData(imageData) else { continue }
                do {
                    let text = try await VisionOCR.shared.extractAllText(from: cgImage)
                    if !text.isEmpty {
                        ocrTexts.append(text)
                    }
                } catch {
                    intLogger.debug("⚠️ VisionOCR failed for image attachment: \(error.localizedDescription)")
                }
            }
        }
        return ocrTexts
    }

    static func cgImageFromData(_ data: Data) -> CGImage? {
        #if canImport(AppKit)
        guard let nsImage = NSImage(data: data), let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        return cgImage
        #elseif canImport(UIKit)
        guard let uiImage = UIImage(data: data), let cgImage = uiImage.cgImage else {
            return nil
        }
        return cgImage
        #else
        return nil
        #endif
    }
    #endif

    // MARK: - Device Context for AI

    /// Builds a device-aware context supplement for the system prompt.
    func buildDeviceContextPrompt() -> String {
        let current = DeviceRegistry.shared.currentDevice
        let allDevices = DeviceRegistry.shared.registeredDevices
        let onlineDevices = DeviceRegistry.shared.onlineDevices

        var lines: [String] = []
        lines.append("DEVICE CONTEXT:")
        lines.append("- Current device: \(current.name) (\(current.type.displayName), \(current.osVersion))")

        if current.capabilities.supportsLocalModels {
            lines.append("- This device supports local AI models")
        }

        #if os(macOS)
        let totalRAM = ProcessInfo.processInfo.physicalMemory / (1024 * 1024 * 1024)
        lines.append("- RAM: \(totalRAM) GB")
        #endif

        if allDevices.count > 1 {
            let others = allDevices.filter { $0.id != current.id }
            let otherNames = others.map { device in
                let status = onlineDevices.contains { $0.id == device.id } ? "online" : "offline"
                return "\(device.name) (\(device.type.displayName), \(status))"
            }
            lines.append("- Other devices in ecosystem: \(otherNames.joined(separator: ", "))")
        }

        lines.append("- User prompts from this conversation may originate from different devices (check message context).")

        return lines.joined(separator: "\n")
    }

    // MARK: - Automatic Prompt Engineering

    /// Generates task-specific system prompt instructions based on the classified task type.
    static func buildTaskSpecificPrompt(for taskType: TaskType) -> String {
        switch taskType {
        case .codeGeneration, .appDevelopment:
            return codingPrompt(.generation)
        case .codeAnalysis:
            return codingPrompt(.analysis)
        case .codeDebugging, .debugging:
            return codingPrompt(.debugging)
        case .codeExplanation:
            return codingPrompt(.explanation)
        case .codeRefactoring:
            return codingPrompt(.refactoring)
        case .factual, .simpleQA:
            return knowledgePrompt(.factual)
        case .creative, .creativeWriting, .contentCreation, .creation:
            return knowledgePrompt(.creative)
        case .analysis, .complexReasoning:
            return knowledgePrompt(.analysis)
        case .research, .informationRetrieval:
            return knowledgePrompt(.research)
        case .conversation, .general:
            return ""
        case .system, .workflowAutomation:
            return knowledgePrompt(.system)
        case .math, .mathLogic:
            return knowledgePrompt(.math)
        case .translation:
            return knowledgePrompt(.translation)
        case .summarization:
            return knowledgePrompt(.summarization)
        case .planning:
            return knowledgePrompt(.planning)
        case .unknown:
            return ""
        }
    }

    // MARK: - Coding Prompt Helpers

    private enum CodingCategory {
        case generation, analysis, debugging, explanation, refactoring
    }

    private static func codingPrompt(_ category: CodingCategory) -> String {
        switch category {
        case .generation:
            return """
            You are a senior software engineer. Write clean, production-ready code. \
            Follow best practices for the language. Include error handling. \
            Explain your design decisions briefly.
            """
        case .analysis:
            return """
            Analyze the code thoroughly. Identify potential bugs, performance issues, \
            security vulnerabilities, and style improvements. Be specific with line references.
            """
        case .debugging:
            return """
            Debug systematically. Identify the root cause, not just symptoms. \
            Explain why the bug occurs and provide a targeted fix. \
            Verify the fix doesn't introduce regressions.
            """
        case .explanation:
            return """
            Explain the code clearly at the appropriate level of detail. \
            Walk through the logic step by step. Highlight key patterns and design decisions.
            """
        case .refactoring:
            return """
            Refactor for clarity, maintainability, and performance. \
            Preserve existing behavior. Explain each change and its benefit. \
            Follow SOLID principles where applicable.
            """
        }
    }

    // MARK: - Knowledge Prompt Helpers

    private enum KnowledgeCategory {
        case factual, creative, analysis, research, system, math, translation, summarization, planning
    }

    private static func knowledgePrompt(_ category: KnowledgeCategory) -> String {
        switch category {
        case .factual:
            return """
            Provide accurate, well-sourced factual information. \
            Distinguish between established facts and your reasoning. \
            If uncertain, say so.
            """
        case .creative:
            return """
            Be creative and engaging. Match the requested tone and style. \
            Offer multiple options or approaches when appropriate.
            """
        case .analysis:
            return """
            Analyze thoroughly with structured reasoning. Consider multiple perspectives. \
            Support conclusions with evidence. Identify assumptions and limitations.
            """
        case .research:
            return """
            Research comprehensively. Organize findings clearly. \
            Cite sources when possible. Distinguish between primary and secondary information. \
            Note gaps in available information.
            """
        case .system:
            return """
            Provide precise system commands and configurations. \
            Warn about potentially destructive operations. \
            Include verification steps.
            """
        case .math:
            return """
            Show your work step by step. Use precise mathematical notation. \
            Verify your answer with a sanity check. Explain the approach before calculating.
            """
        case .translation:
            return """
            Translate accurately while preserving meaning, tone, and cultural nuance. \
            Note any idioms or phrases that don't translate directly. \
            Provide context where the translation might be ambiguous.
            """
        case .summarization:
            return """
            Summarize concisely while preserving key information. \
            Organize by importance. Include the main conclusions and supporting points. \
            Note any critical details that shouldn't be omitted.
            """
        case .planning:
            return """
            Create actionable plans with clear steps, dependencies, and priorities. \
            Identify risks and mitigation strategies. \
            Include time estimates where possible. Consider resource constraints.
            """
        }
    }

    /// Extract numbered steps from an AI response for plan creation.
    static func extractPlanSteps(from text: String) -> [String] {
        let lines = text.components(separatedBy: .newlines)
        var steps: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if let range = trimmed.range(of: #"^\d+[\.\)]\s+"#, options: .regularExpression) {
                let stepText = String(trimmed[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                if !stepText.isEmpty {
                    steps.append(stepText)
                }
            }
        }

        return steps
    }
}
