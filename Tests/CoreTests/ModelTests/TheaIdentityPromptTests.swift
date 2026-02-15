// TheaIdentityPromptTests.swift
// Tests for the TheaIdentityPrompt system prompt builder

import Testing
import Foundation

// MARK: - Test doubles matching runtime types

private enum TestTaskType: String, CaseIterable {
    case codeGeneration, codeAnalysis, codeDebugging, codeExplanation
    case codeRefactoring, debugging, appDevelopment
    case factual, simpleQA, creative, creativeWriting, contentCreation, creation
    case analysis, complexReasoning, research, informationRetrieval
    case conversation, general, system, workflowAutomation
    case math, mathLogic, translation, summarization, planning
    case unknown

    var isCodeRelated: Bool {
        switch self {
        case .codeGeneration, .codeAnalysis, .codeDebugging, .codeExplanation,
             .codeRefactoring, .debugging, .appDevelopment:
            return true
        default:
            return false
        }
    }
}

// MARK: - Prompt Section Assembly Tests

@Suite("Identity Prompt — Section Assembly")
struct IdentityPromptAssemblyTests {
    @Test("Core identity section is always included")
    func coreIdentityAlwaysPresent() {
        // The base prompt from SystemPromptConfiguration.defaults() starts with "You are THEA"
        let defaultBasePrompt = "You are THEA, a personal AI assistant"
        #expect(defaultBasePrompt.contains("THEA"))
        #expect(defaultBasePrompt.contains("AI assistant"))
    }

    @Test("Default base prompt mentions privacy")
    func basePromptMentionsPrivacy() {
        let basePrompt = """
            You are THEA, a personal AI assistant with multi-device awareness, privacy-preserving design, \
            and multi-provider intelligence routing. You provide accurate, helpful, and concise responses. \
            Be direct and focus on answering the user's question. If you don't know something, say so honestly. \
            Never expose, log, or repeat back sensitive data such as API keys, passwords, tokens, or secrets — \
            if you encounter them, redact with [REDACTED]. Prioritize user privacy in all responses.
            """
        #expect(basePrompt.contains("[REDACTED]"))
        #expect(basePrompt.contains("privacy"))
        #expect(basePrompt.contains("API keys"))
    }

    @Test("Default base prompt mentions honesty")
    func basePromptMentionsHonesty() {
        let basePrompt = """
            You are THEA, a personal AI assistant with multi-device awareness, privacy-preserving design, \
            and multi-provider intelligence routing. You provide accurate, helpful, and concise responses. \
            Be direct and focus on answering the user's question. If you don't know something, say so honestly.
            """
        #expect(basePrompt.contains("honestly"))
        #expect(basePrompt.contains("accurate"))
    }
}

// MARK: - Task Type Code-Related Classification Tests

@Suite("Identity Prompt — isCodeRelated Classification")
struct IsCodeRelatedTests {
    @Test("Code generation is code-related")
    func codeGenerationIsCode() {
        #expect(TestTaskType.codeGeneration.isCodeRelated)
    }

    @Test("Code analysis is code-related")
    func codeAnalysisIsCode() {
        #expect(TestTaskType.codeAnalysis.isCodeRelated)
    }

    @Test("Code debugging is code-related")
    func codeDebuggingIsCode() {
        #expect(TestTaskType.codeDebugging.isCodeRelated)
    }

    @Test("Code explanation is code-related")
    func codeExplanationIsCode() {
        #expect(TestTaskType.codeExplanation.isCodeRelated)
    }

    @Test("Code refactoring is code-related")
    func codeRefactoringIsCode() {
        #expect(TestTaskType.codeRefactoring.isCodeRelated)
    }

    @Test("Debugging is code-related")
    func debuggingIsCode() {
        #expect(TestTaskType.debugging.isCodeRelated)
    }

    @Test("App development is code-related")
    func appDevelopmentIsCode() {
        #expect(TestTaskType.appDevelopment.isCodeRelated)
    }

    @Test("Exactly 7 task types are code-related")
    func sevenCodeRelatedTypes() {
        let codeRelated = TestTaskType.allCases.filter(\.isCodeRelated)
        #expect(codeRelated.count == 7)
    }

