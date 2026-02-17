// TheaIdentityPrompt.swift
// Unified, dynamic self-identity system prompt for Thea
// Replaces scattered prompt assembly with a single comprehensive identity

import Foundation

/// Assembles Thea's complete system prompt from runtime state.
///
/// Sections (in order, empty sections skipped):
/// 1. Core Identity — from SystemPromptConfiguration.basePrompt
/// 2. Capabilities — dynamic from runtime singletons
/// 3. Device Context — enhanced device + ecosystem awareness
/// 4. Privacy Posture — current privacy guard mode
/// 5. Task Instructions — user override or built-in fallback
/// 6. Coding Preferences — injected for code-related tasks
/// 7. Conversation Context — custom prompt + language
@MainActor
enum TheaIdentityPrompt {

    // MARK: - Public Entry Point

    static func build(
        taskType: TaskType?,
        conversationLanguage: String?,
        conversationSystemPrompt: String?
    ) -> String {
        var sections: [String] = []

        // 1. Core Identity
        sections.append(buildCoreIdentity())

        // 2. Capabilities
        let capabilities = buildCapabilities()
        if !capabilities.isEmpty { sections.append(capabilities) }

        // 3. Device Context
        sections.append(buildDeviceContext())

        // 4. Privacy Posture
        let privacy = buildPrivacyPosture()
        if !privacy.isEmpty { sections.append(privacy) }

        // 5. Task Instructions
        if let taskType {
            let taskInstructions = buildTaskInstructions(for: taskType)
            if !taskInstructions.isEmpty { sections.append(taskInstructions) }
        }

        // 6. Coding Preferences (for code-related tasks)
        if let taskType, taskType.isCodeRelated {
            sections.append(buildCodingPreferences())
        }

        // 7. Conversation Context
        let conversationContext = buildConversationContext(
            language: conversationLanguage,
            systemPrompt: conversationSystemPrompt
        )
        if !conversationContext.isEmpty { sections.append(conversationContext) }

        return sections.joined(separator: "\n\n")
    }

    // MARK: - Section Builders

    private static func buildCoreIdentity() -> String {
        let config = SystemPromptConfiguration.load()
        return config.basePrompt
    }

    private static func buildCapabilities() -> String {
        var lines: [String] = []
        lines.append("CAPABILITIES:")

        // AI Providers (only show configured ones with API keys)
        let configuredProviders = ProviderRegistry.shared.availableProviders.filter(\.isConfigured)
        if !configuredProviders.isEmpty {
            let names = configuredProviders.map(\.displayName)
            lines.append("- \(configuredProviders.count) AI providers active (\(names.joined(separator: ", "))) with intelligent task routing")
        }

        // Local Models (macOS only)
        #if os(macOS)
        let localModels = MLXModelManager.shared.scannedModels
        if !localModels.isEmpty {
            lines.append("- \(localModels.count) local ML models available for on-device inference (no data leaves device)")
        }
        #endif

        // Verification Pipeline
        lines.append("- Response verification: multi-model consensus, web fact-checking, code execution, static analysis, user feedback learning")

        // Agent Delegation
        if SettingsManager.shared.agentDelegationEnabled {
            lines.append("- Agent delegation: can dispatch complex tasks to specialized sub-agents")
        }

        // Autonomy Level
        let autonomyLevel = AutonomyController.shared.autonomyLevel
        lines.append("- Autonomy level: \(autonomyLevel.displayName)")

        // Cross-device sync
        let allDevices = DeviceRegistry.shared.registeredDevices
        if allDevices.count > 1 {
            lines.append("- Cross-device sync active across \(allDevices.count) devices")
        }

        // Voice (macOS)
        #if os(macOS)
        lines.append("- Voice: text-to-speech (Soprano-80M) and speech-to-text (GLM-ASR-Nano) available on-device")
        #endif

        return lines.count > 1 ? lines.joined(separator: "\n") : ""
    }

