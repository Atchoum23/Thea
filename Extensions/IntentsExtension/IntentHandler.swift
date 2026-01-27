//
//  IntentHandler.swift
//  TheaIntentsExtension
//
//  Created by Thea
//

import Intents
import os.log

/// Intents Extension Handler for Thea
/// Handles Siri and Shortcuts integrations
class IntentHandler: INExtension {
    private let logger = Logger(subsystem: "app.thea.intents", category: "IntentHandler")
    private let appGroupID = "group.app.thea"

    override func handler(for intent: INIntent) -> Any {
        logger.info("Handling intent: \(type(of: intent))")

        // Return appropriate handler based on intent type
        switch intent {
        case is INSendMessageIntent:
            return SendMessageIntentHandler()
        case is INSearchForMessagesIntent:
            return SearchMessagesIntentHandler()
        case is INSearchForNotebookItemsIntent:
            return SearchNotebookIntentHandler()
        default:
            return self
        }
    }
}

// MARK: - Send Message Intent Handler

class SendMessageIntentHandler: NSObject, INSendMessageIntentHandling {
    private let logger = Logger(subsystem: "app.thea.intents", category: "SendMessage")
    private let appGroupID = "group.app.thea"

    func handle(intent: INSendMessageIntent, completion: @escaping (INSendMessageIntentResponse) -> Void) {
        logger.info("Handling send message intent")

        guard let content = intent.content else {
            completion(INSendMessageIntentResponse(code: .failure, userActivity: nil))
            return
        }

        // Process the message with Thea
        processMessage(content) { success, response in
            if success {
                // Save the response for the main app
                self.saveResponse(response)

                let intentResponse = INSendMessageIntentResponse(code: .success, userActivity: nil)
                let message = INMessage(
                    identifier: UUID().uuidString,
                    content: response,
                    dateSent: Date(),
                    sender: INPerson(personHandle: INPersonHandle(value: "thea", type: .unknown), nameComponents: nil, displayName: "Thea", image: nil, contactIdentifier: nil, customIdentifier: "thea"),
                    recipients: intent.recipients
                )
                if #available(iOS 16.0, *) {
                    intentResponse.sentMessages = [message]
                } else {
                    intentResponse.sentMessage = message
                }
                completion(intentResponse)
            } else {
                completion(INSendMessageIntentResponse(code: .failure, userActivity: nil))
            }
        }
    }

    func resolveRecipients(for _: INSendMessageIntent, with completion: @escaping ([INSendMessageRecipientResolutionResult]) -> Void) {
        // Always resolve to Thea
        let thea = INPerson(
            personHandle: INPersonHandle(value: "thea", type: .unknown),
            nameComponents: nil,
            displayName: "Thea",
            image: nil,
            contactIdentifier: nil,
            customIdentifier: "thea"
        )
        completion([.success(with: thea)])
    }

    func resolveContent(for intent: INSendMessageIntent, with completion: @escaping (INStringResolutionResult) -> Void) {
        if let content = intent.content, !content.isEmpty {
            completion(.success(with: content))
        } else {
            completion(.needsValue())
        }
    }

    private func processMessage(_ message: String, completion: @escaping (Bool, String) -> Void) {
        // Save request to shared storage for main app
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            completion(false, "")
            return
        }

        let request: [String: Any] = [
            "message": message,
            "timestamp": Date().timeIntervalSince1970,
            "source": "siri"
        ]

        let requestsDir = containerURL.appendingPathComponent("SiriRequests", isDirectory: true)
        try? FileManager.default.createDirectory(at: requestsDir, withIntermediateDirectories: true)

        let requestPath = requestsDir.appendingPathComponent("\(UUID().uuidString).json")

        if let data = try? JSONSerialization.data(withJSONObject: request) {
            try? data.write(to: requestPath)
        }

        // Notify main app
        let notificationName = CFNotificationName("app.thea.SiriRequest" as CFString)
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            notificationName,
            nil,
            nil,
            true
        )

        // Return quick acknowledgment (full processing by main app)
        completion(true, "I've received your message. Let me process that for you.")
    }

    private func saveResponse(_ response: String) {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            return
        }

        let responsePath = containerURL.appendingPathComponent("siri_response.txt")
        try? response.write(to: responsePath, atomically: true, encoding: .utf8)
    }
}

// MARK: - Search Messages Intent Handler