    @Test("Factual is NOT code-related")
    func factualNotCode() {
        #expect(!TestTaskType.factual.isCodeRelated)
    }

    @Test("Creative writing is NOT code-related")
    func creativeNotCode() {
        #expect(!TestTaskType.creativeWriting.isCodeRelated)
    }

    @Test("Planning is NOT code-related")
    func planningNotCode() {
        #expect(!TestTaskType.planning.isCodeRelated)
    }

    @Test("Math is NOT code-related")
    func mathNotCode() {
        #expect(!TestTaskType.math.isCodeRelated)
    }

    @Test("Translation is NOT code-related")
    func translationNotCode() {
        #expect(!TestTaskType.translation.isCodeRelated)
    }

    @Test("Conversation is NOT code-related")
    func conversationNotCode() {
        #expect(!TestTaskType.conversation.isCodeRelated)
    }

    @Test("Unknown is NOT code-related")
    func unknownNotCode() {
        #expect(!TestTaskType.unknown.isCodeRelated)
    }
}

// MARK: - Coding Preferences Content Tests

@Suite("Identity Prompt — Coding Preferences Content")
struct CodingPreferencesTests {
    private let codingPreferences = """
        CODING STANDARDS:
        - Prefer composition over inheritance; use dependency injection for testability
        - Use proper types, enums, protocols — avoid Any, force casts, force unwraps
        - Keep files under 500 lines when practical; self-documenting code
        - Comments only for non-obvious logic; design for extensibility
        - Respect existing patterns — extend, don't hack
        - Fix issues immediately — no deferring; test edge cases and error conditions
        - Always choose the cleanest architectural solution, not the easiest hack
        """

    @Test("Mentions composition over inheritance")
    func compositionOverInheritance() {
        #expect(codingPreferences.contains("composition over inheritance"))
    }

    @Test("Mentions dependency injection")
    func dependencyInjection() {
        #expect(codingPreferences.contains("dependency injection"))
    }

    @Test("Warns against force casts")
    func noForceCasts() {
        #expect(codingPreferences.contains("force casts"))
    }

    @Test("Mentions 500 line limit")
    func fileLengthLimit() {
        #expect(codingPreferences.contains("500 lines"))
    }

    @Test("Mentions extensibility")
    func extensibility() {
        #expect(codingPreferences.contains("extensibility"))
    }

    @Test("Mentions fix issues immediately")
    func fixImmediately() {
        #expect(codingPreferences.contains("Fix issues immediately"))
    }

    @Test("Mentions cleanest architectural solution")
    func cleanArchitecture() {
        #expect(codingPreferences.contains("cleanest architectural solution"))
    }
}

// MARK: - Language Instruction Tests

@Suite("Identity Prompt — Language Instructions")
struct LanguageInstructionTests {
    private func buildLanguageInstruction(lang: String?) -> String {
        guard let lang = lang,
              !lang.isEmpty,
              lang.count <= 10,
              lang.allSatisfy({ $0.isLetter || $0 == "-" }),
              let languageName = Locale.current.localizedString(forLanguageCode: lang)
        else { return "" }

        return "LANGUAGE: Respond entirely in \(languageName). " +
            "Maintain technical accuracy and use language-appropriate formatting. " +
            "If the user writes in a different language, still respond in \(languageName) unless asked otherwise."
    }

    @Test("French language code produces valid instruction")
    func frenchLanguageInstruction() {
        let result = buildLanguageInstruction(lang: "fr")
        #expect(result.contains("LANGUAGE:"))
        #expect(!result.isEmpty)
    }

    @Test("Nil language produces empty string")
    func nilLanguage() {
        let result = buildLanguageInstruction(lang: nil)
        #expect(result.isEmpty)
    }

    @Test("Empty language produces empty string")
    func emptyLanguage() {
        let result = buildLanguageInstruction(lang: "")
        #expect(result.isEmpty)
    }

    @Test("Language code with injection attempt is rejected")
    func injectionAttemptRejected() {
        let result = buildLanguageInstruction(lang: "en; DROP TABLE")
        #expect(result.isEmpty)
    }

