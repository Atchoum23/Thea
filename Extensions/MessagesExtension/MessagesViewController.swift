//
//  MessagesViewController.swift
//  Thea Messages Extension
//
//  Created by Thea
//  iMessage app integration for AI-powered messaging
//

import Messages
import os.log
import UIKit

/// Messages extension view controller for iMessage integration
class MessagesViewController: MSMessagesAppViewController {
    private let logger = Logger(subsystem: "app.thea.messages", category: "MessagesExtension")

    // MARK: - UI Components

    private lazy var containerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private lazy var suggestionCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumInteritemSpacing = 8
        layout.minimumLineSpacing = 8

        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.translatesAutoresizingMaskIntoConstraints = false
        cv.backgroundColor = .clear
        cv.showsHorizontalScrollIndicator = false
        cv.delegate = self
        cv.dataSource = self
        cv.register(SuggestionCell.self, forCellWithReuseIdentifier: "SuggestionCell")
        return cv
    }()

    private lazy var inputTextField: UITextField = {
        let tf = UITextField()
        tf.translatesAutoresizingMaskIntoConstraints = false
        tf.placeholder = "Ask Thea for a response..."
        tf.borderStyle = .roundedRect
        tf.returnKeyType = .send
        tf.delegate = self
        return tf
    }()

    private lazy var generateButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Generate", for: .normal)
        button.addTarget(self, action: #selector(generateTapped), for: .touchUpInside)
        return button
    }()

    // MARK: - Data

    private var suggestions: [MessageSuggestion] = []
    private var conversationContext: String = ""

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadSuggestions()
    }

    // MARK: - MSMessagesAppViewController

    override func willBecomeActive(with conversation: MSConversation) {
        super.willBecomeActive(with: conversation)
        logger.info("Messages extension becoming active")

        // Extract conversation context
        extractConversationContext(from: conversation)

        // Generate contextual suggestions
        generateContextualSuggestions()
    }

    override func didResignActive(with conversation: MSConversation) {
        super.didResignActive(with: conversation)
        logger.info("Messages extension resigning active")
    }

    override func didReceive(_ message: MSMessage, conversation: MSConversation) {
        super.didReceive(message, conversation: conversation)

        // Process received message for context
        if let url = message.url {
            logger.debug("Received message with URL: \(url)")
        }
    }

    override func didSelect(_ message: MSMessage, conversation: MSConversation) {
        super.didSelect(message, conversation: conversation)

        // Handle message selection
        if let layout = message.layout as? MSMessageTemplateLayout {
            logger.debug("Selected message with caption: \(layout.caption ?? "none")")
        }
    }

    override func willTransition(to presentationStyle: MSMessagesAppPresentationStyle) {
        super.willTransition(to: presentationStyle)

        // Adjust UI based on presentation style
        switch presentationStyle {
        case .compact:
            showCompactUI()
        case .expanded:
            showExpandedUI()
        case .transcript:
            break
        @unknown default:
            break
        }
    }

    // MARK: - UI Setup

    private func setupUI() {
        view.addSubview(containerView)
        containerView.addSubview(suggestionCollectionView)
        containerView.addSubview(inputTextField)
        containerView.addSubview(generateButton)

        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            containerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),

            suggestionCollectionView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 8),
            suggestionCollectionView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            suggestionCollectionView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            suggestionCollectionView.heightAnchor.constraint(equalToConstant: 44),

            inputTextField.topAnchor.constraint(equalTo: suggestionCollectionView.bottomAnchor, constant: 12),
            inputTextField.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            inputTextField.trailingAnchor.constraint(equalTo: generateButton.leadingAnchor, constant: -8),

            generateButton.centerYAnchor.constraint(equalTo: inputTextField.centerYAnchor),
            generateButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            generateButton.widthAnchor.constraint(equalToConstant: 80)
        ])
    }

    private func showCompactUI() {
        inputTextField.isHidden = true
        generateButton.isHidden = true
    }

    private func showExpandedUI() {
        inputTextField.isHidden = false
        generateButton.isHidden = false
    }

    // MARK: - Suggestions

    private func loadSuggestions() {
        // Load default quick suggestions
        suggestions = [
            MessageSuggestion(text: "👍 Sounds good!", type: .quickReply),
            MessageSuggestion(text: "Let me check...", type: .quickReply),
            MessageSuggestion(text: "Thanks!", type: .quickReply),
            MessageSuggestion(text: "On my way!", type: .quickReply)
        ]

        suggestionCollectionView.reloadData()
    }

    private func extractConversationContext(from conversation: MSConversation) {
        // In a real implementation, you would analyze recent messages
        // For privacy, we only get limited context
        if let selectedMessage = conversation.selectedMessage,
           let layout = selectedMessage.layout as? MSMessageTemplateLayout
        {
            conversationContext = layout.caption ?? ""
        }
    }

    private func generateContextualSuggestions() {
        // Generate AI-powered suggestions based on context
        // This would connect to Thea's AI backend

        let contextualSuggestions: [MessageSuggestion] = [
            MessageSuggestion(text: "Generate response", type: .aiGenerated),
            MessageSuggestion(text: "Summarize", type: .aiGenerated),
            MessageSuggestion(text: "Translate", type: .aiGenerated)
        ]

        suggestions.append(contentsOf: contextualSuggestions)
        suggestionCollectionView.reloadData()
    }

    // MARK: - Actions

    @objc private func generateTapped() {
        guard let prompt = inputTextField.text, !prompt.isEmpty else { return }

        // Generate AI response
        generateAIResponse(prompt: prompt)
    }

    private func generateAIResponse(prompt: String) {
        // Create an MSMessage with a deep link URL that the main Thea app processes
        // Messages extensions cannot run AI models directly — they forward via URL scheme

        guard let conversation = activeConversation else { return }

        let message = MSMessage()
        let layout = MSMessageTemplateLayout()
        layout.caption = "✨ Thea suggests:"
        layout.subcaption = "Tap to view AI response"
        layout.image = UIImage(systemName: "sparkles")

        message.layout = layout

        // Create URL with the prompt for the main app to process
        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "action", value: "generate"),
            URLQueryItem(name: "prompt", value: prompt)
        ]
        message.url = components.url

        conversation.insert(message) { [weak self] error in
            if let error {
                self?.logger.error("Failed to insert message: \(error)")
            } else {
                self?.inputTextField.text = ""
            }
        }
    }

    private func sendQuickReply(_ text: String) {
        guard let conversation = activeConversation else { return }

        // For quick replies, we can insert directly into the input field
        // or send as a message

        let message = MSMessage()
        let layout = MSMessageTemplateLayout()
        layout.caption = text

        message.layout = layout

        conversation.insert(message) { [weak self] error in
            if let error {
                self?.logger.error("Failed to send quick reply: \(error)")
            }
        }
    }
}

