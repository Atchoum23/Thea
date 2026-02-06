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
    private let logger = Logger(subsystem: "app.thea.safari", category: "ExtensionHandler")
    private let appGroupID = "group.app.theathe"

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
        saveRequest([
            "type": "analyze",
            "content": String(content.prefix(10000)), // Limit content size
            "timestamp": Date().timeIntervalSince1970
        ])

        // Return quick response - full analysis via main app
        completion([
            "success": true,
            "message": "Analysis queued. Open Thea for full results.",
            "quickSummary": generateQuickSummary(content)
        ])
    }

    private func handleSaveToMemory(_ data: [String: Any], completion: @escaping ([String: Any]) -> Void) {
        saveRequest([
            "type": "memory",
            "data": data,
            "timestamp": Date().timeIntervalSince1970
        ])

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
        saveRequest([
            "type": "action",
            "actionId": actionId,
            "params": params,
            "timestamp": Date().timeIntervalSince1970
        ])

        notifyMainApp("ActionExecuted")

        completion(["success": true, "message": "Action queued"])
    }

    private func handleTrackBrowsing(url: String, title: String, completion: @escaping ([String: Any]) -> Void) {
        // Privacy-conscious tracking - only store if user enabled
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            let prefsPath = containerURL.appendingPathComponent("safari_prefs.json")
            if let data = try? Data(contentsOf: prefsPath),
               let prefs = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let trackingEnabled = prefs["trackBrowsing"] as? Bool,
               trackingEnabled
            {
                // Store visit
                let historyPath = containerURL.appendingPathComponent("browse_history.jsonl")
                let entry: [String: Any] = [
                    "url": url,
                    "title": title,
                    "timestamp": Date().timeIntervalSince1970
                ]

                if let entryData = try? JSONSerialization.data(withJSONObject: entry),
                   let line = String(data: entryData, encoding: .utf8)
                {
                    let handle = try? FileHandle(forWritingTo: historyPath)
                    if let handle {
                        handle.seekToEndOfFile()
                        handle.write((line + "\n").data(using: .utf8)!)
                        try? handle.close()
                    } else {
                        try? (line + "\n").write(to: historyPath, atomically: true, encoding: .utf8)
                    }
                }
            }
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

    private func saveRequest(_ request: [String: Any]) {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            return
        }

        let requestsDir = containerURL.appendingPathComponent("SafariRequests", isDirectory: true)
        try? FileManager.default.createDirectory(at: requestsDir, withIntermediateDirectories: true)

        let filename = "\(UUID().uuidString).json"
        let filePath = requestsDir.appendingPathComponent(filename)

        if let data = try? JSONSerialization.data(withJSONObject: request) {
            try? data.write(to: filePath)
        }
    }

    private func notifyMainApp(_ event: String) {
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
