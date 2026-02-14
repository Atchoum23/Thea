// FunctionGemmaEngine.swift
// Thea — FunctionGemma Natural Language → Structured Function Calls
//
// Parses natural language instructions into structured function calls
// targeting Thea's AppIntegrationModule system. Fully offline via CoreML.

import Foundation
import OSLog

// MARK: - FunctionGemma Engine

@MainActor
@Observable
final class FunctionGemmaEngine {
    static let shared = FunctionGemmaEngine()

    private let logger = Logger(subsystem: "com.thea.app", category: "FunctionGemma")

    // MARK: - State

    private(set) var isModelLoaded = false
    private(set) var isProcessing = false
    private(set) var lastError: String?

    // MARK: - Configuration

    /// Available function definitions for the model
    private var functionCatalog: [FunctionDefinition] = []

    private init() {
        buildFunctionCatalog()
    }

    // MARK: - Model Loading

    /// Load the FunctionGemma model via CoreML
    func loadModel() async throws {
        guard !isModelLoaded else { return }

        logger.info("Loading FunctionGemma model...")

        let engine = CoreMLInferenceEngine.shared
        let models = engine.discoverLLMModels()

        // Look for a FunctionGemma or function-calling model
        let functionModel = models.first { model in
            let name = model.name.lowercased()
            return name.contains("functiongemma") ||
                name.contains("function-gemma") ||
                name.contains("function_call")
        }

        if let model = functionModel {
            try await engine.loadModel(at: model.path, id: model.id)
            isModelLoaded = true
            logger.info("FunctionGemma model loaded: \(model.name)")
        } else {
            // Fall back to rule-based parsing if no CoreML model available
            logger.info("No FunctionGemma CoreML model found — using rule-based parser")
            isModelLoaded = true
        }
    }

    // MARK: - Function Call Parsing

    /// Parse a natural language instruction into a structured function call
    func parse(_ instruction: String) async throws -> FunctionCall? {
        isProcessing = true
        defer { isProcessing = false }

        // Try CoreML model first
        if let coreMLResult = try await parseWithCoreML(instruction) {
            return coreMLResult
        }

        // Fall back to rule-based parsing
        return parseWithRules(instruction)
    }

    /// Parse multiple instructions (e.g., "Create a reminder and then open Safari")
    func parseMultiple(_ instruction: String) async throws -> [FunctionCall] {
        isProcessing = true
        defer { isProcessing = false }

        // Split on conjunctions
        let parts = splitInstruction(instruction)
        var calls: [FunctionCall] = []

        for part in parts {
            if let call = try await parse(part.trimmingCharacters(in: .whitespaces)) {
                calls.append(call)
            }
        }

        return calls
    }

    // MARK: - CoreML Parsing

    private func parseWithCoreML(_ instruction: String) async throws -> FunctionCall? {
        let engine = CoreMLInferenceEngine.shared
        guard engine.loadedModelID != nil else { return nil }

        // Build prompt with function catalog
        let prompt = buildFunctionCallingPrompt(instruction: instruction)

        let stream = try await engine.generate(prompt: prompt, maxTokens: 256)
        var result = ""
        for try await chunk in stream {
            result += chunk
        }

        return parseFunctionCallFromOutput(result)
    }

    // MARK: - Rule-Based Parsing

    private func parseWithRules(_ instruction: String) -> FunctionCall? {
        let lower = instruction.lowercased().trimmingCharacters(in: .whitespaces)

        // Calendar operations
        if let call = parseCalendarIntent(lower, original: instruction) {
            return call
        }

        // Reminder operations
        if let call = parseReminderIntent(lower, original: instruction) {
            return call
        }

        // Safari operations
        if let call = parseSafariIntent(lower, original: instruction) {
            return call
        }

        // Finder operations
        if let call = parseFinderIntent(lower, original: instruction) {
            return call
        }

        // Terminal operations
        if let call = parseTerminalIntent(lower, original: instruction) {
            return call
        }

        // Music operations
        if let call = parseMusicIntent(lower, original: instruction) {
            return call
        }

        // System operations
        if let call = parseSystemIntent(lower, original: instruction) {
            return call
        }

        // Mail operations
        if let call = parseMailIntent(lower, original: instruction) {
            return call
        }

        // Shortcuts operations
        if let call = parseShortcutsIntent(lower, original: instruction) {
            return call
        }

        return nil
    }

}

// MARK: - Intent Parsing

