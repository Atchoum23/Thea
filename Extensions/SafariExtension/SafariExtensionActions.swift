//
//  SafariExtensionActions.swift
//  TheaSafariExtension
//
//  New action handlers for the Safari Web Extension:
//  askAI, deepResearch, searchMemory, credentials, passwords,
//  passkeys, recentSaves, rewriteText, analyzeWritingStyle.
//

import Foundation
import os.log

// MARK: - New Action Handlers

extension SafariWebExtensionHandler {

    // MARK: askAI

    func handleAskAI(
        _ message: [String: Any],
        completion: @escaping ([String: Any]) -> Void
    ) {
        let question = message["question"] as? String ?? ""
        let context = message["context"] as? String ?? ""
        let model = message["model"] as? String
        let conversationId = message["conversationId"] as? String ?? UUID().uuidString

        guard !question.isEmpty else {
            completion(["error": "No question provided"])
            return
        }

        try? saveRequest([
            "type": "askAI",
            "question": question,
            "context": String(context.prefix(10000)),
            "model": model as Any,
            "conversationId": conversationId,
            "timestamp": Date().timeIntervalSince1970
        ])

        notifyMainApp("AskAI")

        completion([
            "success": true,
            "message": "AI query sent to Thea. Open the app for the response.",
            "conversationId": conversationId
        ])
    }

    // MARK: deepResearch

    func handleDeepResearch(
        _ message: [String: Any],
        completion: @escaping ([String: Any]) -> Void
    ) {
        let query = message["query"] as? String ?? ""
        let sources = message["sources"] as? [String] ?? []

        guard !query.isEmpty else {
            completion(["error": "No research query provided"])
            return
        }

        try? saveRequest([
            "type": "deepResearch",
            "query": query,
            "sources": sources,
            "timestamp": Date().timeIntervalSince1970
        ])

        notifyMainApp("DeepResearch")

        completion([
            "success": true,
            "message": "Research request queued. Open Thea for results."
        ])
    }

    // MARK: searchMemory

    func handleSearchMemory(
        _ message: [String: Any],
        completion: @escaping ([String: Any]) -> Void
    ) {
        let query = message["query"] as? String ?? ""
        let limit = message["limit"] as? Int ?? 10

        guard !query.isEmpty else {
            completion(["error": "No search query provided"])
            return
        }

        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) else {
            completion(["success": true, "results": [], "count": 0])
            return
        }

        let memoryDir = containerURL.appendingPathComponent("MemoryStore", isDirectory: true)
        var results: [[String: Any]] = []