    private static func buildDeviceContext() -> String {
        let current = DeviceRegistry.shared.currentDevice
        let allDevices = DeviceRegistry.shared.registeredDevices
        let onlineDevices = DeviceRegistry.shared.onlineDevices

        var lines: [String] = []
        lines.append("DEVICE CONTEXT:")
        lines.append("- Current device: \(current.name) (\(current.type.displayName), \(current.osVersion))")

        #if os(macOS)
        let totalRAM = ProcessInfo.processInfo.physicalMemory / (1024 * 1024 * 1024)
        lines.append("- RAM: \(totalRAM) GB")
        if totalRAM >= 128 {
            lines.append("- Capability tier: heavy ML inference (70B+ models), parallel builds, large context")
        } else if totalRAM >= 32 {
            lines.append("- Capability tier: moderate ML inference, standard builds")
        } else {
            lines.append("- Capability tier: lightweight — prefer smaller models, avoid memory-intensive operations")
        }
        #endif

        if current.capabilities.supportsLocalModels {
            lines.append("- Local AI model execution supported (Neural Engine + GPU)")
        }

        if allDevices.count > 1 {
            let others = allDevices.filter { $0.id != current.id }
            let descriptions = others.map { device in
                let status = onlineDevices.contains { $0.id == device.id }? "online" : "offline"
                return "\(device.name) (\(device.type.displayName), \(status))"
            }
            lines.append("- Ecosystem: \(descriptions.joined(separator: ", "))")
        }

        lines.append("- Messages may originate from different devices (check message context)")

        return lines.joined(separator: "\n")
    }

    private static func buildPrivacyPosture() -> String {
        // OutboundPrivacyGuard is always active (strict mode default-deny)
        // Since it's an actor we can't query synchronously, but it's always on
        "PRIVACY: Outbound privacy guard ACTIVE (strict default-deny) — all messages sanitized for PII and credentials before cloud transmission. Never expose API keys, passwords, or tokens."
    }

    private static func buildTaskInstructions(for taskType: TaskType) -> String {
        let config = SystemPromptConfiguration.load()

        // User override takes priority
        if config.useDynamicPrompts, config.isCustomized(for: taskType) {
            let userPrompt = config.prompt(for: taskType)
            if !userPrompt.isEmpty { return userPrompt }
        }

        // Fall back to built-in task prompt
        let builtIn = ChatManager.buildTaskSpecificPrompt(for: taskType)

        // Planning addendum
        if taskType == .planning, !builtIn.isEmpty {
            return builtIn + "\n\n" +
                "IMPORTANT: Structure your response as a numbered plan with clear steps. " +
                "Start each step on its own line with a number and period. " +
                "Keep each step concise and actionable."
        }

        return builtIn
    }

    private static func buildCodingPreferences() -> String {
        """
        CODING STANDARDS:
        - Prefer composition over inheritance; use dependency injection for testability
        - Use proper types, enums, protocols — avoid Any, force casts, force unwraps
        - Keep files under 500 lines when practical; self-documenting code
        - Comments only for non-obvious logic; design for extensibility
        - Respect existing patterns — extend, don't hack
        - Fix issues immediately — no deferring; test edge cases and error conditions
        - Always choose the cleanest architectural solution, not the easiest hack
        """
    }

    private static func buildConversationContext(
        language: String?,
        systemPrompt: String?
    ) -> String {
        var parts: [String] = []

        if let customPrompt = systemPrompt, !customPrompt.isEmpty {
            parts.append(customPrompt)
        }

        if let lang = language,
           !lang.isEmpty,
           lang.count <= 10,
           lang.allSatisfy({ $0.isLetter || $0 == "-" }),
           let languageName = Locale.current.localizedString(forLanguageCode: lang)
        {
            parts.append(
                "LANGUAGE: Respond entirely in \(languageName). " +
                    "Maintain technical accuracy and use language-appropriate formatting. " +
                    "If the user writes in a different language, still respond in \(languageName) unless asked otherwise."
            )
        }

        return parts.joined(separator: "\n\n")
    }
}