extension FunctionGemmaEngine {
    func parseCalendarIntent(_ lower: String, original: String) -> FunctionCall? {
        let calendarTriggers = ["calendar", "event", "meeting", "appointment", "schedule"]
        guard calendarTriggers.contains(where: { lower.contains($0) }) else { return nil }

        if lower.contains("create") || lower.contains("add") || lower.contains("schedule") || lower.contains("new") {
            let title = extractQuotedOrAfter(original, keywords: ["called", "titled", "named", "for"])
                ?? extractAfter(original, keyword: "event")
                ?? "New Event"

            var args: [String: String] = ["title": title]
            if let time = extractTimeExpression(lower) { args["time"] = time }

            return FunctionCall(
                module: "calendar", function: "createEvent",
                arguments: args, confidence: 0.8, originalInstruction: original
            )
        }

        if lower.contains("show") || lower.contains("list") || lower.contains("what") || lower.contains("get") {
            if lower.contains("today") {
                return FunctionCall(
                    module: "calendar", function: "getTodayEvents",
                    arguments: [:], confidence: 0.9, originalInstruction: original
                )
            }
            return FunctionCall(
                module: "calendar", function: "getEvents",
                arguments: [:], confidence: 0.7, originalInstruction: original
            )
        }

        return nil
    }

    func parseReminderIntent(_ lower: String, original: String) -> FunctionCall? {
        let triggers = ["reminder", "remind", "todo", "to-do", "task"]
        guard triggers.contains(where: { lower.contains($0) }) else { return nil }

        if lower.contains("create") || lower.contains("add") || lower.contains("set") || lower.contains("new") || lower.contains("remind me") {
            let title = extractQuotedOrAfter(original, keywords: ["to", "about", "called", "titled"])
                ?? extractAfter(original, keyword: "reminder")
                ?? "New Reminder"

            var args: [String: String] = ["title": title]
            if let time = extractTimeExpression(lower) { args["dueDate"] = time }

            return FunctionCall(
                module: "reminders", function: "createReminder",
                arguments: args, confidence: 0.85, originalInstruction: original
            )
        }

        if lower.contains("show") || lower.contains("list") || lower.contains("get") {
            return FunctionCall(
                module: "reminders", function: "fetchReminders",
                arguments: [:], confidence: 0.8, originalInstruction: original
            )
        }

        return nil
    }

    func parseSafariIntent(_ lower: String, original: String) -> FunctionCall? {
        let triggers = ["safari", "browse", "website", "web page", "open url", "search for", "search the web"]
        guard triggers.contains(where: { lower.contains($0) }) else { return nil }

        if lower.contains("open") || lower.contains("navigate") || lower.contains("go to") {
            if let url = extractURL(original) {
                return FunctionCall(
                    module: "safari", function: "navigateTo",
                    arguments: ["url": url], confidence: 0.9, originalInstruction: original
                )
            }
        }

        if lower.contains("search") {
            let query = extractQuotedOrAfter(original, keywords: ["search for", "search", "look up"]) ?? "query"
            return FunctionCall(
                module: "safari", function: "navigateTo",
                arguments: ["url": "https://www.google.com/search?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)"],
                confidence: 0.8, originalInstruction: original
            )
        }

        return nil
    }

    func parseFinderIntent(_ lower: String, original: String) -> FunctionCall? {
        let triggers = ["finder", "folder", "file", "directory"]
        guard triggers.contains(where: { lower.contains($0) }) else { return nil }

        if lower.contains("open") || lower.contains("show") || lower.contains("reveal") {
            return FunctionCall(
                module: "finder", function: "getSelectedFiles",
                arguments: [:], confidence: 0.7, originalInstruction: original
            )
        }

        return nil
    }

    func parseTerminalIntent(_ lower: String, original: String) -> FunctionCall? {
        let triggers = ["terminal", "command line", "shell", "run command", "execute"]
        guard triggers.contains(where: { lower.contains($0) }) else { return nil }

        if lower.contains("run") || lower.contains("execute") || lower.contains("open terminal") {
            let command = extractQuotedOrAfter(original, keywords: ["run", "execute"]) ?? ""
            return FunctionCall(
                module: "terminal", function: "executeCommand",
                arguments: ["command": command], confidence: command.isEmpty ? 0.5 : 0.8,
                originalInstruction: original
            )
        }

        return nil
    }

