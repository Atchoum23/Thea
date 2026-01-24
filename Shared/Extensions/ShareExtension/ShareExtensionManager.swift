// ShareExtensionManager.swift
// Share Extension support for receiving content from other apps

import Foundation
import OSLog
import Combine
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Share Extension Manager

/// Manages shared content from other apps via Share Extension
@MainActor
public final class ShareExtensionManager: ObservableObject {
    public static let shared = ShareExtensionManager()

    private let logger = Logger(subsystem: "com.thea.app", category: "ShareExtension")

    // MARK: - App Group

    private let appGroupIdentifier = "group.com.thea.app"

    // MARK: - Published State

    @Published public private(set) var pendingSharedContent: [SharedContent] = []
    @Published public private(set) var isProcessing = false

    // MARK: - Initialization

    private init() {
        loadPendingContent()
        setupObservers()
    }

    private func setupObservers() {
        // Listen for app becoming active to check for new shared content
        #if os(iOS)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        #endif
    }

    @objc private func appDidBecomeActive() {
        loadPendingContent()
    }

    // MARK: - Content Loading

    private func loadPendingContent() {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) else {
            logger.warning("Could not access app group container")
            return
        }

        let sharedDataURL = containerURL.appendingPathComponent("SharedContent")

        guard FileManager.default.fileExists(atPath: sharedDataURL.path) else {
            return
        }

        do {
            let data = try Data(contentsOf: sharedDataURL)
            let content = try JSONDecoder().decode([SharedContent].self, from: data)
            pendingSharedContent = content

            if !content.isEmpty {
                logger.info("Loaded \(content.count) pending shared items")
                NotificationCenter.default.post(name: .sharedContentReceived, object: nil)
            }
        } catch {
            logger.error("Failed to load shared content: \(error.localizedDescription)")
        }
    }

    // MARK: - Content Processing

    /// Process shared content
    public func processSharedContent(_ content: SharedContent) async -> SharedContentResult {
        isProcessing = true
        defer { isProcessing = false }

        logger.info("Processing shared content: \(content.type.rawValue)")

        switch content.type {
        case .text:
            return await processText(content)
        case .url:
            return await processURL(content)
        case .image:
            return await processImage(content)
        case .file:
            return await processFile(content)
        case .pdf:
            return await processPDF(content)
        }
    }

    private func processText(_ content: SharedContent) async -> SharedContentResult {
        guard let text = content.text else {
            return SharedContentResult(success: false, error: "No text content")
        }

        // Create a new conversation with the shared text
        let message = "Shared text:\n\n\(text)"

        return SharedContentResult(
            success: true,
            action: .createConversation(initialMessage: message),
            content: content
        )
    }

    private func processURL(_ content: SharedContent) async -> SharedContentResult {
        guard let urlString = content.url,
              let url = URL(string: urlString) else {
            return SharedContentResult(success: false, error: "Invalid URL")
        }

        // Optionally fetch URL content
        let message = "Shared URL: \(url.absoluteString)"

        return SharedContentResult(
            success: true,
            action: .createConversation(initialMessage: message),
            content: content
        )
    }

    private func processImage(_ content: SharedContent) async -> SharedContentResult {
        guard let imageData = content.data else {
            return SharedContentResult(success: false, error: "No image data")
        }

        // Analyze image with Vision
        do {
            let analysis = try await VisionIntelligence.shared.analyzeForAI(imageData: imageData)
            let message = "Shared image analysis:\n\n\(analysis.description)"

            return SharedContentResult(
                success: true,
                action: .createConversation(initialMessage: message),
                content: content
            )
        } catch {
            return SharedContentResult(success: false, error: error.localizedDescription)
        }
    }

    private func processFile(_ content: SharedContent) async -> SharedContentResult {
        guard let fileURL = content.fileURL else {
            return SharedContentResult(success: false, error: "No file URL")
        }

        let fileName = fileURL.lastPathComponent
        let message = "Shared file: \(fileName)"

        return SharedContentResult(
            success: true,
            action: .createConversation(initialMessage: message),
            content: content
        )
    }

    private func processPDF(_ content: SharedContent) async -> SharedContentResult {
        guard let pdfData = content.data else {
            return SharedContentResult(success: false, error: "No PDF data")
        }

        // Analyze PDF with Document Intelligence
        do {
            let analysis = try await DocumentIntelligence.shared.analyze(documentData: pdfData, type: .pdf)
            let message = "Shared PDF:\n\nTitle: \(analysis.title ?? "Unknown")\n\nSummary: \(analysis.summary)"

            return SharedContentResult(
                success: true,
                action: .createConversation(initialMessage: message),
                content: content
            )
        } catch {
            return SharedContentResult(success: false, error: error.localizedDescription)
        }
    }

    // MARK: - Content Management

    /// Remove processed content
    public func removeContent(_ content: SharedContent) {
        pendingSharedContent.removeAll { $0.id == content.id }
        savePendingContent()
    }

    /// Clear all pending content
    public func clearAllContent() {
        pendingSharedContent.removeAll()
        savePendingContent()
    }

    private func savePendingContent() {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) else {
            return
        }

        let sharedDataURL = containerURL.appendingPathComponent("SharedContent")

        do {
            let data = try JSONEncoder().encode(pendingSharedContent)
            try data.write(to: sharedDataURL)
        } catch {
            logger.error("Failed to save pending content: \(error.localizedDescription)")
        }
    }

    // MARK: - Extension Communication

    /// Called by Share Extension to add content
    public static func addSharedContent(_ content: SharedContent) {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.thea.app"
        ) else {
            return
        }

        let sharedDataURL = containerURL.appendingPathComponent("SharedContent")

        var existing: [SharedContent] = []

        // Load existing content
        if FileManager.default.fileExists(atPath: sharedDataURL.path),
           let data = try? Data(contentsOf: sharedDataURL),
           let decoded = try? JSONDecoder().decode([SharedContent].self, from: data) {
            existing = decoded
        }

        // Add new content
        existing.append(content)

        // Save
        if let data = try? JSONEncoder().encode(existing) {
            try? data.write(to: sharedDataURL)
        }
    }

    // MARK: - Quick Actions

    /// Get quick actions for shared content
    public func getQuickActions(for content: SharedContent) -> [QuickAction] {
        var actions: [QuickAction] = [
            QuickAction(
                id: "ask-ai",
                title: "Ask AI About This",
                icon: "sparkles",
                action: .askAI
            ),
            QuickAction(
                id: "new-conversation",
                title: "Start Conversation",
                icon: "bubble.left.and.bubble.right",
                action: .newConversation
            )
        ]

        switch content.type {
        case .text:
            actions.append(QuickAction(
                id: "summarize",
                title: "Summarize",
                icon: "doc.text",
                action: .summarize
            ))
            actions.append(QuickAction(
                id: "translate",
                title: "Translate",
                icon: "globe",
                action: .translate
            ))

        case .url:
            actions.append(QuickAction(
                id: "fetch-content",
                title: "Fetch & Analyze",
                icon: "arrow.down.doc",
                action: .fetchContent
            ))

        case .image:
            actions.append(QuickAction(
                id: "describe",
                title: "Describe Image",
                icon: "eye",
                action: .describeImage
            ))
            actions.append(QuickAction(
                id: "extract-text",
                title: "Extract Text (OCR)",
                icon: "text.viewfinder",
                action: .extractText
            ))

        case .file, .pdf:
            actions.append(QuickAction(
                id: "analyze",
                title: "Analyze Document",
                icon: "doc.text.magnifyingglass",
                action: .analyzeDocument
            ))
        }

        return actions
    }
}

