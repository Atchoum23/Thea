//
//  MailExtensionHandler.swift
//  Thea Mail Extension
//
//  Created by Thea
//  Mail extension for AI-powered email assistance
//

#if canImport(MailKit)
    import MailKit
    import os.log

    /// Mail extension for email summarization and smart replies
    @available(macOS 12.0, iOS 16.0, *)
    class MailExtensionHandler: MEExtension {
        private let logger = Logger(subsystem: "app.thea.mail", category: "MailExtension")

        // MARK: - MEExtension

        func handler(for _: MEExtensionSession) -> MEExtensionHandler {
            logger.info("Creating mail extension handler for session")
            return TheaMailHandler()
        }
    }

    /// Handles mail extension functionality
    @available(macOS 12.0, iOS 16.0, *)
    class TheaMailHandler: MEExtensionHandler {
        private let logger = Logger(subsystem: "app.thea.mail", category: "TheaMailHandler")

        // MARK: - Content Blocking

        override func contentBlocker() -> MEContentBlocker? {
            TheaContentBlocker()
        }

        // MARK: - Message Actions

        override func messageActions(for _: MEMessage) async -> [MEMessageAction] {
            var actions: [MEMessageAction] = []

            // Summarize action
            actions.append(MEMessageAction(
                identifier: "summarize",
                title: "Summarize with Thea",
                image: UIImage(systemName: "sparkles")
            ))

            // Quick reply action
            actions.append(MEMessageAction(
                identifier: "quickReply",
                title: "Smart Reply",
                image: UIImage(systemName: "arrowshape.turn.up.left.fill")
            ))

            // Translate action
            actions.append(MEMessageAction(
                identifier: "translate",
                title: "Translate",
                image: UIImage(systemName: "globe")
            ))

            return actions
        }

        override func perform(action: MEMessageAction, for message: MEMessage) async throws {
            logger.info("Performing action: \(action.identifier)")

            switch action.identifier {
            case "summarize":
                try await summarizeMessage(message)
            case "quickReply":
                try await generateQuickReply(message)
            case "translate":
                try await translateMessage(message)
            default:
                break
            }
        }

        // MARK: - Compose Actions

        override func composeActions(for _: MEComposeSession) async -> [MEComposeAction] {
            var actions: [MEComposeAction] = []

            // Improve writing action
            actions.append(MEComposeAction(
                identifier: "improve",
                title: "Improve with Thea",
                image: UIImage(systemName: "wand.and.stars")
            ))

            // Shorten action
            actions.append(MEComposeAction(
                identifier: "shorten",
                title: "Make Concise",
                image: UIImage(systemName: "arrow.down.right.and.arrow.up.left")
            ))

            // Formalize action
            actions.append(MEComposeAction(
                identifier: "formalize",
                title: "Make Professional",
                image: UIImage(systemName: "briefcase.fill")
            ))

            return actions
        }

        override func perform(action: MEComposeAction, for session: MEComposeSession) async throws {
            logger.info("Performing compose action: \(action.identifier)")

            guard let body = session.body else { return }

            switch action.identifier {
            case "improve":
                try await improveComposition(body, session: session)
            case "shorten":
                try await shortenComposition(body, session: session)
            case "formalize":
                try await formalizeComposition(body, session: session)
            default:
                break
            }
        }

        // MARK: - Message Security

        override func messageSecurityHandler() -> MEMessageSecurityHandler? {
            TheaSecurityHandler()
        }

        // MARK: - Private Methods

        private func summarizeMessage(_ message: MEMessage) async throws {
            // Get message content
            let subject = message.subject
            let fromAddress = message.fromAddress.rawString

            // In a real implementation, this would call Thea's AI service
            // and display the summary in a notification or the app

            logger.info("Summarizing message: \(subject ?? "No subject")")

            // Save request to app group for main app to process
            saveRequest(type: "summarize", messageId: message.identifier.uuidString)
        }

        private func generateQuickReply(_ message: MEMessage) async throws {
            logger.info("Generating quick reply for message")

            saveRequest(type: "quickReply", messageId: message.identifier.uuidString)
        }

        private func translateMessage(_ message: MEMessage) async throws {
            logger.info("Translating message")

            saveRequest(type: "translate", messageId: message.identifier.uuidString)
        }

        private func improveComposition(_ body: String, session _: MEComposeSession) async throws {
            logger.info("Improving composition")

            // In a real implementation, this would:
            // 1. Send the body to Thea's AI service
            // 2. Receive improved text
            // 3. Update the composition

            saveRequest(type: "improve", content: body)
        }

        private func shortenComposition(_ body: String, session _: MEComposeSession) async throws {
            logger.info("Shortening composition")

            saveRequest(type: "shorten", content: body)
        }

        private func formalizeComposition(_ body: String, session _: MEComposeSession) async throws {
            logger.info("Formalizing composition")

            saveRequest(type: "formalize", content: body)
        }

        private func saveRequest(type: String, messageId: String? = nil, content: String? = nil) {
            guard let containerURL = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: "group.app.theathe"
            ) else { return }

            let request = MailRequest(
                type: type,
                messageId: messageId,
                content: content,
                timestamp: Date()
            )

            let requestsURL = containerURL.appendingPathComponent("mail_requests.json")

            var requests: [MailRequest] = []
            if let data = try? Data(contentsOf: requestsURL),
               let existing = try? JSONDecoder().decode([MailRequest].self, from: data)
            {
                requests = existing
            }

            requests.append(request)

            if let data = try? JSONEncoder().encode(requests) {
                try? data.write(to: requestsURL)
            }
        }
    }

    // MARK: - Content Blocker

    @available(macOS 12.0, iOS 16.0, *)
    class TheaContentBlocker: MEContentBlocker {
        func contentRules() -> [MEContentRule] {
            // Block tracking pixels and external content by default
            [
                MEContentRule(
                    identifier: "block_tracking_pixels",
                    trigger: MEContentRuleTrigger(urlFilter: ".*tracking.*"),
                    action: .block
                ),
                MEContentRule(
                    identifier: "block_external_images",
                    trigger: MEContentRuleTrigger(urlFilter: ".*\\.gif$"),
                    action: .block
                )
            ]
        }
    }

    // MARK: - Security Handler

    @available(macOS 12.0, iOS 16.0, *)
    class TheaSecurityHandler: MEMessageSecurityHandler {
        private let logger = Logger(subsystem: "app.thea.mail", category: "Security")

        func decodedMessage(for _: MEMessage) async -> MEDecodedMessage? {
            // Analyze message for security issues
            logger.debug("Analyzing message security")

            return nil // Return nil to use default decoding
        }

        func primaryActionClicked(for _: MEMessage) async throws {
            // Handle security action clicked
            logger.info("Security action clicked")
        }
    }

    // MARK: - Supporting Types

    struct MailRequest: Codable {
        let type: String
        let messageId: String?
        let content: String?
        let timestamp: Date
    }
#else

    // Stub for platforms without MailKit
    import Foundation

    class MailExtensionHandler {
        // MailKit not available on this platform
    }

#endif
