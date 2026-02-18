//
//  SafariWebExtensionHandler.swift
//  TheaSafariExtension
//
//  Created by Thea
//

import os.log
import SafariServices

/// Safari Web Extension Handler for Thea
/// Bridges JavaScript messages to native code for enhanced web intelligence
class SafariWebExtensionHandler: NSObject, NSExtensionRequestHandling {
    let logger = Logger(subsystem: "app.thea.safari", category: "ExtensionHandler")
    let appGroupID = "group.app.theathe"

    func beginRequest(with context: NSExtensionContext) {
        let request = context.inputItems.first as? NSExtensionItem

        let profile: UUID? = if #available(iOS 17.0, macOS 14.0, *) {
            request?.userInfo?[SFExtensionProfileKey] as? UUID
        } else {
            nil
        }

        let message: Any? = if #available(iOS 15.0, macOS 11.0, *) {
            request?.userInfo?[SFExtensionMessageKey]
        } else {
            nil
        }

        logger.info("Received message from browser: \(String(describing: message), privacy: .public)")

        // Process the message
        if let messageDict = message as? [String: Any] {
            processMessage(messageDict, profile: profile) { response in
                let responseItem = NSExtensionItem()
                if #available(iOS 15.0, macOS 11.0, *) {
                    responseItem.userInfo = [SFExtensionMessageKey: response]
                }
                context.completeRequest(returningItems: [responseItem])
            }
        } else {
            context.completeRequest(returningItems: nil)
        }
    }

    private func processMessage(_ message: [String: Any], profile _: UUID?, completion: @escaping ([String: Any]) -> Void) {
        guard let action = message["action"] as? String else {
            completion(["error": "No action specified"])
            return
        }

        switch action {
        case "getPageContext":
            // Get context for current page
            let pageData = message["pageData"] as? [String: Any] ?? [:]
            handleGetPageContext(pageData, completion: completion)

        case "analyzeContent":
            // Analyze page content with AI
            let content = message["content"] as? String ?? ""
            handleAnalyzeContent(content, completion: completion)

        case "saveToMemory":
            // Save information to Thea's memory
            let data = message["data"] as? [String: Any] ?? [:]
            handleSaveToMemory(data, completion: completion)

        case "getQuickActions":
            // Get available quick actions for this page
            let url = message["url"] as? String ?? ""
            handleGetQuickActions(url, completion: completion)

        case "executeAction":
            // Execute a quick action
            let actionId = message["actionId"] as? String ?? ""
            let params = message["params"] as? [String: Any] ?? [:]
            handleExecuteAction(actionId, params: params, completion: completion)

        case "trackBrowsing":
            // Track browsing activity (privacy-conscious)
            let urlString = message["url"] as? String ?? ""
            let title = message["title"] as? String ?? ""
            handleTrackBrowsing(url: urlString, title: title, completion: completion)

        case "suggestAutofill":
            // Suggest autofill for forms
            let formFields = message["fields"] as? [[String: Any]] ?? []
            handleSuggestAutofill(formFields, completion: completion)

        case "askAI":
            handleAskAI(message, completion: completion)

        case "deepResearch":
            handleDeepResearch(message, completion: completion)

        case "getCredentials":
            handleGetCredentials(message, completion: completion)

        case "saveCredential":
            handleSaveCredential(message, completion: completion)

        case "generatePassword":
            handleGeneratePassword(completion: completion)

        case "getTOTPSecret":
            handleGetTOTPSecret(message, completion: completion)

        case "rewriteText":
            handleRewriteText(message, completion: completion)

        case "analyzeWritingStyle":
            handleAnalyzeWritingStyle(message, completion: completion)

        case "searchMemory":
            handleSearchMemory(message, completion: completion)

        case "ping":
            // Connection health check
            completion(["success": true, "status": "connected", "version": "1.0"])

        default:
            completion(["error": "Unknown action: \(action)"])
        }
    }

    // MARK: - Action Handlers

    private func handleGetPageContext(_ pageData: [String: Any], completion: @escaping ([String: Any]) -> Void) {
        // Return context-aware suggestions based on page
        var response: [String: Any] = [
            "success": true,
            "suggestions": [
                ["icon": "bookmark", "title": "Save to Memory", "action": "saveToMemory"],
                ["icon": "text.quote", "title": "Summarize Page", "action": "analyzeContent"],
                ["icon": "translate", "title": "Translate", "action": "translate"]
            ]
        ]

        // Add page-specific actions
        if let url = pageData["url"] as? String {
            if url.contains("github.com") {
                response["suggestions"] = [
                    ["icon": "doc.text", "title": "Explain Code", "action": "explainCode"],
                    ["icon": "star", "title": "Track Repository", "action": "trackRepo"]
                ]
            } else if url.contains("youtube.com") || url.contains("vimeo.com") {
                response["suggestions"] = [
                    ["icon": "text.quote", "title": "Transcribe Video", "action": "transcribe"],
                    ["icon": "bookmark", "title": "Save Timestamp", "action": "saveTimestamp"]
                ]
            }
        }

        completion(response)
    }

    private func handleAnalyzeContent(_ content: String, completion: @escaping ([String: Any]) -> Void) {
        // Save analysis request for main app
        do {
            try saveRequest([
                "type": "analyze",
                "content": String(content.prefix(10000)), // Limit content size
                "timestamp": Date().timeIntervalSince1970
            ])
        } catch {
            logger.error("Failed to save analyze request: \(error)")
            completion(["error": "Failed to queue analysis: \(error.localizedDescription)"])
            return
        }

        // Return quick response - full analysis via main app
        completion([
            "success": true,
            "message": "Analysis queued. Open Thea for full results.",
            "quickSummary": generateQuickSummary(content)
        ])
    }

    private func handleSaveToMemory(_ data: [String: Any], completion: @escaping ([String: Any]) -> Void) {
        do {
            try saveRequest([
                "type": "memory",
                "data": data,
                "timestamp": Date().timeIntervalSince1970
            ])
        } catch {
            logger.error("Failed to save memory request: \(error)")
            completion(["error": "Failed to save to memory: \(error.localizedDescription)"])
            return
        }

        // Notify main app via Darwin notification
        notifyMainApp("SavedToMemory")

        completion([
            "success": true,
            "message": "Saved to Thea's memory"
        ])
    }

    private func handleGetQuickActions(_: String, completion: @escaping ([String: Any]) -> Void) {
        // Load custom actions from main app
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            let actionsPath = containerURL.appendingPathComponent("safari_actions.json")
            if let data = try? Data(contentsOf: actionsPath),
               let actions = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
            {
                completion(["success": true, "actions": actions])
                return
            }
        }

        // Default actions
        completion([
            "success": true,
            "actions": [
                ["id": "summarize", "title": "Summarize", "icon": "text.quote"],
                ["id": "save", "title": "Save Page", "icon": "bookmark"],
                ["id": "share", "title": "Share to Thea", "icon": "square.and.arrow.up"]
            ]
        ])
    }

    private func handleExecuteAction(_ actionId: String, params: [String: Any], completion: @escaping ([String: Any]) -> Void) {
        do {
            try saveRequest([
                "type": "action",
                "actionId": actionId,
                "params": params,
                "timestamp": Date().timeIntervalSince1970
            ])
        } catch {
            logger.error("Failed to save action request: \(error)")
            completion(["error": "Failed to queue action: \(error.localizedDescription)"])
            return
        }

        notifyMainApp("ActionExecuted")

        completion(["success": true, "message": "Action queued"])
    }

    private func handleTrackBrowsing(url: String, title: String, completion: @escaping ([String: Any]) -> Void) {
        // Privacy-conscious tracking - only store if user enabled
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            completion(["success": true]) // Tracking is best-effort
            return
        }

        let prefsPath = containerURL.appendingPathComponent("safari_prefs.json")
        // Reading prefs is best-effort; if prefs unreadable, tracking is off
        guard let data = try? Data(contentsOf: prefsPath),
              let prefs = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let trackingEnabled = prefs["trackBrowsing"] as? Bool,
              trackingEnabled
        else {
            completion(["success": true])
            return
        }

        // Store visit
        let historyPath = containerURL.appendingPathComponent("browse_history.jsonl")
        let entry: [String: Any] = [
            "url": url,
            "title": title,
            "timestamp": Date().timeIntervalSince1970
        ]

        do {
            let entryData = try JSONSerialization.data(withJSONObject: entry)
            guard let line = String(data: entryData, encoding: .utf8) else {
                completion(["success": false, "error": "Failed to encode browse entry as UTF-8"])
                return
            }

            if let handle = try? FileHandle(forWritingTo: historyPath) {
                handle.seekToEndOfFile()
                handle.write((line + "\n").data(using: .utf8)!)
                try handle.close()
            } else {
                try (line + "\n").write(to: historyPath, atomically: true, encoding: .utf8)
            }
        } catch {
            logger.error("Failed to write browse history: \(error)")
            // Browsing tracking is non-critical; report but don't block
            completion(["success": false, "error": "Failed to store browse history: \(error.localizedDescription)"])
            return
        }

        completion(["success": true])
    }

    private func handleSuggestAutofill(_ fields: [[String: Any]], completion: @escaping ([String: Any]) -> Void) {
        // Load saved form data from secure storage
        var suggestions: [[String: Any]] = []

        for field in fields {
            guard let fieldName = field["name"] as? String else { continue }

            let lowercaseName = fieldName.lowercased()
            var suggestion: [String: Any] = ["field": fieldName]

            if lowercaseName.contains("email") {
                suggestion["value"] = loadSecureValue(key: "email")
            } else if lowercaseName.contains("name"), !lowercaseName.contains("user") {
                suggestion["value"] = loadSecureValue(key: "fullName")
            } else if lowercaseName.contains("phone") {
                suggestion["value"] = loadSecureValue(key: "phone")
            }

            if suggestion["value"] != nil {
                suggestions.append(suggestion)
            }
        }

        completion(["success": true, "suggestions": suggestions])
    }

    // MARK: - Helpers

    private func generateQuickSummary(_ content: String) -> String {
        // Simple summarization - real implementation would use ML
        let sentences = content.components(separatedBy: ". ")
        if sentences.count > 3 {
            return sentences.prefix(3).joined(separator: ". ") + "..."
        }
        return String(content.prefix(200)) + (content.count > 200 ? "..." : "")
    }

    enum SaveRequestError: Error, LocalizedError {
        case noAppGroupContainer
        case directoryCreationFailed(Error)
        case serializationFailed(Error)
        case writeFailed(Error)

        var errorDescription: String? {
            switch self {
            case .noAppGroupContainer:
                "App group container unavailable"
            case .directoryCreationFailed(let error):
                "Failed to create requests directory: \(error.localizedDescription)"
            case .serializationFailed(let error):
                "Failed to serialize request: \(error.localizedDescription)"
            case .writeFailed(let error):
                "Failed to write request to disk: \(error.localizedDescription)"
            }
        }
    }

    func saveRequest(_ request: [String: Any]) throws {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            throw SaveRequestError.noAppGroupContainer
        }

        let requestsDir = containerURL.appendingPathComponent("SafariRequests", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: requestsDir, withIntermediateDirectories: true)
        } catch {
            throw SaveRequestError.directoryCreationFailed(error)
        }

        let filename = "\(UUID().uuidString).json"
        let filePath = requestsDir.appendingPathComponent(filename)

        let data: Data
        do {
            data = try JSONSerialization.data(withJSONObject: request)
        } catch {
            throw SaveRequestError.serializationFailed(error)
        }

        do {
            try data.write(to: filePath)
        } catch {
            throw SaveRequestError.writeFailed(error)
        }
    }

    func notifyMainApp(_ event: String) {
        let notificationName = CFNotificationName("app.thea.Safari\(event)" as CFString)
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            notificationName,
            nil,
            nil,
            true
        )
    }

    private func loadSecureValue(key: String) -> String? {
        // Would use Keychain in production
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            let autofillPath = containerURL.appendingPathComponent("autofill_data.json")
            if let data = try? Data(contentsOf: autofillPath),
               let autofill = try? JSONSerialization.jsonObject(with: data) as? [String: String]
            {
                return autofill[key]
            }
        }
        return nil
    }
}