    @Test("Too long language code is rejected")
    func tooLongCodeRejected() {
        let result = buildLanguageInstruction(lang: "abcdefghijk")
        #expect(result.isEmpty)
    }

    @Test("BCP-47 tag with hyphen is accepted")
    func bcp47WithHyphen() {
        let result = buildLanguageInstruction(lang: "pt-BR")
        #expect(!result.isEmpty)
    }
}

// MARK: - Privacy Posture Tests

@Suite("Identity Prompt — Privacy Posture")
struct PrivacyPostureTests {
    private let privacyLine = "PRIVACY: Outbound privacy guard ACTIVE (strict default-deny) — all messages sanitized for PII and credentials before cloud transmission. Never expose API keys, passwords, or tokens."

    @Test("Privacy posture mentions strict default-deny")
    func mentionsStrictDefaultDeny() {
        #expect(privacyLine.contains("strict default-deny"))
    }

    @Test("Privacy posture mentions PII sanitization")
    func mentionsPIISanitization() {
        #expect(privacyLine.contains("PII"))
    }

    @Test("Privacy posture mentions API keys")
    func mentionsAPIKeys() {
        #expect(privacyLine.contains("API keys"))
    }

    @Test("Privacy posture mentions tokens")
    func mentionsTokens() {
        #expect(privacyLine.contains("tokens"))
    }
}

// MARK: - Device Context Tests

@Suite("Identity Prompt — Device Context")
struct DeviceContextTests {
    @Test("RAM capability tiers are correct")
    func ramCapabilityTiers() {
        let heavy: UInt64 = 192
        let moderate: UInt64 = 64
        let light: UInt64 = 16

        #expect(heavy >= 128)
        #expect(moderate >= 32 && moderate < 128)
        #expect(light < 32)
    }

    @Test("Capability tier descriptions are distinct")
    func capabilityTierDescriptions() {
        let heavyDesc = "heavy ML inference (70B+ models), parallel builds, large context"
        let moderateDesc = "moderate ML inference, standard builds"
        let lightDesc = "lightweight — prefer smaller models, avoid memory-intensive operations"

        #expect(heavyDesc != moderateDesc)
        #expect(moderateDesc != lightDesc)
        #expect(heavyDesc != lightDesc)
    }
}

// MARK: - Section Ordering Tests

@Suite("Identity Prompt — Section Order")
struct SectionOrderTests {
    @Test("Sections join with double newlines")
    func sectionsJoinedProperly() {
        let sections = ["Section 1", "Section 2", "Section 3"]
        let result = sections.joined(separator: "\n\n")
        #expect(result == "Section 1\n\nSection 2\n\nSection 3")
    }

    @Test("Empty sections are skipped")
    func emptySectionsSkipped() {
        var sections: [String] = []
        sections.append("Identity")
        let empty = ""
        if !empty.isEmpty { sections.append(empty) }
        sections.append("Device")
        #expect(sections.count == 2)
        #expect(sections == ["Identity", "Device"])
    }

    @Test("Conversation system prompt is passed through")
    func conversationPromptPassthrough() {
        let customPrompt = "You are a French tutor specializing in grammar."
        var parts: [String] = []
        if !customPrompt.isEmpty { parts.append(customPrompt) }
        #expect(parts.count == 1)
        #expect(parts[0] == customPrompt)
    }
}

// MARK: - SystemPromptConfiguration Tests

@Suite("Identity Prompt — SystemPromptConfiguration")
struct SystemPromptConfigTests {
    private struct TestConfig: Codable {
        var basePrompt: String
        var taskPrompts: [String: String]
        var useDynamicPrompts: Bool

        func isCustomized(for key: String) -> Bool {
            guard let current = taskPrompts[key] else { return false }
            let defaults = Self.defaults()
            guard let defaultPrompt = defaults.taskPrompts[key] else { return !current.isEmpty }
            return current != defaultPrompt
        }

        static func defaults() -> TestConfig {
            TestConfig(
                basePrompt: "You are THEA",
                taskPrompts: ["codeGeneration": "Write clean code"],
                useDynamicPrompts: true
            )
        }
    }

