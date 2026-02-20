// WebToolHandler.swift
// Thea
//
// Tool handler for web search and URL fetching (B3)

import Foundation
import os.log

private let logger = Logger(subsystem: "ai.thea.app", category: "WebToolHandler")

@MainActor
enum WebToolHandler {

    // MARK: - web_search

    static func search(_ input: [String: Any]) async -> AnthropicToolResult {
        let id = input["_tool_use_id"] as? String ?? ""
        let query = input["query"] as? String ?? ""
        guard !query.isEmpty else {
            return AnthropicToolResult(toolUseId: id, content: "No query provided.", isError: true)
        }
        logger.debug("web_search: '\(query)'")
        // Use WebSearchVerifier to gather verified claims for the query
        let verifier = WebSearchVerifier()
        let result = await verifier.verify(response: query, query: query)
        let confirmedClaims = result.verifiedClaims.filter { $0.confirmed }
        if confirmedClaims.isEmpty && result.unverifiedClaims.isEmpty {
            return AnthropicToolResult(toolUseId: id, content: "No web results found for '\(query)'.")
        }
        let lines = confirmedClaims.prefix(5).map { claim in
            let src = claim.source.map { " — \($0)" } ?? ""
            return "• \(claim.claim)\(src)"
        }
        let text = lines.joined(separator: "\n")
        return AnthropicToolResult(toolUseId: id, content: text.isEmpty ? "No confirmed results for '\(query)'." : text)
    }

    // MARK: - fetch_url

    static func fetchURL(_ input: [String: Any]) async -> AnthropicToolResult {
        let id = input["_tool_use_id"] as? String ?? ""
        let urlString = input["url"] as? String ?? ""
        guard !urlString.isEmpty, let url = URL(string: urlString) else {
            return AnthropicToolResult(toolUseId: id, content: "Invalid URL: '\(urlString)'", isError: true)
        }
        // Only allow HTTPS URLs for security
        guard url.scheme == "https" else {
            return AnthropicToolResult(toolUseId: id, content: "Only HTTPS URLs are supported.", isError: true)
        }
        logger.debug("fetch_url: '\(urlString)'")
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard statusCode == 200 else {
                return AnthropicToolResult(toolUseId: id, content: "HTTP \(statusCode) from \(urlString)", isError: true)
            }
            let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) ?? ""
            // Strip HTML tags minimally and truncate
            let stripped = stripBasicHTML(text)
            let truncated = stripped.count > 6000 ? String(stripped.prefix(6000)) + "\n[…truncated]" : stripped
            return AnthropicToolResult(toolUseId: id, content: truncated)
        } catch {
            return AnthropicToolResult(toolUseId: id, content: "Fetch failed: \(error.localizedDescription)", isError: true)
        }
    }

    // MARK: - Helpers

    private static func stripBasicHTML(_ html: String) -> String {
        // Remove script/style blocks
        var result = html
        for tag in ["<script[^>]*>[\\s\\S]*?</script>", "<style[^>]*>[\\s\\S]*?</style>"] {
            if let regex = try? NSRegularExpression(pattern: tag, options: .caseInsensitive) {
                let range = NSRange(result.startIndex..., in: result)
                result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "")
            }
        }
        // Remove remaining HTML tags
        if let regex = try? NSRegularExpression(pattern: "<[^>]+>", options: []) {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: " ")
        }
        // Decode common HTML entities
        result = result
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&nbsp;", with: " ")
        // Collapse whitespace
        let lines = result.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return lines.joined(separator: "\n")
    }
}
