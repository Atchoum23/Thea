//
//  ShareViewController.swift
//  TheaShareExtension
//
//  Created by Thea
//

import Social
import UIKit
import UniformTypeIdentifiers
import Vision

/// Share Extension for Thea
/// Allows users to share content from any app to Thea for AI processing
class ShareViewController: SLComposeServiceViewController {
    // MARK: - Error Types

    enum ShareError: Error, LocalizedError {
        case noAppGroupContainer
        case directoryCreationFailed(Error)
        case imageWriteFailed(index: Int, Error)
        case fileCopyFailed(filename: String, Error)
        case metadataWriteFailed(Error)
        case pendingListWriteFailed(Error)

        var errorDescription: String? {
            switch self {
            case .noAppGroupContainer:
                "Unable to access shared storage. Thea may need to be reinstalled."
            case .directoryCreationFailed(let error):
                "Failed to prepare storage: \(error.localizedDescription)"
            case .imageWriteFailed(let index, let error):
                "Failed to save image \(index + 1): \(error.localizedDescription)"
            case .fileCopyFailed(let filename, let error):
                "Failed to copy \"\(filename)\": \(error.localizedDescription)"
            case .metadataWriteFailed(let error):
                "Failed to save share metadata: \(error.localizedDescription)"
            case .pendingListWriteFailed(let error):
                "Failed to update pending shares: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Properties

    private var sharedItems: [SharedItem] = []

    private struct SharedItem {
        let type: ItemType
        let content: Any

        enum ItemType {
            case text
            case url
            case image
            case file
        }
    }

    // App Group for shared data
    private let appGroupID = "group.app.theathe"

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        placeholder = "Add a note to Thea..."
        title = "Share to Thea"
        processInputItems()
    }

    // MARK: - Validation

    override func isContentValid() -> Bool {
        // Content is valid if we have text or shared items
        let hasContent = !sharedItems.isEmpty || !contentText.isEmpty
        return hasContent
    }

    // MARK: - Configuration

    override func configurationItems() -> [Any]! {
        // Configuration items for the share sheet
        var items: [SLComposeSheetConfigurationItem] = []

        // Action type selector
        if let actionItem = SLComposeSheetConfigurationItem() {
            actionItem.title = "Action"
            actionItem.value = "Ask Thea"
            actionItem.tapHandler = { [weak self] in
                self?.showActionPicker()
            }
            items.append(actionItem)
        }

        return items
    }

    // MARK: - Post Action

    override func didSelectPost() {
        // Save shared content to App Group for the main app to process
        do {
            try saveSharedContent()
        } catch {
            let alert = UIAlertController(
                title: "Share Failed",
                message: error.localizedDescription,
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
                self?.extensionContext?.cancelRequest(
                    withError: error
                )
            })
            present(alert, animated: true)
            return
        }

        // Notify the main app
        notifyMainApp()

        // Complete the extension
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }

    override func didSelectCancel() {
        extensionContext?.cancelRequest(withError: NSError(domain: "ShareCancelled", code: 0))
    }

    // MARK: - Private Methods

    private func processInputItems() {
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else { return }

        for item in extensionItems {
            guard let attachments = item.attachments else { continue }

            for attachment in attachments {
                // Process different content types
                processAttachment(attachment)
            }
        }
    }

    private func processAttachment(_ attachment: NSItemProvider) {
        // Handle URLs
        if attachment.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            attachment.loadItem(forTypeIdentifier: UTType.url.identifier) { [weak self] item, _ in
                if let url = item as? URL {
                    DispatchQueue.main.async {
                        self?.sharedItems.append(SharedItem(type: .url, content: url))
                        self?.validateContent()
                    }
                }
            }
        }

        // Handle text
        if attachment.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
            attachment.loadItem(forTypeIdentifier: UTType.plainText.identifier) { [weak self] item, _ in
                if let text = item as? String {
                    DispatchQueue.main.async {
                        self?.sharedItems.append(SharedItem(type: .text, content: text))
                        self?.validateContent()
                    }
                }
            }
        }