    func parseMusicIntent(_ lower: String, original: String) -> FunctionCall? {
        let triggers = ["music", "song", "play", "pause", "skip", "volume"]
        guard triggers.contains(where: { lower.contains($0) }) else { return nil }

        if lower.contains("play") {
            return FunctionCall(module: "music", function: "play", arguments: [:], confidence: 0.8, originalInstruction: original)
        }
        if lower.contains("pause") || lower.contains("stop") {
            return FunctionCall(module: "music", function: "pause", arguments: [:], confidence: 0.85, originalInstruction: original)
        }
        if lower.contains("skip") || lower.contains("next") {
            return FunctionCall(module: "music", function: "nextTrack", arguments: [:], confidence: 0.85, originalInstruction: original)
        }

        return nil
    }

    func parseSystemIntent(_ lower: String, original: String) -> FunctionCall? {
        let triggers = ["system", "brightness", "volume", "dark mode", "sleep", "lock"]
        guard triggers.contains(where: { lower.contains($0) }) else { return nil }

        if lower.contains("dark mode") {
            let enable = lower.contains("enable") || lower.contains("turn on") || lower.contains("activate")
            return FunctionCall(
                module: "system", function: "setDarkMode",
                arguments: ["enabled": enable ? "true" : "false"], confidence: 0.9, originalInstruction: original
            )
        }
        if lower.contains("lock") {
            return FunctionCall(module: "system", function: "lockScreen", arguments: [:], confidence: 0.9, originalInstruction: original)
        }
        if lower.contains("sleep") {
            return FunctionCall(module: "system", function: "sleep", arguments: [:], confidence: 0.85, originalInstruction: original)
        }

        return nil
    }

    func parseMailIntent(_ lower: String, original: String) -> FunctionCall? {
        let triggers = ["email", "mail", "send an email", "compose"]
        guard triggers.contains(where: { lower.contains($0) }) else { return nil }

        if lower.contains("send") || lower.contains("compose") || lower.contains("write") {
            let recipient = extractAfter(original, keyword: "to") ?? ""
            let subject = extractQuotedOrAfter(original, keywords: ["about", "subject", "regarding"]) ?? ""
            return FunctionCall(
                module: "mail", function: "composeEmail",
                arguments: ["to": recipient, "subject": subject], confidence: 0.7, originalInstruction: original
            )
        }

        return nil
    }

    func parseShortcutsIntent(_ lower: String, original: String) -> FunctionCall? {
        let triggers = ["shortcut", "automation", "run shortcut"]
        guard triggers.contains(where: { lower.contains($0) }) else { return nil }

        if lower.contains("run") {
            let name = extractQuotedOrAfter(original, keywords: ["run", "shortcut", "called", "named"]) ?? ""
            return FunctionCall(
                module: "shortcuts", function: "runShortcut",
                arguments: ["name": name], confidence: name.isEmpty ? 0.4 : 0.85, originalInstruction: original
            )
        }

        return nil
    }
}

// MARK: - Text Extraction & Prompt Helpers

extension FunctionGemmaEngine {
    func extractQuotedOrAfter(_ text: String, keywords: [String]) -> String? {
        if let range = text.range(of: "\"[^\"]+\"", options: .regularExpression) {
            let quoted = text[range]
            return String(quoted.dropFirst().dropLast())
        }
        if let range = text.range(of: "'[^']+'", options: .regularExpression) {
            let quoted = text[range]
            return String(quoted.dropFirst().dropLast())
        }

        for keyword in keywords {
            if let result = extractAfter(text, keyword: keyword) {
                return result
            }
        }

        return nil
    }

    func extractAfter(_ text: String, keyword: String) -> String? {
        guard let range = text.lowercased().range(of: keyword) else { return nil }
        let after = text[range.upperBound...].trimmingCharacters(in: .whitespaces)
        guard !after.isEmpty else { return nil }
        let stopWords = [" and ", " then ", " but ", " or ", ".", ",", ";"]
        var result = after
        for stop in stopWords {
            if let stopRange = result.lowercased().range(of: stop) {
                result = String(result[..<stopRange.lowerBound])
            }
        }
        return result.trimmingCharacters(in: .whitespaces)
    }

    func extractURL(_ text: String) -> String? {
        let pattern = "https?://[^\\s]+"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        if let match = regex.firstMatch(in: text, range: range),
           let swiftRange = Range(match.range, in: text)
        {
            return String(text[swiftRange])
        }
        return nil
    }

