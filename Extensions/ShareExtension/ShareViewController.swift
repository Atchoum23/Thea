//
//  ShareViewController.swift
//  TheaShareExtension
//
//  Created by Thea
//

import Social
import UIKit
import UniformTypeIdentifiers

/// Share Extension for Thea
/// Allows users to share content from any app to Thea for AI processing
class ShareViewController: SLComposeServiceViewController {
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
    private let appGroupID = "group.app.thea"

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
        saveSharedContent()

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

    private func saveSharedContent() {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            return
        }

        // Create shared content directory
        let sharedDir = containerURL.appendingPathComponent("SharedContent", isDirectory: true)
        try? FileManager.default.createDirectory(at: sharedDir, withIntermediateDirectories: true)

        // Create a unique ID for this share
        let shareID = UUID().uuidString
        let shareDir = sharedDir.appendingPathComponent(shareID, isDirectory: true)
        try? FileManager.default.createDirectory(at: shareDir, withIntermediateDirectories: true)

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
                    try? data.write(to: imagePath)
                    itemMeta["path"] = imagePath.lastPathComponent
                }

            case .file:
                itemMeta["type"] = "file"
                if let fileURL = item.content as? URL {
                    let destPath = shareDir.appendingPathComponent(fileURL.lastPathComponent)
                    try? FileManager.default.copyItem(at: fileURL, to: destPath)
                    itemMeta["path"] = fileURL.lastPathComponent
                }
            }

            itemsMetadata.append(itemMeta)
        }

        metadata["items"] = itemsMetadata

        // Save metadata JSON
        let metadataPath = shareDir.appendingPathComponent("metadata.json")
        if let jsonData = try? JSONSerialization.data(withJSONObject: metadata, options: .prettyPrinted) {
            try? jsonData.write(to: metadataPath)
        }

        // Update the pending shares list
        let pendingPath = sharedDir.appendingPathComponent("pending.json")
        var pending: [String] = []
        if let data = try? Data(contentsOf: pendingPath),
           let existing = try? JSONSerialization.jsonObject(with: data) as? [String]
        {
            pending = existing
        }
        pending.append(shareID)
        if let jsonData = try? JSONSerialization.data(withJSONObject: pending) {
            try? jsonData.write(to: pendingPath)
        }
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