        // Handle images
        if attachment.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            attachment.loadItem(forTypeIdentifier: UTType.image.identifier) { [weak self] item, _ in
                var image: UIImage?
                if let imageItem = item as? UIImage {
                    image = imageItem
                } else if let url = item as? URL, let data = try? Data(contentsOf: url) {
                    image = UIImage(data: data)
                }

                if let validImage = image {
                    DispatchQueue.main.async {
                        self?.sharedItems.append(SharedItem(type: .image, content: validImage))
                        self?.validateContent()
                    }
                }
            }
        }

        // Handle files
        if attachment.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            attachment.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { [weak self] item, _ in
                if let url = item as? URL {
                    DispatchQueue.main.async {
                        self?.sharedItems.append(SharedItem(type: .file, content: url))
                        self?.validateContent()
                    }
                }
            }
        }
    }

    private func saveSharedContent() throws {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            throw ShareError.noAppGroupContainer
        }

        // Create shared content directory
        let sharedDir = containerURL.appendingPathComponent("SharedContent", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: sharedDir, withIntermediateDirectories: true)
        } catch {
            throw ShareError.directoryCreationFailed(error)
        }

        // Create a unique ID for this share
        let shareID = UUID().uuidString
        let shareDir = sharedDir.appendingPathComponent(shareID, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: shareDir, withIntermediateDirectories: true)
        } catch {
            throw ShareError.directoryCreationFailed(error)
        }

        // Save metadata
        var metadata: [String: Any] = [
            "id": shareID,
            "timestamp": Date().timeIntervalSince1970,
            "userNote": contentText ?? "",
            "items": []
        ]

        var itemsMetadata: [[String: Any]] = []

        for (index, item) in sharedItems.enumerated() {
            var itemMeta: [String: Any] = ["index": index]

            switch item.type {
            case .text:
                itemMeta["type"] = "text"
                itemMeta["content"] = item.content as? String ?? ""

            case .url:
                itemMeta["type"] = "url"
                itemMeta["content"] = (item.content as? URL)?.absoluteString ?? ""

            case .image:
                itemMeta["type"] = "image"
                let imagePath = shareDir.appendingPathComponent("image_\(index).jpg")
                if let image = item.content as? UIImage,
                   let data = image.jpegData(compressionQuality: 0.8)
                {
                    do {
                        try data.write(to: imagePath)
                        itemMeta["path"] = imagePath.lastPathComponent
                        // AAB3-4: Vision OCR — extract text from shared images
                        if let ocrText = performOCR(on: image) {
                            itemMeta["ocrText"] = ocrText
                        }
                    } catch {
                        throw ShareError.imageWriteFailed(index: index, error)
                    }
                }

            case .file:
                itemMeta["type"] = "file"
                if let fileURL = item.content as? URL {
                    let destPath = shareDir.appendingPathComponent(fileURL.lastPathComponent)
                    do {
                        try FileManager.default.copyItem(at: fileURL, to: destPath)
                        itemMeta["path"] = fileURL.lastPathComponent
                    } catch {
                        throw ShareError.fileCopyFailed(filename: fileURL.lastPathComponent, error)
                    }
                }
            }

            itemsMetadata.append(itemMeta)
        }

        metadata["items"] = itemsMetadata

        // Save metadata JSON
        let metadataPath = shareDir.appendingPathComponent("metadata.json")
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: metadata, options: .prettyPrinted)
            try jsonData.write(to: metadataPath)
        } catch {
            throw ShareError.metadataWriteFailed(error)
        }

        // Update the pending shares list
        let pendingPath = sharedDir.appendingPathComponent("pending.json")
        var pending: [String] = []
        // Reading existing pending list is best-effort; start fresh if unreadable
        if let data = try? Data(contentsOf: pendingPath),
           let existing = try? JSONSerialization.jsonObject(with: data) as? [String]
        {
            pending = existing
        }
        pending.append(shareID)
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: pending)
            try jsonData.write(to: pendingPath)
        } catch {
            throw ShareError.pendingListWriteFailed(error)
        }
    }

    // MARK: - Vision OCR (AAB3-4)

    /// Extracts text from an image using VNRecognizeTextRequest (on-device, no network).
    private func performOCR(on image: UIImage) -> String? {
        guard let cgImage = image.cgImage else { return nil }

        var recognizedText: [String] = []
        let semaphore = DispatchSemaphore(value: 0)

        let request = VNRecognizeTextRequest { request, _ in
            defer { semaphore.signal() }
            guard let observations = request.results as? [VNRecognizedTextObservation] else { return }
            recognizedText = observations.compactMap { $0.topCandidates(1).first?.string }
        }
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])
        semaphore.wait()

        let joined = recognizedText.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return joined.isEmpty ? nil : joined
    }

    private func notifyMainApp() {
        // Use Darwin notifications to wake up the main app
        let notificationName = CFNotificationName("app.thea.SharedContent" as CFString)
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            notificationName,
            nil,
            nil,
            true
        )
    }

    private func showActionPicker() {
        let alert = UIAlertController(title: "Action", message: "What should Thea do?", preferredStyle: .actionSheet)

        let actions = [
            "Ask Thea",
            "Summarize",
            "Translate",
            "Add to Memory",
            "Create Artifact"
        ]

        for action in actions {
            alert.addAction(UIAlertAction(title: action, style: .default) { [weak self] _ in
                // Update configuration
                if let item = self?.configurationItems().first as? SLComposeSheetConfigurationItem {
                    item.value = action
                }
                self?.reloadConfigurationItems()
            })
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
        }

        present(alert, animated: true)
    }
}
