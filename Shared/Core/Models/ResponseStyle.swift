// ResponseStyle.swift
// Thea — Named response-style presets that append instructions to the system prompt.

import Foundation

// MARK: - ResponseStyle

/// A named preset that appends style instructions to the system prompt for every message.
/// Built-in styles cannot be deleted; custom styles are stored in SettingsManager.
struct ResponseStyle: Identifiable, Codable, Hashable {
    let id: String          // Stable UUID string used as persistence key
    var name: String
    var description: String
    var systemPromptSuffix: String
    var isBuiltIn: Bool

    // MARK: - Built-in Styles

    static let builtInStyles: [ResponseStyle] = [
        ResponseStyle(
            id: "builtin.concise",
            name: "Concise",
            description: "Short, to-the-point answers. Skips preamble and filler.",
            systemPromptSuffix: "RESPONSE STYLE: Be extremely concise. Provide the shortest accurate answer. " +
                "Skip preamble, filler phrases, and unnecessary context. " +
                "Prefer bullet points over paragraphs when listing items.",
            isBuiltIn: true
        ),
        ResponseStyle(
            id: "builtin.detailed",
            name: "Detailed",
            description: "Thorough explanations with context and examples.",
            systemPromptSuffix: "RESPONSE STYLE: Provide thorough, detailed explanations. " +
                "Include context, reasoning, edge cases, and practical examples. " +
                "Err on the side of more information rather than less.",
            isBuiltIn: true
        ),
        ResponseStyle(
            id: "builtin.formal",
            name: "Formal",
            description: "Professional tone suitable for business communication.",
            systemPromptSuffix: "RESPONSE STYLE: Use a formal, professional tone. " +
                "Avoid contractions, slang, and casual language. " +
                "Structure responses with clear headings and well-formed paragraphs.",
            isBuiltIn: true
        ),
        ResponseStyle(
            id: "builtin.casual",
            name: "Casual",
            description: "Friendly, conversational tone like chatting with a colleague.",
            systemPromptSuffix: "RESPONSE STYLE: Use a friendly, casual conversational tone. " +
                "Contractions, informal language, and relatable analogies are encouraged. " +
                "Be warm and approachable.",
            isBuiltIn: true
        ),
        ResponseStyle(
            id: "builtin.technical",
            name: "Technical",
            description: "Deep technical detail; assumes expert-level knowledge.",
            systemPromptSuffix: "RESPONSE STYLE: Use precise technical language and domain-specific terminology. " +
                "Assume the reader has expert-level knowledge. " +
                "Include implementation details, edge cases, performance considerations, and references to specifications or standards where relevant.",
            isBuiltIn: true
        ),
        ResponseStyle(
            id: "builtin.creative",
            name: "Creative",
            description: "Imaginative and expressive; ideal for brainstorming and writing.",
            systemPromptSuffix: "RESPONSE STYLE: Be imaginative, expressive, and exploratory. " +
                "Offer multiple perspectives or variations. " +
                "Use vivid language and creative framing. " +
                "Avoid overly structured or formulaic responses.",
            isBuiltIn: true
        ),
    ]
}
