//
//  PreviewViewController.swift
//  TheaQuickLookExtension
//
//  Created by Thea
//

#if os(macOS)
    import Cocoa
    import os.log
    @preconcurrency import Quartz

    /// Quick Look Preview Extension for Thea
    /// Provides AI-enhanced previews of Thea artifacts and conversations
    class PreviewViewController: NSViewController, QLPreviewingController {
        nonisolated static let _qlPreviewingControllerConformance = true

        private let logger = Logger(subsystem: "app.thea.quicklook", category: "Preview")
        private let appGroupID = "group.app.thea"

        // UI Elements
        private var scrollView: NSScrollView!
        private var contentView: NSView!
        private var titleLabel: NSTextField!
        private var subtitleLabel: NSTextField!
        private var bodyTextView: NSTextView!
        private var iconView: NSImageView!
        private var metadataStack: NSStackView!

        override var nibName: NSNib.Name? {
            nil
        }

        override func loadView() {
            view = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
            setupUI()
        }

        private func setupUI() {
            view.wantsLayer = true
            view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

            // Scroll view for content
            scrollView = NSScrollView()
            scrollView.translatesAutoresizingMaskIntoConstraints = false
            scrollView.hasVerticalScroller = true
            scrollView.autohidesScrollers = true
            view.addSubview(scrollView)

            // Content container
            contentView = NSView()
            contentView.translatesAutoresizingMaskIntoConstraints = false
            scrollView.documentView = contentView

            // Header section
            let headerView = createHeaderView()
            contentView.addSubview(headerView)

            // Body text view
            let textContainer = NSTextContainer()
            let layoutManager = NSLayoutManager()
            let textStorage = NSTextStorage()
            textStorage.addLayoutManager(layoutManager)
            layoutManager.addTextContainer(textContainer)

            bodyTextView = NSTextView(frame: .zero, textContainer: textContainer)
            bodyTextView.translatesAutoresizingMaskIntoConstraints = false
            bodyTextView.isEditable = false
            bodyTextView.isSelectable = true
            bodyTextView.backgroundColor = .clear
            bodyTextView.font = .systemFont(ofSize: 13)
            bodyTextView.textColor = .labelColor
            contentView.addSubview(bodyTextView)

            // Metadata section
            metadataStack = NSStackView()
            metadataStack.translatesAutoresizingMaskIntoConstraints = false
            metadataStack.orientation = .vertical
            metadataStack.alignment = .leading
            metadataStack.spacing = 4
            contentView.addSubview(metadataStack)

            NSLayoutConstraint.activate([
                scrollView.topAnchor.constraint(equalTo: view.topAnchor),
                scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

                contentView.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
                contentView.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
                contentView.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
                contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),

                headerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
                headerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
                headerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

                bodyTextView.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 16),
                bodyTextView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
                bodyTextView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

                metadataStack.topAnchor.constraint(equalTo: bodyTextView.bottomAnchor, constant: 16),
                metadataStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
                metadataStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
                metadataStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
            ])
        }

        private func createHeaderView() -> NSView {
            let headerView = NSView()
            headerView.translatesAutoresizingMaskIntoConstraints = false

            // Icon
            iconView = NSImageView()
            iconView.translatesAutoresizingMaskIntoConstraints = false
            iconView.imageScaling = .scaleProportionallyUpOrDown
            iconView.contentTintColor = .systemPurple
            headerView.addSubview(iconView)

            // Title
            titleLabel = NSTextField(labelWithString: "")
            titleLabel.translatesAutoresizingMaskIntoConstraints = false
            titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
            titleLabel.textColor = .labelColor
            headerView.addSubview(titleLabel)

            // Subtitle
            subtitleLabel = NSTextField(labelWithString: "")
            subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
            subtitleLabel.font = .systemFont(ofSize: 12)
            subtitleLabel.textColor = .secondaryLabelColor
            headerView.addSubview(subtitleLabel)

            NSLayoutConstraint.activate([
                iconView.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
                iconView.topAnchor.constraint(equalTo: headerView.topAnchor),
                iconView.widthAnchor.constraint(equalToConstant: 48),
                iconView.heightAnchor.constraint(equalToConstant: 48),

                titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
                titleLabel.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 4),
                titleLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),

                subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
                subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
                subtitleLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),

                headerView.heightAnchor.constraint(equalToConstant: 60)
            ])

            return headerView
        }

        // MARK: - QLPreviewingController

        nonisolated func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping @Sendable (Error?) -> Void) {
            // Load data synchronously and update UI on main queue
            do {
                let data = try Data(contentsOf: url)

                DispatchQueue.main.async { [weak self] in
                    guard let self else {
                        handler(QLPreviewError.unsupportedContent)
                        return
                    }
                    self.handlePreviewOfFile(data: data, url: url, completionHandler: handler)
                }
            } catch {
                DispatchQueue.main.async {
                    handler(error)
                }
            }
        }

        private func handlePreviewOfFile(data: Data, url: URL, completionHandler handler: @escaping @Sendable (Error?) -> Void) {
            logger.info("Preparing preview for: \(url.path)")

            // Try to decode as Thea artifact
            if let artifact = try? JSONDecoder().decode(TheaArtifact.self, from: data) {
                displayArtifact(artifact)
                handler(nil)
                return
            }

            // Try to decode as conversation
            if let conversation = try? JSONDecoder().decode(TheaConversation.self, from: data) {
                displayConversation(conversation)
                handler(nil)
                return
            }

            // Try to decode as memory
            if let memory = try? JSONDecoder().decode(TheaMemory.self, from: data) {
                displayMemory(memory)
                handler(nil)
                return
            }

            // Fallback: display as plain text
            if let text = String(data: data, encoding: .utf8) {
                displayPlainText(text, filename: url.lastPathComponent)
                handler(nil)
                return
            }

            handler(QLPreviewError.unsupportedContent)
        }

        // MARK: - Display Methods

        private func displayArtifact(_ artifact: TheaArtifact) {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }

                self.iconView.image = NSImage(systemSymbolName: "doc.text.fill", accessibilityDescription: nil)
                self.titleLabel.stringValue = artifact.title
                self.subtitleLabel.stringValue = "Thea Artifact • \(artifact.type.capitalized)"
                self.bodyTextView.string = artifact.content

                self.addMetadata([
                    ("Created", self.formatDate(artifact.created)),
                    ("Modified", self.formatDate(artifact.modified)),
                    ("Tags", artifact.tags.joined(separator: ", "))
                ])
            }
        }

        private func displayConversation(_ conversation: TheaConversation) {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }

                self.iconView.image = NSImage(systemSymbolName: "bubble.left.and.bubble.right.fill", accessibilityDescription: nil)
                self.titleLabel.stringValue = conversation.title
                self.subtitleLabel.stringValue = "Conversation • \(conversation.messages.count) messages"

                // Format conversation
                var formattedText = ""
                for message in conversation.messages {
                    let role = message.role == "user" ? "You" : "Thea"
                    formattedText += "[\(role)]\n\(message.content)\n\n"
                }
                self.bodyTextView.string = formattedText

                self.addMetadata([
                    ("Started", self.formatDate(conversation.created)),
                    ("Duration", self.formatDuration(from: conversation.created, to: conversation.lastActive))
                ])
            }
        }

        private func displayMemory(_ memory: TheaMemory) {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }

                self.iconView.image = NSImage(systemSymbolName: "brain.head.profile", accessibilityDescription: nil)
                self.titleLabel.stringValue = memory.title ?? "Memory"
                self.subtitleLabel.stringValue = "Thea Memory • \(memory.category)"
                self.bodyTextView.string = memory.content

                self.addMetadata([
                    ("Saved", self.formatDate(memory.created)),
                    ("Importance", "\(memory.importance)/10"),
                    ("Source", memory.source ?? "Unknown")
                ])
            }
        }

        private func displayPlainText(_ text: String, filename: String) {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }

                self.iconView.image = NSImage(systemSymbolName: "doc.text", accessibilityDescription: nil)
                self.titleLabel.stringValue = filename
                self.subtitleLabel.stringValue = "Text File"
                self.bodyTextView.string = text
            }
        }

        private func addMetadata(_ items: [(String, String)]) {
            metadataStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

            // Add separator
            let separator = NSBox()
            separator.boxType = .separator
            metadataStack.addArrangedSubview(separator)

            for (label, value) in items {
                let row = NSStackView()
                row.orientation = .horizontal
                row.spacing = 8

                let labelField = NSTextField(labelWithString: label + ":")
                labelField.font = .systemFont(ofSize: 11, weight: .medium)
                labelField.textColor = .secondaryLabelColor

                let valueField = NSTextField(labelWithString: value)
                valueField.font = .systemFont(ofSize: 11)
                valueField.textColor = .labelColor

                row.addArrangedSubview(labelField)
                row.addArrangedSubview(valueField)

                metadataStack.addArrangedSubview(row)
            }
        }

        // MARK: - Helpers

        private func formatDate(_ date: Date) -> String {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }

        private func formatDuration(from start: Date, to end: Date) -> String {
            let interval = end.timeIntervalSince(start)
            let hours = Int(interval) / 3600
            let minutes = (Int(interval) % 3600) / 60

            if hours > 0 {
                return "\(hours)h \(minutes)m"
            } else {
                return "\(minutes)m"
            }
        }
    }

    // MARK: - Quick Look Error

    enum QLPreviewError: Error {
        case unsupportedContent
    }

    // MARK: - Data Models

    struct TheaArtifact: Codable {
        let id: String
        let title: String
        let type: String
        let content: String
        let created: Date
        let modified: Date
        let tags: [String]
    }

    struct TheaConversation: Codable {
        let id: String
        let title: String
        let messages: [TheaMessage]
        let created: Date
        let lastActive: Date
    }

    struct TheaMessage: Codable {
        let role: String
        let content: String
        let timestamp: Date
    }

    struct TheaMemory: Codable {
        let id: String
        let title: String?
        let content: String
        let category: String
        let importance: Int
        let source: String?
        let created: Date
    }
#endif