class SearchMessagesIntentHandler: NSObject, INSearchForMessagesIntentHandling {
    private let logger = Logger(subsystem: "app.thea.intents", category: "SearchMessages")
    private let appGroupID = "group.app.thea"

    func handle(intent: INSearchForMessagesIntent, completion: @escaping (INSearchForMessagesIntentResponse) -> Void) {
        logger.info("Handling search messages intent")

        // Search through Thea conversations using sender display name as proxy search
        let searchQuery = intent.senders?.first?.displayName
        let messages = searchConversations(query: searchQuery)

        let response = INSearchForMessagesIntentResponse(code: .success, userActivity: nil)
        response.messages = messages
        completion(response)
    }

    private func searchConversations(query: String?) -> [INMessage] {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            return []
        }

        let conversationsDir = containerURL.appendingPathComponent("Conversations", isDirectory: true)

        guard let files = try? FileManager.default.contentsOfDirectory(at: conversationsDir, includingPropertiesForKeys: nil) else {
            return []
        }

        var results: [INMessage] = []
        let searchTerm = query?.lowercased() ?? ""

        for file in files.prefix(50) { // Limit for performance
            guard let data = try? Data(contentsOf: file),
                  let conversation = try? JSONDecoder().decode(IntentConversation.self, from: data)
            else {
                continue
            }

            for message in conversation.messages {
                if searchTerm.isEmpty || message.content.lowercased().contains(searchTerm) {
                    let sender = INPerson(
                        personHandle: INPersonHandle(value: message.role, type: .unknown),
                        nameComponents: nil,
                        displayName: message.role == "user" ? "You" : "Thea",
                        image: nil,
                        contactIdentifier: nil,
                        customIdentifier: message.role
                    )

                    let inMessage = INMessage(
                        identifier: UUID().uuidString,
                        content: message.content,
                        dateSent: message.timestamp,
                        sender: sender,
                        recipients: []
                    )
                    results.append(inMessage)

                    if results.count >= 20 {
                        return results
                    }
                }
            }
        }

        return results
    }
}

// MARK: - Search Notebook Intent Handler

class SearchNotebookIntentHandler: NSObject, INSearchForNotebookItemsIntentHandling {
    private let logger = Logger(subsystem: "app.thea.intents", category: "SearchNotebook")
    private let appGroupID = "group.app.thea"

    func handle(intent: INSearchForNotebookItemsIntent, completion: @escaping (INSearchForNotebookItemsIntentResponse) -> Void) {
        logger.info("Handling search notebook intent")

        // Search through Thea memories and notes
        let items = searchNotebook(query: intent.title)

        let response = INSearchForNotebookItemsIntentResponse(code: .success, userActivity: nil)
        response.tasks = items
        completion(response)
    }

    private func searchNotebook(query: INSpeakableString?) -> [INTask] {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            return []
        }

        let memoriesDir = containerURL.appendingPathComponent("Memories", isDirectory: true)

        guard let files = try? FileManager.default.contentsOfDirectory(at: memoriesDir, includingPropertiesForKeys: nil) else {
            return []
        }

        var results: [INTask] = []
        let searchTerm = query?.spokenPhrase.lowercased() ?? ""

        for file in files.prefix(50) {
            guard let data = try? Data(contentsOf: file),
                  let memory = try? JSONDecoder().decode(IntentMemory.self, from: data)
            else {
                continue
            }

            if searchTerm.isEmpty ||
                memory.content.lowercased().contains(searchTerm) ||
                (memory.title?.lowercased().contains(searchTerm) ?? false)
            {
                let task = INTask(
                    title: INSpeakableString(spokenPhrase: memory.title ?? "Memory"),
                    status: .notCompleted,
                    taskType: .notCompletable,
                    spatialEventTrigger: nil,
                    temporalEventTrigger: nil,
                    createdDateComponents: Calendar.current.dateComponents([.year, .month, .day], from: memory.created),
                    modifiedDateComponents: nil,
                    identifier: memory.id
                )
                results.append(task)

                if results.count >= 20 {
                    return results
                }
            }
        }

        return results
    }
}

// MARK: - Data Models

struct IntentConversation: Codable {
    let id: String
    let title: String
    let messages: [IntentMessage]
}

struct IntentMessage: Codable {
    let role: String
    let content: String
    let timestamp: Date
}

struct IntentMemory: Codable {
    let id: String
    let title: String?
    let content: String
    let created: Date
}
