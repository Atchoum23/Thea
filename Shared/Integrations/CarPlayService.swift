//
//  CarPlayService.swift
//  Thea
//
//  CarPlay integration for voice-first AI assistant experience
//

import Combine
import Foundation
import SwiftUI

#if canImport(CarPlay)
    import CarPlay
    import OSLog

    // MARK: - CarPlay Service

    /// Service for managing CarPlay integration
    @MainActor
    public class CarPlayService: NSObject, ObservableObject {
        public static let shared = CarPlayService()
        private let logger = Logger(subsystem: "ai.thea.app", category: "CarPlayService")

        // MARK: - Published State

        @Published public private(set) var isConnected = false
        @Published public private(set) var currentTemplate: CPTemplate?
        @Published public private(set) var recentConversations: [CarPlayConversation] = []
        @Published public private(set) var quickPrompts: [CarPlayQuickPrompt] = []

        // MARK: - CarPlay Interface

        private var interfaceController: CPInterfaceController?
        // periphery:ignore - Reserved: Wave 10 service — wired in future integration phase
        private var carWindow: CPWindow?

        // MARK: - Initialization

        override private init() {
            super.init()
            loadQuickPrompts()
        }

        // MARK: - CarPlay Connection

        public func connect(interfaceController: CPInterfaceController, window: CPWindow) {
            self.interfaceController = interfaceController
            carWindow = window
            isConnected = true

            interfaceController.delegate = self

            // Set up the root template
            setupRootTemplate()
        }

        public func disconnect() {
            interfaceController = nil
            carWindow = nil
            isConnected = false
        }

        // MARK: - Template Setup

        private func setupRootTemplate() {
            let tabBar = CPTabBarTemplate(templates: [
                createChatTab(),
                createQuickActionsTab(),
                createHistoryTab(),
                createSettingsTab()
            ])

            interfaceController?.setRootTemplate(tabBar, animated: true) { _, _ in }
        }

        private func createChatTab() -> CPListTemplate {
            let items: [CPListItem] = [
                createListItem(
                    title: "New Conversation",
                    subtitle: "Start a voice conversation with Thea",
                    image: UIImage(systemName: "bubble.left.fill")
                ) { [weak self] in
                    self?.startVoiceConversation()
                },
                createListItem(
                    title: "Continue Last Chat",
                    subtitle: recentConversations.first?.lastMessage ?? "No recent chats",
                    image: UIImage(systemName: "arrow.clockwise")
                ) { [weak self] in
                    self?.continueLastConversation()
                }
            ]

            let section = CPListSection(items: items)
            let template = CPListTemplate(title: "Thea", sections: [section])
            template.tabImage = UIImage(systemName: "brain")
            return template
        }

        private func createQuickActionsTab() -> CPListTemplate {
            let items = quickPrompts.map { prompt in
                createListItem(
                    title: prompt.title,
                    subtitle: prompt.description,
                    image: UIImage(systemName: prompt.icon)
                ) { [weak self] in
                    self?.executeQuickPrompt(prompt)
                }
            }

            let section = CPListSection(items: items, header: "Quick Actions", sectionIndexTitle: nil)
            let template = CPListTemplate(title: "Quick Actions", sections: [section])
            template.tabImage = UIImage(systemName: "bolt.fill")
            return template
        }

        private func createHistoryTab() -> CPListTemplate {
            let items = recentConversations.prefix(10).map { conversation in
                createListItem(
                    title: conversation.title,
                    subtitle: conversation.lastMessage,
                    image: UIImage(systemName: "clock.fill")
                ) { [weak self] in
                    self?.openConversation(conversation)
                }
            }

            let section = CPListSection(items: items)
            let template = CPListTemplate(title: "History", sections: [section])
            template.tabImage = UIImage(systemName: "clock.fill")
            return template
        }

        private func createSettingsTab() -> CPListTemplate {
            let items: [CPListItem] = [
                createListItem(
                    title: "Voice Settings",
                    subtitle: "Configure voice interaction",
                    image: UIImage(systemName: "speaker.wave.3.fill")
                ) { [weak self] in
                    self?.showVoiceSettings()
                },
                createListItem(
                    title: "Auto-Read Responses",
                    subtitle: "Read AI responses aloud",
                    image: UIImage(systemName: "text.bubble.fill")
                ) { [weak self] in
                    self?.toggleAutoRead()
                }
            ]

            let section = CPListSection(items: items)
            let template = CPListTemplate(title: "Settings", sections: [section])
            template.tabImage = UIImage(systemName: "gearshape.fill")
            return template
        }

        // MARK: - Helper Methods

        private func createListItem(
            title: String,
            subtitle: String?,
            image: UIImage?,
            handler: @escaping () -> Void
        ) -> CPListItem {
            let item = CPListItem(text: title, detailText: subtitle, image: image)
            item.handler = { _, completion in
                handler()
                completion()
            }
            return item
        }

        // MARK: - Actions

        private func startVoiceConversation() {
            let voiceTemplate = CPVoiceControlTemplate(voiceControlStates: [
                CPVoiceControlState(
                    identifier: "listening",
                    titleVariants: ["Listening..."],
                    image: UIImage(systemName: "mic.fill"),
                    repeats: false
                ),
                CPVoiceControlState(
                    identifier: "processing",
                    titleVariants: ["Processing..."],
                    image: UIImage(systemName: "brain"),
                    repeats: false
                ),
                CPVoiceControlState(
                    identifier: "speaking",
                    titleVariants: ["Speaking..."],
                    image: UIImage(systemName: "speaker.wave.3.fill"),
                    repeats: false
                )
            ])

            interfaceController?.pushTemplate(voiceTemplate, animated: true) { _, _ in }

            // Start voice recognition
            Task {
                await beginVoiceRecognition()
            }
        }

        private func beginVoiceRecognition() async {
            // Integration with VoiceRecognitionService
            // This would connect to the existing voice infrastructure
        }

        private func continueLastConversation() {
            guard let lastConversation = recentConversations.first else {
                showAlert(title: "No Recent Chats", message: "Start a new conversation")
                return
            }
            openConversation(lastConversation)
        }

        private func openConversation(_ conversation: CarPlayConversation) {
            let items = conversation.messages.suffix(10).map { message in
                createListItem(
                    title: message.isUser ? "You" : "Thea",
                    subtitle: message.content,
                    image: UIImage(systemName: message.isUser ? "person.fill" : "brain")
                ) {}
            }

            let section = CPListSection(items: items)
            let template = CPListTemplate(title: conversation.title, sections: [section])

            interfaceController?.pushTemplate(template, animated: true) { _, _ in }
        }

        private func executeQuickPrompt(_ prompt: CarPlayQuickPrompt) {
            // Show processing state
            let alertTemplate = CPAlertTemplate(
                titleVariants: ["Processing..."],
                actions: []
            )
            interfaceController?.presentTemplate(alertTemplate, animated: true) { _, _ in }

            // Execute prompt
            Task {
                // This would integrate with the AI service
                do {
                    try await Task.sleep(nanoseconds: 2_000_000_000)
                } catch {
                    logger.warning("CarPlay AI prompt sleep cancelled: \(error)")
                }

                await MainActor.run {
                    interfaceController?.dismissTemplate(animated: true) { _, _ in }
                    showResponse(for: prompt)
                }
            }
        }

        private func showResponse(for prompt: CarPlayQuickPrompt) {
            let informationTemplate = CPInformationTemplate(
                title: prompt.title,
                layout: .leading,
                items: [
                    CPInformationItem(title: "Response", detail: "AI response would appear here")
                ],
                actions: [
                    CPTextButton(title: "Read Aloud", textStyle: .normal) { _ in
                        // Trigger text-to-speech
                    },
                    CPTextButton(title: "Done", textStyle: .confirm) { [weak self] _ in
                        self?.interfaceController?.popTemplate(animated: true) { _, _ in }
                    }
                ]
            )

            interfaceController?.pushTemplate(informationTemplate, animated: true) { _, _ in }
        }

        private func showVoiceSettings() {
            // Voice settings implementation
        }

        private func toggleAutoRead() {
            // Toggle auto-read setting
        }

        private func showAlert(title: String, message _: String) {
            let alertTemplate = CPAlertTemplate(
                titleVariants: [title],
                actions: [
                    CPAlertAction(title: "OK", style: .default) { [weak self] _ in
                        self?.interfaceController?.dismissTemplate(animated: true) { _, _ in }
                    }
                ]
            )
            interfaceController?.presentTemplate(alertTemplate, animated: true) { _, _ in }
        }

        // MARK: - Data Loading

        private func loadQuickPrompts() {
            quickPrompts = [
                CarPlayQuickPrompt(
                    id: "navigation",
                    title: "Navigate Home",
                    description: "Get directions to home",
                    icon: "house.fill",
                    prompt: "Navigate me home"
                ),
                CarPlayQuickPrompt(
                    id: "weather",
                    title: "Weather Update",
                    description: "Current weather conditions",
                    icon: "cloud.sun.fill",
                    prompt: "What's the current weather?"
                ),
                CarPlayQuickPrompt(
                    id: "calendar",
                    title: "Next Meeting",
                    description: "Your upcoming appointments",
                    icon: "calendar",
                    prompt: "What's my next meeting?"
                ),
                CarPlayQuickPrompt(
                    id: "message",
                    title: "Read Messages",
                    description: "Recent unread messages",
                    icon: "message.fill",
                    prompt: "Read my recent messages"
                ),
                CarPlayQuickPrompt(
                    id: "music",
                    title: "Play Music",
                    description: "Resume or find music",
                    icon: "music.note",
                    prompt: "Play some music"
                ),
                CarPlayQuickPrompt(
                    id: "reminder",
                    title: "Add Reminder",
                    description: "Create a quick reminder",
                    icon: "bell.fill",
                    prompt: "Remind me when I get home to..."
                )
            ]
        }
    }

    // MARK: - CPInterfaceControllerDelegate

    extension CarPlayService: CPInterfaceControllerDelegate {
        nonisolated public func templateWillAppear(_ aTemplate: CPTemplate, animated _: Bool) {
            Task { @MainActor in
                currentTemplate = aTemplate
            }
        }

        nonisolated public func templateDidAppear(_: CPTemplate, animated _: Bool) {}

        nonisolated public func templateWillDisappear(_: CPTemplate, animated _: Bool) {}

        nonisolated public func templateDidDisappear(_: CPTemplate, animated _: Bool) {}
    }

#endif

// MARK: - Supporting Types

public struct CarPlayConversation: Identifiable, Codable, Sendable {
    public let id: UUID
    public var title: String
    public var messages: [CarPlayMessage]
    public var lastUpdated: Date

    public var lastMessage: String {
        messages.last?.content ?? "No messages"
    }

    public init(id: UUID = UUID(), title: String, messages: [CarPlayMessage] = [], lastUpdated: Date = Date()) {
        self.id = id
        self.title = title
        self.messages = messages
        self.lastUpdated = lastUpdated
    }
}

public struct CarPlayMessage: Identifiable, Codable, Sendable {
    public let id: UUID
    public let content: String
    public let isUser: Bool
    public let timestamp: Date

    public init(id: UUID = UUID(), content: String, isUser: Bool, timestamp: Date = Date()) {
        self.id = id
        self.content = content
        self.isUser = isUser
        self.timestamp = timestamp
    }
}

public struct CarPlayQuickPrompt: Identifiable, Codable, Sendable {
    public let id: String
    public let title: String
    public let description: String
    public let icon: String
    public let prompt: String
}