    func extractTimeExpression(_ text: String) -> String? {
        let patterns = [
            "tomorrow", "today", "tonight",
            "in \\d+ (?:hour|minute|day|week)s?",
            "at \\d{1,2}(?::\\d{2})?\\s*(?:am|pm)?",
            "next (?:monday|tuesday|wednesday|thursday|friday|saturday|sunday)"
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..<text.endIndex, in: text)),
               let range = Range(match.range, in: text)
            {
                return String(text[range])
            }
        }

        return nil
    }

    func splitInstruction(_ text: String) -> [String] {
        let separators = [" and then ", " then ", " and also ", ", and "]
        var parts = [text]

        for separator in separators {
            var newParts: [String] = []
            for part in parts {
                newParts.append(contentsOf: part.components(separatedBy: separator))
            }
            parts = newParts
        }

        return parts.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    func parseFunctionCallFromOutput(_ output: String) -> FunctionCall? {
        guard let data = output.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let module = json["module"] as? String,
              let function = json["function"] as? String
        else { return nil }

        let arguments = (json["arguments"] as? [String: String]) ?? [:]
        let confidence = json["confidence"] as? Double ?? 0.7

        return FunctionCall(
            module: module, function: function,
            arguments: arguments, confidence: confidence, originalInstruction: ""
        )
    }

    func buildFunctionCallingPrompt(instruction: String) -> String {
        var prompt = "You are a function-calling assistant. Parse the user instruction into a function call.\n\n"
        prompt += "Available functions:\n"

        for def in functionCatalog {
            prompt += "- \(def.module).\(def.name): \(def.description)\n"
            if !def.parameters.isEmpty {
                prompt += "  Parameters: \(def.parameters.map { "\($0.name) (\($0.type))" }.joined(separator: ", "))\n"
            }
        }

        prompt += "\nInstruction: \(instruction)\n"
        prompt += "Output JSON: "

        return prompt
    }

    func buildFunctionCatalog() {
        functionCatalog = [
            FunctionDefinition(module: "calendar", name: "createEvent", description: "Create a calendar event", parameters: [
                .init(name: "title", type: "string", required: true),
                .init(name: "time", type: "string", required: false)
            ]),
            FunctionDefinition(module: "calendar", name: "getTodayEvents", description: "Get today's calendar events", parameters: []),
            FunctionDefinition(module: "calendar", name: "getEvents", description: "Get calendar events", parameters: []),
            FunctionDefinition(module: "reminders", name: "createReminder", description: "Create a reminder", parameters: [
                .init(name: "title", type: "string", required: true),
                .init(name: "dueDate", type: "string", required: false)
            ]),
            FunctionDefinition(module: "reminders", name: "fetchReminders", description: "List reminders", parameters: []),
            FunctionDefinition(module: "safari", name: "navigateTo", description: "Open URL in Safari", parameters: [
                .init(name: "url", type: "string", required: true)
            ]),
            FunctionDefinition(module: "terminal", name: "executeCommand", description: "Execute a shell command", parameters: [
                .init(name: "command", type: "string", required: true)
            ]),
            FunctionDefinition(module: "music", name: "play", description: "Play music", parameters: []),
            FunctionDefinition(module: "music", name: "pause", description: "Pause music", parameters: []),
            FunctionDefinition(module: "music", name: "nextTrack", description: "Skip to next track", parameters: []),
            FunctionDefinition(module: "system", name: "setDarkMode", description: "Toggle dark mode", parameters: [
                .init(name: "enabled", type: "boolean", required: true)
            ]),
            FunctionDefinition(module: "system", name: "lockScreen", description: "Lock the screen", parameters: []),
            FunctionDefinition(module: "mail", name: "composeEmail", description: "Compose an email", parameters: [
                .init(name: "to", type: "string", required: true),
                .init(name: "subject", type: "string", required: false)
            ]),
            FunctionDefinition(module: "shortcuts", name: "runShortcut", description: "Run a Shortcuts automation", parameters: [
                .init(name: "name", type: "string", required: true)
            ])
        ]
    }
}

// MARK: - Types

struct FunctionCall: Sendable {
    let module: String
    let function: String
    let arguments: [String: String]
    let confidence: Double
    let originalInstruction: String
}

struct FunctionDefinition: Sendable {
    let module: String
    let name: String
    let description: String
    let parameters: [ParameterDef]

    struct ParameterDef: Sendable {
        let name: String
        let type: String
        let required: Bool
    }
}