// MARK: - UICollectionViewDataSource

extension MessagesViewController: UICollectionViewDataSource {
    func collectionView(_: UICollectionView, numberOfItemsInSection _: Int) -> Int {
        suggestions.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "SuggestionCell", for: indexPath) as! SuggestionCell
        let suggestion = suggestions[indexPath.item]
        cell.configure(with: suggestion)
        return cell
    }
}

// MARK: - UICollectionViewDelegate

extension MessagesViewController: UICollectionViewDelegate {
    func collectionView(_: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let suggestion = suggestions[indexPath.item]

        switch suggestion.type {
        case .quickReply:
            sendQuickReply(suggestion.text)
        case .aiGenerated:
            requestPresentationStyle(.expanded)
            inputTextField.text = suggestion.text
        }
    }
}

// MARK: - UICollectionViewDelegateFlowLayout

extension MessagesViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_: UICollectionView, layout _: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let suggestion = suggestions[indexPath.item]
        let width = suggestion.text.size(withAttributes: [.font: UIFont.systemFont(ofSize: 14)]).width + 24
        return CGSize(width: min(width, 150), height: 36)
    }
}

// MARK: - UITextFieldDelegate

extension MessagesViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_: UITextField) -> Bool {
        generateTapped()
        return true
    }
}

// MARK: - Supporting Types

struct MessageSuggestion {
    let text: String
    let type: SuggestionType

    enum SuggestionType {
        case quickReply
        case aiGenerated
    }
}

// MARK: - Suggestion Cell

class SuggestionCell: UICollectionViewCell {
    private let label: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.font = .systemFont(ofSize: 14)
        l.textAlignment = .center
        return l
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        contentView.backgroundColor = .systemGray5
        contentView.layer.cornerRadius = 18
        contentView.clipsToBounds = true

        contentView.addSubview(label)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -12)
        ])
    }

    func configure(with suggestion: MessageSuggestion) {
        label.text = suggestion.text

        switch suggestion.type {
        case .quickReply:
            contentView.backgroundColor = .systemGray5
            label.textColor = .label
        case .aiGenerated:
            contentView.backgroundColor = .systemBlue.withAlphaComponent(0.2)
            label.textColor = .systemBlue
        }
    }
}