// MARK: - Types

public struct SharedContent: Identifiable, Codable {
    public let id: UUID
    public let type: ContentType
    public let text: String?
    public let url: String?
    public let data: Data?
    public let fileURL: URL?
    public let fileName: String?
    public let mimeType: String?
    public let sourceApp: String?
    public let timestamp: Date

    public enum ContentType: String, Codable {
        case text
        case url
        case image
        case file
        case pdf
    }

    public init(
        id: UUID = UUID(),
        type: ContentType,
        text: String? = nil,
        url: String? = nil,
        data: Data? = nil,
        fileURL: URL? = nil,
        fileName: String? = nil,
        mimeType: String? = nil,
        sourceApp: String? = nil,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.text = text
        self.url = url
        self.data = data
        self.fileURL = fileURL
        self.fileName = fileName
        self.mimeType = mimeType
        self.sourceApp = sourceApp
        self.timestamp = timestamp
    }
}

public struct SharedContentResult {
    public let success: Bool
    public let action: ResultAction?
    public let content: SharedContent?
    public let error: String?

    public enum ResultAction {
        case createConversation(initialMessage: String)
        case addToConversation(conversationId: String, message: String)
        case createArtifact(content: String, type: String)
    }

    public init(
        success: Bool,
        action: ResultAction? = nil,
        content: SharedContent? = nil,
        error: String? = nil
    ) {
        self.success = success
        self.action = action
        self.content = content
        self.error = error
    }
}

public struct QuickAction: Identifiable {
    public let id: String
    public let title: String
    public let icon: String
    public let action: ActionType