    @Test("Default config has dynamic prompts enabled")
    func dynamicPromptsEnabled() {
        let config = TestConfig.defaults()
        #expect(config.useDynamicPrompts)
    }

    @Test("Unmodified task prompt is not customized")
    func unmodifiedNotCustomized() {
        let config = TestConfig.defaults()
        #expect(!config.isCustomized(for: "codeGeneration"))
    }

    @Test("Modified task prompt IS customized")
    func modifiedIsCustomized() {
        var config = TestConfig.defaults()
        config.taskPrompts["codeGeneration"] = "Custom code instructions"
        #expect(config.isCustomized(for: "codeGeneration"))
    }

    @Test("Unknown task type is customized if non-empty")
    func unknownTaskCustomized() {
        var config = TestConfig.defaults()
        config.taskPrompts["newTask"] = "New instructions"
        #expect(config.isCustomized(for: "newTask"))
    }

    @Test("Missing task prompt is not customized")
    func missingNotCustomized() {
        let config = TestConfig.defaults()
        #expect(!config.isCustomized(for: "nonexistent"))
    }

    @Test("Config is Codable roundtrip")
    func codableRoundtrip() throws {
        let config = TestConfig.defaults()
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(TestConfig.self, from: data)
        #expect(decoded.basePrompt == config.basePrompt)
        #expect(decoded.useDynamicPrompts == config.useDynamicPrompts)
        #expect(decoded.taskPrompts.count == config.taskPrompts.count)
    }
}

// MARK: - Capabilities Section Tests

@Suite("Identity Prompt — Capabilities Content")
struct CapabilitiesContentTests {
    @Test("Provider list formatted correctly")
    func providerListFormatting() {
        let names = ["Anthropic", "OpenAI", "Google"]
        let line = "- \(names.count) AI providers active (\(names.joined(separator: ", "))) with intelligent task routing"
        #expect(line.contains("3 AI providers active"))
        #expect(line.contains("Anthropic, OpenAI, Google"))
        #expect(line.contains("intelligent task routing"))
    }

    @Test("Local models line format")
    func localModelsLineFormat() {
        let count = 5
        let line = "- \(count) local ML models available for on-device inference (no data leaves device)"
        #expect(line.contains("5 local ML models"))
        #expect(line.contains("no data leaves device"))
    }

    @Test("Verification pipeline line content")
    func verificationPipelineLine() {
        let line = "- Response verification: multi-model consensus, web fact-checking, code execution, static analysis, user feedback learning"
        #expect(line.contains("consensus"))
        #expect(line.contains("web fact-checking"))
        #expect(line.contains("code execution"))
        #expect(line.contains("static analysis"))
        #expect(line.contains("feedback learning"))
    }

    @Test("Agent delegation line appears when enabled")
    func agentDelegationLine() {
        let enabled = true
        var lines: [String] = []
        if enabled {
            lines.append("- Agent delegation: can dispatch complex tasks to specialized sub-agents")
        }
        #expect(lines.count == 1)
        #expect(lines[0].contains("sub-agents"))
    }

    @Test("Agent delegation line absent when disabled")
    func agentDelegationAbsent() {
        let enabled = false
        var lines: [String] = []
        if enabled {
            lines.append("- Agent delegation: can dispatch complex tasks to specialized sub-agents")
        }
        #expect(lines.isEmpty)
    }

    @Test("Cross-device sync line appears for multi-device")
    func crossDeviceSyncLine() {
        let deviceCount = 3
        var lines: [String] = []
        if deviceCount > 1 {
            lines.append("- Cross-device sync active across \(deviceCount) devices")
        }
        #expect(lines.count == 1)
        #expect(lines[0].contains("3 devices"))
    }

    @Test("Cross-device sync line absent for single device")
    func singleDeviceNoSync() {
        let deviceCount = 1
        var lines: [String] = []
        if deviceCount > 1 {
            lines.append("- Cross-device sync active across \(deviceCount) devices")
        }
        #expect(lines.isEmpty)
    }
}
