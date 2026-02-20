//
//  KeyboardViewController.swift
//  TheaKeyboardExtension
//
//  Created by Thea
//

import SwiftUI
import UIKit

/// Thea AI-Powered Keyboard Extension
/// Provides AI assistance directly within any text field
class KeyboardViewController: UIInputViewController {
    // MARK: - Properties

    private var currentText: String = ""
    private var suggestions: [String] = []

    // App Group for shared data
    private let appGroupID = "group.app.theathe"

    // UI Elements
    private var suggestionBar: UIStackView!
    private var aiButton: UIButton!

    // AAB3-5: SwiftUI hosting controller for suggestions bar
    private var suggestionsHostingController: UIHostingController<TheaKeyboardSuggestionsView>?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupKeyboard()
        loadUserPreferences()
    }

    override func textWillChange(_: UITextInput?) {
        // Called when the text is about to change
    }

    override func textDidChange(_: UITextInput?) {
        // Called when the text did change
        updateSuggestions()
    }

    // MARK: - Setup

    private func setupKeyboard() {
        // Create main container
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)

        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.topAnchor.constraint(equalTo: view.topAnchor),
            containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        // Suggestion bar
        setupSuggestionBar(in: containerView)

        // AI button bar
        setupAIBar(in: containerView)

        // Keyboard grid
        setupKeyboardGrid(in: containerView)
    }

    // AAB3-5: SwiftUI suggestions bar via UIHostingController
    private func setupSuggestionBar(in container: UIView) {
        let swiftUIView = TheaKeyboardSuggestionsView(
            suggestions: suggestions,
            onSelect: { [weak self] text in self?.insertText(text) },
            onAIAssist: { [weak self] in self?.aiAssistTapped() }
        )
        let hostingController = UIHostingController(rootView: swiftUIView)
        suggestionsHostingController = hostingController

        addChild(hostingController)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)

        hostingController.view.backgroundColor = .clear

        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: container.topAnchor, constant: 4),
            hostingController.view.heightAnchor.constraint(equalToConstant: 36)
        ])

        // Keep the UIStackView reference valid for layout anchors used below
        suggestionBar = UIStackView()
        suggestionBar.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(suggestionBar)
        NSLayoutConstraint.activate([
            suggestionBar.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            suggestionBar.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            suggestionBar.topAnchor.constraint(equalTo: container.topAnchor, constant: 4),
            suggestionBar.heightAnchor.constraint(equalToConstant: 36)
        ])
        suggestionBar.isHidden = true  // SwiftUI host is the visible layer
    }

    /// Updates the SwiftUI suggestion chips when new suggestions arrive.
    private func updateSuggestionsView() {
        guard let hosting = suggestionsHostingController else { return }
        hosting.rootView = TheaKeyboardSuggestionsView(
            suggestions: suggestions,
            onSelect: { [weak self] text in self?.insertText(text) },
            onAIAssist: { [weak self] in self?.aiAssistTapped() }
        )
    }

    private func setupAIBar(in container: UIView) {
        let aiBar = UIStackView()
        aiBar.axis = .horizontal
        aiBar.spacing = 8
        aiBar.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(aiBar)

        NSLayoutConstraint.activate([
            aiBar.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 4),
            aiBar.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -4),
            aiBar.topAnchor.constraint(equalTo: suggestionBar.bottomAnchor, constant: 4),
            aiBar.heightAnchor.constraint(equalToConstant: 32)
        ])

        // AI quick actions
        let actions = [
            ("sparkles", "AI Assist", #selector(aiAssistTapped)),
            ("doc.on.clipboard", "Paste", #selector(pasteTapped)),
            ("arrow.uturn.backward", "Undo", #selector(undoTapped)),
            ("globe", "Language", #selector(languageTapped))
        ]

        for (icon, title, action) in actions {
            let button = UIButton(type: .system)
            button.setImage(UIImage(systemName: icon), for: .normal)
            button.setTitle(" \(title)", for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 12)
            button.addTarget(self, action: action, for: .touchUpInside)
            button.backgroundColor = UIColor.systemGray5
            button.layer.cornerRadius = 8
            aiBar.addArrangedSubview(button)
        }
    }

    private func setupKeyboardGrid(in container: UIView) {
        let keyboardStack = UIStackView()
        keyboardStack.axis = .vertical
        keyboardStack.spacing = 6
        keyboardStack.distribution = .fillEqually
        keyboardStack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(keyboardStack)

        NSLayoutConstraint.activate([
            keyboardStack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 2),
            keyboardStack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -2),
            keyboardStack.topAnchor.constraint(equalTo: suggestionBar.bottomAnchor, constant: 44),
            keyboardStack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -4)
        ])

        // Keyboard rows
        let rows = [
            ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"],
            ["a", "s", "d", "f", "g", "h", "j", "k", "l"],
            ["⇧", "z", "x", "c", "v", "b", "n", "m", "⌫"],
            ["123", "🌐", "space", ".", "⏎"]
        ]

        for row in rows {
            let rowStack = UIStackView()
            rowStack.axis = .horizontal
            rowStack.spacing = 4
            rowStack.distribution = .fill

            for key in row {
                let button = createKeyButton(title: key)

                // Special key sizing
                if key == "space" {
                    button.widthAnchor.constraint(equalToConstant: 150).isActive = true
                } else if key == "⇧" || key == "⌫" || key == "⏎" {
                    button.widthAnchor.constraint(equalToConstant: 44).isActive = true
                } else if key == "123" || key == "🌐" {
                    button.widthAnchor.constraint(equalToConstant: 40).isActive = true
                }

                rowStack.addArrangedSubview(button)
            }

            keyboardStack.addArrangedSubview(rowStack)
        }
    }

    private func createKeyButton(title: String) -> UIButton {
        let button = UIButton(type: .system)

        if title == "space" {
            button.setTitle("Thea", for: .normal)
        } else {
            button.setTitle(title, for: .normal)
        }

        button.titleLabel?.font = .systemFont(ofSize: 22, weight: .regular)
        button.backgroundColor = UIColor.systemBackground
        button.setTitleColor(.label, for: .normal)
        button.layer.cornerRadius = 5
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 1)
        button.layer.shadowOpacity = 0.2
        button.layer.shadowRadius = 1

        button.addTarget(self, action: #selector(keyPressed(_:)), for: .touchUpInside)

        return button
    }

    private func createSuggestionButton(title: String) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 14)
        button.backgroundColor = UIColor.systemGray6
        button.layer.cornerRadius = 8
        button.addTarget(self, action: #selector(suggestionTapped(_:)), for: .touchUpInside)
        return button
    }

    // MARK: - Key Actions

    @objc private func keyPressed(_ sender: UIButton) {
        guard let title = sender.title(for: .normal) else { return }

        switch title {
        case "⌫":
            textDocumentProxy.deleteBackward()
        case "⏎":
            textDocumentProxy.insertText("\n")
        case "space", "Thea":
            textDocumentProxy.insertText(" ")
        case "⇧":
            // Toggle shift - would implement proper shift handling
            break
        case "123":
            // Switch to numbers - would implement keyboard switching
            break
        case "🌐":
            advanceToNextInputMode()
        default:
            textDocumentProxy.insertText(title)
        }

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    @objc private func suggestionTapped(_ sender: UIButton) {
        guard let suggestion = sender.title(for: .normal), !suggestion.isEmpty else { return }

        // Delete the partial word
        while let char = textDocumentProxy.documentContextBeforeInput?.last,
              char.isLetter
        {
            textDocumentProxy.deleteBackward()
        }

        // Insert the suggestion
        textDocumentProxy.insertText(suggestion + " ")
    }

    @objc private func aiAssistTapped() {
        // Get context and show AI suggestions
        let context = textDocumentProxy.documentContextBeforeInput ?? ""
        showAIAssistMenu(context: context)
    }

    @objc private func pasteTapped() {
        if let clipboard = UIPasteboard.general.string {
            textDocumentProxy.insertText(clipboard)
        }
    }

    @objc private func undoTapped() {
        // Undo functionality
        textDocumentProxy.deleteBackward()
    }

    @objc private func languageTapped() {
        advanceToNextInputMode()
    }

    // MARK: - AI Features

    private func updateSuggestions() {
        // Get current word being typed
        guard let context = textDocumentProxy.documentContextBeforeInput else { return }

        // Simple word completion (would use actual ML model in production)
        let words = context.split(separator: " ")
        guard let lastWord = words.last else { return }

        // Load predictions from shared storage
        loadPredictions(for: String(lastWord))
    }

    private func loadPredictions(for partial: String) {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            return
        }

        let predictionsPath = containerURL.appendingPathComponent("keyboard_predictions.json")

        // Default predictions if no learned data
        var predictions = ["the", "to", "and"]

        if let data = try? Data(contentsOf: predictionsPath),
           let learned = try? JSONDecoder().decode([String: [String]].self, from: data),
           let specific = learned[partial.lowercased()]
        {
            predictions = specific
        }

        // Update UI — SwiftUI suggestions view (AAB3-5) + legacy UIStackView
        DispatchQueue.main.async {
            self.suggestions = predictions
            self.updateSuggestionsView()
        }
    }

    private func showAIAssistMenu(context: String) {
        let alert = UIAlertController(title: "Thea AI", message: "What would you like to do?", preferredStyle: .actionSheet)

        alert.addAction(UIAlertAction(title: "Complete Sentence", style: .default) { [weak self] _ in
            self?.completeWithAI(context: context, action: "complete")
        })

        alert.addAction(UIAlertAction(title: "Fix Grammar", style: .default) { [weak self] _ in
            self?.completeWithAI(context: context, action: "grammar")
        })

        alert.addAction(UIAlertAction(title: "Make Professional", style: .default) { [weak self] _ in
            self?.completeWithAI(context: context, action: "professional")
        })

        alert.addAction(UIAlertAction(title: "Make Casual", style: .default) { [weak self] _ in
            self?.completeWithAI(context: context, action: "casual")
        })

        alert.addAction(UIAlertAction(title: "Translate", style: .default) { [weak self] _ in
            self?.completeWithAI(context: context, action: "translate")
        })

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: 0, width: 0, height: 0)
        }

        present(alert, animated: true)
    }

    private func completeWithAI(context: String, action: String) {
        // Show loading state on suggestion bar
        setSuggestionsLoading(true)

        Task {
            let result = await KeyboardAIService.shared.performAction(context: context, action: action)

            await MainActor.run {
                self.setSuggestionsLoading(false)

                if let text = result {
                    if action == "complete" {
                        // For completion, append the result
                        self.textDocumentProxy.insertText(text)
                    } else {
                        // For rewrites (grammar, professional, casual, translate):
                        // Delete the original context then insert replacement
                        let contextLength = context.count
                        for _ in 0 ..< contextLength {
                            self.textDocumentProxy.deleteBackward()
                        }
                        self.textDocumentProxy.insertText(text)
                    }
                }
            }
        }
    }

    private func setSuggestionsLoading(_ loading: Bool) {
        for view in suggestionBar.arrangedSubviews {
            if let button = view as? UIButton {
                if loading {
                    button.setTitle("···", for: .normal)
                    button.isEnabled = false
                } else {
                    button.isEnabled = true
                }
            }
        }
    }

    private func loadUserPreferences() {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            return
        }

        let prefsPath = containerURL.appendingPathComponent("keyboard_prefs.json")

        // Load and apply preferences
        if let data = try? Data(contentsOf: prefsPath),
           let prefs = try? JSONDecoder().decode(KeyboardPreferences.self, from: data)
        {
            // Apply theme, haptic settings, etc.
            _ = prefs // Silence unused warning for now
        }
    }

    private struct KeyboardPreferences: Codable {
        var enableHaptics: Bool = true
        var theme: String = "system"
        var autoCorrect: Bool = true
    }
}