    public enum ActionType {
        case askAI
        case newConversation
        case summarize
        case translate
        case fetchContent
        case describeImage
        case extractText
        case analyzeDocument
    }
}

// MARK: - Notifications

public extension Notification.Name {
    static let sharedContentReceived = Notification.Name("thea.shareExtension.contentReceived")
}

// MARK: - Share Extension View Controller Base

#if canImport(UIKit)
import Social

/// Base class for Share Extension view controller
@available(iOS 13.0, *)
open class TheaShareExtensionViewController: SLComposeServiceViewController {

    override open func isContentValid() -> Bool {
        // SAFETY: Validate content without force unwrapping extensionContext
        guard let context = extensionContext else { return contentText != nil }
        return contentText != nil || !context.inputItems.isEmpty
    }

    override open func didSelectPost() {
        // Process the shared content
        Task {
            await processSharedContent()
            extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        }
    }

    private func processSharedContent() async {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let itemProviders = extensionItem.attachments else {
            return
        }

        for provider in itemProviders {
            if provider.hasItemConformingToTypeIdentifier("public.plain-text") {
                await handleTextItem(provider)
            } else if provider.hasItemConformingToTypeIdentifier("public.url") {
                await handleURLItem(provider)
            } else if provider.hasItemConformingToTypeIdentifier("public.image") {
                await handleImageItem(provider)
            } else if provider.hasItemConformingToTypeIdentifier("com.adobe.pdf") {
                await handlePDFItem(provider)
            } else if provider.hasItemConformingToTypeIdentifier("public.data") {
                await handleFileItem(provider)
            }
        }
    }

    private func handleTextItem(_ provider: NSItemProvider) async {
        do {
            let text = try await provider.loadItem(forTypeIdentifier: "public.plain-text") as? String
            let content = SharedContent(type: .text, text: text)
            ShareExtensionManager.addSharedContent(content)
        } catch {
            print("Failed to load text: \(error)")
        }
    }

    private func handleURLItem(_ provider: NSItemProvider) async {
        do {
            let url = try await provider.loadItem(forTypeIdentifier: "public.url") as? URL
            let content = SharedContent(type: .url, url: url?.absoluteString)
            ShareExtensionManager.addSharedContent(content)
        } catch {
            print("Failed to load URL: \(error)")
        }
    }

    private func handleImageItem(_ provider: NSItemProvider) async {
        do {
            if let image = try await provider.loadItem(forTypeIdentifier: "public.image") as? UIImage,
               let data = image.jpegData(compressionQuality: 0.8) {
                let content = SharedContent(type: .image, data: data)
                ShareExtensionManager.addSharedContent(content)
            }
        } catch {
            print("Failed to load image: \(error)")
        }
    }

    private func handlePDFItem(_ provider: NSItemProvider) async {
        do {
            if let url = try await provider.loadItem(forTypeIdentifier: "com.adobe.pdf") as? URL {
                let data = try Data(contentsOf: url)
                let content = SharedContent(type: .pdf, data: data, fileName: url.lastPathComponent)
                ShareExtensionManager.addSharedContent(content)
            }
        } catch {
            print("Failed to load PDF: \(error)")
        }
    }

    private func handleFileItem(_ provider: NSItemProvider) async {
        do {
            if let url = try await provider.loadItem(forTypeIdentifier: "public.data") as? URL {
                let data = try Data(contentsOf: url)
                let content = SharedContent(
                    type: .file,
                    data: data,
                    fileURL: url,
                    fileName: url.lastPathComponent
                )
                ShareExtensionManager.addSharedContent(content)
            }
        } catch {
            print("Failed to load file: \(error)")
        }
    }

    override open func configurationItems() -> [Any] {
        // SAFETY: Return non-optional array (override removes IUO)
        return []
    }
}
#endif

// MARK: - Action Extension Support

/// Handles action extension items
public class ActionExtensionHandler {

    /// Process action extension input
    public static func processInput(from extensionContext: NSExtensionContext?) async -> SharedContent? {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let provider = extensionItem.attachments?.first else {
            return nil
        }

        // Handle different content types
        if provider.hasItemConformingToTypeIdentifier("public.plain-text") {
            if let text = try? await provider.loadItem(forTypeIdentifier: "public.plain-text") as? String {
                return SharedContent(type: .text, text: text)
            }
        }

        if provider.hasItemConformingToTypeIdentifier("public.url") {
            if let url = try? await provider.loadItem(forTypeIdentifier: "public.url") as? URL {
                return SharedContent(type: .url, url: url.absoluteString)
            }
        }

        return nil
    }
}