        let queryTerms = query.lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }

        guard !queryTerms.isEmpty else {
            completion(["success": true, "results": [], "count": 0])
            return
        }

        if let files = try? FileManager.default.contentsOfDirectory(
            at: memoryDir,
            includingPropertiesForKeys: [.contentModificationDateKey]
        ) {
            let sortedFiles = files
                .filter { $0.pathExtension == "json" }
                .sorted { lhs, rhs in
                    let lhsDate = (try? lhs.resourceValues(
                        forKeys: Set<URLResourceKey>([.contentModificationDateKey])
                    ))?.contentModificationDate ?? .distantPast
                    let rhsDate = (try? rhs.resourceValues(
                        forKeys: Set<URLResourceKey>([.contentModificationDateKey])
                    ))?.contentModificationDate ?? .distantPast
                    return lhsDate > rhsDate
                }

            for file in sortedFiles {
                guard results.count < limit else { break }

                if let data = try? Data(contentsOf: file),
                   let entry = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                {
                    let content = (entry["content"] as? String ?? "").lowercased()
                    let title = (entry["title"] as? String ?? "").lowercased()
                    let searchable = content + " " + title

                    let matches = queryTerms.filter { searchable.contains($0) }
                    if !matches.isEmpty {
                        var result = entry
                        result["relevance"] = Double(matches.count) / Double(queryTerms.count)
                        results.append(result)
                    }
                }
            }
        }

        results.sort { ($0["relevance"] as? Double ?? 0) > ($1["relevance"] as? Double ?? 0) }
        completion(["success": true, "results": results, "count": results.count])
    }

    // MARK: getCredentials

    func handleGetCredentials(
        _ message: [String: Any],
        completion: @escaping ([String: Any]) -> Void
    ) {
        let domain = message["domain"] as? String ?? ""

        guard !domain.isEmpty else {
            completion(["error": "No domain provided"])
            return
        }

        let credentials = KeychainHelper.queryCredentials(domain: domain)
        completion(["success": true, "credentials": credentials])
    }

    // MARK: saveCredential

    func handleSaveCredential(
        _ message: [String: Any],
        completion: @escaping ([String: Any]) -> Void
    ) {
        let domain = message["domain"] as? String ?? ""
        let username = message["username"] as? String ?? ""
        let password = message["password"] as? String ?? ""

        guard !domain.isEmpty, !username.isEmpty, !password.isEmpty else {
            completion(["error": "Missing domain, username, or password"])
            return
        }

        let saved = KeychainHelper.saveCredential(
            domain: domain, username: username, password: password
        )

        if saved {
            completion(["success": true, "message": "Credential saved"])
        } else {
            completion(["success": false, "error": "Failed to save credential"])
        }
    }

    // MARK: generatePassword

    func handleGeneratePassword(
        completion: @escaping ([String: Any]) -> Void
    ) {
        let password = PasswordGenerator.generateStrongPassword()
        completion(["success": true, "password": password])
    }

    // MARK: getTOTPSecret

    func handleGetTOTPSecret(
        _ message: [String: Any],
        completion: @escaping ([String: Any]) -> Void
    ) {
        let domain = message["domain"] as? String ?? ""

        guard !domain.isEmpty else {
            completion(["error": "No domain provided"])
            return
        }

        if let secret = KeychainHelper.getTOTPSecret(domain: domain) {
            completion(["success": true, "secret": secret])
        } else {
            completion(["success": false, "error": "No TOTP secret found for \(domain)"])
        }
    }

    // MARK: registerPasskey

    func handleRegisterPasskey(
        _ message: [String: Any],
        completion: @escaping ([String: Any]) -> Void
    ) {
        let domain = message["domain"] as? String ?? ""
        let challenge = message["challenge"] as? String ?? ""
        let rpId = message["rpId"] as? String ?? ""

        logger.info("Passkey registration requested for \(domain)")

        // Stub: full ASAuthorization integration requires main app context
        completion([
            "success": false,
            "status": "pending",
            "message": "Passkey registration requires Thea main app. Open Thea to complete.",
            "domain": domain,
            "challenge": challenge,
            "rpId": rpId
        ])
    }

    // MARK: authenticatePasskey

    func handleAuthenticatePasskey(
        _ message: [String: Any],
        completion: @escaping ([String: Any]) -> Void
    ) {
        let domain = message["domain"] as? String ?? ""
        let challenge = message["challenge"] as? String ?? ""
        let rpId = message["rpId"] as? String ?? ""

        logger.info("Passkey authentication requested for \(domain)")

        // Stub: full ASAuthorization integration requires main app context
        completion([
            "success": false,
            "status": "pending",
            "message": "Passkey authentication requires Thea main app. Open Thea to complete.",
            "domain": domain,
            "challenge": challenge,
            "rpId": rpId
        ])
    }

    // MARK: getRecentSaves

    func handleGetRecentSaves(
        completion: @escaping ([String: Any]) -> Void
    ) {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) else {
            completion(["success": true, "items": [], "count": 0])
            return
        }

        let savedDir = containerURL.appendingPathComponent("SavedItems", isDirectory: true)
        var items: [[String: Any]] = []

        if let files = try? FileManager.default.contentsOfDirectory(
            at: savedDir,
            includingPropertiesForKeys: [.contentModificationDateKey]
        ) {
            let recentFiles = files
                .filter { $0.pathExtension == "json" }
                .sorted { lhs, rhs in
                    let lhsDate = (try? lhs.resourceValues(
                        forKeys: Set<URLResourceKey>([.contentModificationDateKey])
                    ))?.contentModificationDate ?? .distantPast
                    let rhsDate = (try? rhs.resourceValues(
                        forKeys: Set<URLResourceKey>([.contentModificationDateKey])
                    ))?.contentModificationDate ?? .distantPast
                    return lhsDate > rhsDate
                }
                .prefix(20)

            for file in recentFiles {
                if let data = try? Data(contentsOf: file),
                   let item = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                {
                    items.append(item)
                }
            }
        }

        completion(["success": true, "items": items, "count": items.count])
    }

    // MARK: rewriteText

    func handleRewriteText(
        _ message: [String: Any],
        completion: @escaping ([String: Any]) -> Void
    ) {
        let text = message["text"] as? String ?? ""
        let style = message["style"] as? String ?? "neutral"
        let tone = message["tone"] as? String ?? "professional"

        guard !text.isEmpty else {
            completion(["error": "No text provided"])
            return
        }

        try? saveRequest([
            "type": "rewriteText",
            "text": String(text.prefix(10000)),
            "style": style,
            "tone": tone,
            "timestamp": Date().timeIntervalSince1970
        ])

        notifyMainApp("RewriteText")

        completion([
            "success": true,
            "message": "Rewrite request queued. Open Thea for results.",
            "style": style,
            "tone": tone
        ])
    }

    // MARK: analyzeWritingStyle

    func handleAnalyzeWritingStyle(
        _ message: [String: Any],
        completion: @escaping ([String: Any]) -> Void
    ) {
        let text = message["text"] as? String ?? ""

        guard !text.isEmpty else {
            completion(["error": "No text provided"])
            return
        }

        let analysis = TextAnalyzer.analyzeStyle(text)
        completion([
            "success": true,
            "analysis": analysis.asDictionary
        ])
    }
}
