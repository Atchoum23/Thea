//
//  TheaKeyboardController.swift
//  Thea
//
//  Main keyboard controller for Thea's AI-powered iOS/iPad keyboard.
//  Handles input, predictions, AI features, and bilingual support.
//
//  Copyright 2026. All rights reserved.
//

#if os(iOS)
import UIKit
import Combine
import NaturalLanguage
import os.log

// MARK: - Keyboard State

/// Current state of the keyboard
public enum KeyboardState: Sendable {
    case alphabetic(shifted: Bool, capsLock: Bool)
    case numeric
    case symbols
    case emoji
}

/// AI action that can be triggered from the keyboard
public enum KeyboardAIAction: String, Sendable, CaseIterable {
    case rewrite = "rewrite"
    case summarize = "summarize"
    case expand = "expand"
    case translate = "translate"
    case fixGrammar = "fix_grammar"
    case makeList = "make_list"
    case askAI = "ask_ai"

    public var displayName: String {
        switch self {
        case .rewrite: "Rewrite"
        case .summarize: "Summarize"
        case .expand: "Expand"
        case .translate: "Translate"
        case .fixGrammar: "Fix Grammar"
        case .makeList: "Make List"
        case .askAI: "Ask Thea"
        }
    }

    public var icon: String {
        switch self {
        case .rewrite: "arrow.triangle.2.circlepath"
        case .summarize: "text.badge.minus"
        case .expand: "text.badge.plus"
        case .translate: "globe"
        case .fixGrammar: "checkmark.circle"
        case .makeList: "list.bullet"
        case .askAI: "sparkles"
        }
    }
}

// MARK: - Keyboard Controller

/// Main controller for the Thea keyboard
@MainActor
public final class TheaKeyboardController: ObservableObject {
    private let logger = Logger(subsystem: "ai.thea.app", category: "Keyboard")

    // MARK: - Published State

    /// Current keyboard state
    @Published public private(set) var state: KeyboardState = .alphabetic(shifted: false, capsLock: false)

    /// Current keyboard configuration
    @Published public var configuration: TheaKeyboardConfiguration

    /// Current input text (for predictions)
    @Published public private(set) var currentInput: String = ""

    /// Word predictions
    @Published public private(set) var predictions: [String] = []

    /// Smart reply suggestions
    @Published public private(set) var smartReplies: [String] = []

    /// Whether AI action panel is shown
    @Published public var showingAIActions: Bool = false

    /// Detected language of current input
    @Published public private(set) var detectedLanguage: KeyboardLanguage?

    /// Whether keyboard is in bilingual mode
    @Published public var bilingualActive: Bool = true

    // MARK: - Private State

    private var textDocumentProxy: UITextDocumentProxy?
    private var cancellables = Set<AnyCancellable>()
    private let predictionEngine: KeyboardPredictionEngine
    private var lastTypedWord: String = ""

    // MARK: - Initialization

    public init(configuration: TheaKeyboardConfiguration = TheaKeyboardConfiguration()) {
        self.configuration = configuration
        self.predictionEngine = KeyboardPredictionEngine(
            primaryLanguage: configuration.primaryLanguage,
            secondaryLanguage: configuration.secondaryLanguage
        )

        setupBindings()
        logger.info("TheaKeyboardController initialized with layout: \(configuration.primaryLayout.displayName)")
    }

    private func setupBindings() {
        // Update predictions when input changes
        $currentInput
            .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
            .sink { [weak self] input in
                Task { await self?.updatePredictions(for: input) }
            }
            .store(in: &cancellables)
    }

    // MARK: - Public API

    /// Set the text document proxy for input
    public func setTextDocumentProxy(_ proxy: UITextDocumentProxy) {
        self.textDocumentProxy = proxy
        updateCurrentInput()
    }

    /// Handle key press
    public func handleKeyPress(_ key: KeyDefinition) {
        switch key.type {
        case .character:
            insertCharacter(key)

        case .shift:
            toggleShift()

        case .backspace:
            deleteBackward()

        case .returnKey:
            insertNewline()

        case .space:
            insertSpace()

        case .switchLayout:
            switchLayout()

        case .emoji:
            state = .emoji

        case .globe:
            switchLanguage()

        case .dictation:
            startDictation()

        case .aiAction:
            showingAIActions = true
        }

        // Generate haptic feedback if enabled
        if configuration.haptics.keyPressEnabled {
            generateHapticFeedback()
        }
    }

    /// Handle long press on key (show alternates)
    public func handleLongPress(_ key: KeyDefinition) -> [String] {
        guard configuration.appearance.showAlternatesPopup else { return [] }
        return key.alternates
    }

    /// Insert an alternate character
    public func insertAlternate(_ character: String) {
        textDocumentProxy?.insertText(character)
        updateCurrentInput()
    }

    /// Select a prediction
    public func selectPrediction(_ prediction: String) {
        // Delete current partial word
        deleteCurrentWord()

        // Insert prediction with space
        textDocumentProxy?.insertText(prediction + " ")
        updateCurrentInput()

        // Auto-shift after sentence-ending punctuation
        if prediction.hasSuffix(".") || prediction.hasSuffix("!") || prediction.hasSuffix("?") {
            state = .alphabetic(shifted: true, capsLock: false)
        }
    }

    /// Perform AI action on selected text via App Group shared container
    public func performAIAction(_ action: KeyboardAIAction) async -> String? {
        guard let selectedText = textDocumentProxy?.selectedText,
              !selectedText.isEmpty else {
            return nil
        }

        showingAIActions = false
        logger.info("AI action requested: \(action.rawValue) on text: \(selectedText.prefix(50))...")

        // Queue the AI request via shared App Group UserDefaults
        // The main Thea app processes queued requests on next launch
        guard let sharedDefaults = UserDefaults(suiteName: "group.app.theathe") else {
            logger.warning("Could not access shared App Group defaults")
            return nil
        }

        let requestId = UUID().uuidString
        let request: [String: String] = [
            "id": requestId,
            "action": action.rawValue,
            "text": String(selectedText.prefix(5000)),
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]

        // Store the request for the main app to process
        var pending = sharedDefaults.array(forKey: "keyboard.ai.pendingRequests") as? [[String: String]] ?? []
        pending.append(request)
        sharedDefaults.set(pending, forKey: "keyboard.ai.pendingRequests")

        // Check if a previous result is available for this action+text combo
        let cacheKey = "keyboard.ai.cache.\(action.rawValue).\(selectedText.hashValue)"
        if let cached = sharedDefaults.string(forKey: cacheKey) {
            return cached
        }

        return nil
    }

    /// Get current layout rows
    public var layoutRows: [[KeyDefinition]] {
        switch state {
        case .alphabetic:
            return configuration.primaryLayout.rows
        case .numeric:
            return numericRows
        case .symbols:
            return symbolRows
        case .emoji:
            return [] // Emoji handled separately
        }
    }

    // MARK: - Private Methods

    private func insertCharacter(_ key: KeyDefinition) {
        let character: String
        switch state {
        case .alphabetic(let shifted, let capsLock):
            if shifted || capsLock {
                character = key.shifted ?? key.primary.uppercased()
            } else {
                character = key.primary
            }

            // Auto-unshift after typing (unless caps lock)
            if shifted && !capsLock {
                state = .alphabetic(shifted: false, capsLock: false)
            }

        default:
            character = key.primary
        }

        textDocumentProxy?.insertText(character)
        updateCurrentInput()
    }

    private func toggleShift() {
        switch state {
        case .alphabetic(let shifted, let capsLock):
            if capsLock {
                // Caps lock on -> turn off
                state = .alphabetic(shifted: false, capsLock: false)
            } else if shifted {
                // Shifted -> caps lock
                state = .alphabetic(shifted: true, capsLock: true)
            } else {
                // Normal -> shifted
                state = .alphabetic(shifted: true, capsLock: false)
            }
        default:
            break
        }
    }

    private func deleteBackward() {
        textDocumentProxy?.deleteBackward()
        updateCurrentInput()
    }

    private func insertNewline() {
        textDocumentProxy?.insertText("\n")
        state = .alphabetic(shifted: true, capsLock: false)
        updateCurrentInput()
    }

    private func insertSpace() {
        // Double-space for period (common iOS behavior)
        if lastTypedWord.hasSuffix(" ") {
            textDocumentProxy?.deleteBackward()
            textDocumentProxy?.insertText(". ")
            state = .alphabetic(shifted: true, capsLock: false)
        } else {
            textDocumentProxy?.insertText(" ")
        }
        updateCurrentInput()
    }

    private func switchLayout() {
        switch state {
        case .alphabetic:
            state = .numeric
        case .numeric:
            state = .symbols
        case .symbols, .emoji:
            state = .alphabetic(shifted: false, capsLock: false)
        }
    }

    private func switchLanguage() {
        // Toggle between primary and secondary layout
        if let secondary = configuration.secondaryLayout {
            let temp = configuration.primaryLayout
            configuration.primaryLayout = secondary
            configuration.secondaryLayout = temp
        }

        // Also swap languages
        if let secondaryLang = configuration.secondaryLanguage {
            let temp = configuration.primaryLanguage
            configuration.primaryLanguage = secondaryLang
            configuration.secondaryLanguage = temp
        }

        logger.info("Switched to layout: \(self.configuration.primaryLayout.displayName)")
    }

    private func startDictation() {
        // Would trigger system dictation or Whisper integration
        logger.info("Dictation requested")
    }

    private func updateCurrentInput() {
        guard let proxy = textDocumentProxy else { return }

        // Get text before cursor
        let beforeCursor = proxy.documentContextBeforeInput ?? ""

        // Extract current word (last word being typed)
        let words = beforeCursor.components(separatedBy: .whitespacesAndNewlines)
        currentInput = words.last ?? ""
        lastTypedWord = beforeCursor.suffix(2).description
    }

    private func deleteCurrentWord() {
        guard !currentInput.isEmpty else { return }
        for _ in 0..<currentInput.count {
            textDocumentProxy?.deleteBackward()
        }
    }

    private func updatePredictions(for input: String) async {
        guard configuration.aiFeatures.predictionsEnabled else {
            predictions = []
            return
        }

        predictions = await predictionEngine.getPredictions(
            for: input,
            context: textDocumentProxy?.documentContextBeforeInput,
            maxResults: configuration.aiFeatures.maxPredictions
        )

        // Detect language if bilingual mode is active
        if configuration.bilingualModeEnabled {
            detectedLanguage = await predictionEngine.detectLanguage(
                text: textDocumentProxy?.documentContextBeforeInput ?? input
            )
        }
    }

    private func generateHapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred(intensity: configuration.haptics.intensity)
    }

    // MARK: - Numeric & Symbol Layouts

    private var numericRows: [[KeyDefinition]] {
        [
            [
                KeyDefinition(primary: "1"),
                KeyDefinition(primary: "2"),
                KeyDefinition(primary: "3"),
                KeyDefinition(primary: "4"),
                KeyDefinition(primary: "5"),
                KeyDefinition(primary: "6"),
                KeyDefinition(primary: "7"),
                KeyDefinition(primary: "8"),
                KeyDefinition(primary: "9"),
                KeyDefinition(primary: "0")
            ],
            [
                KeyDefinition(primary: "-"),
                KeyDefinition(primary: "/"),
                KeyDefinition(primary: ":"),
                KeyDefinition(primary: ";"),
                KeyDefinition(primary: "("),
                KeyDefinition(primary: ")"),
                KeyDefinition(primary: "$"),
                KeyDefinition(primary: "&"),
                KeyDefinition(primary: "@"),
                KeyDefinition(primary: "\"")
            ],
            [
                KeyDefinition.special(.switchLayout, label: "#+=", width: .wide),
                KeyDefinition(primary: "."),
                KeyDefinition(primary: ","),
                KeyDefinition(primary: "?"),
                KeyDefinition(primary: "!"),
                KeyDefinition(primary: "'"),
                KeyDefinition.special(.backspace, label: "⌫", width: .wide)
            ],
            [
                KeyDefinition.special(.switchLayout, label: "ABC", width: .wide),
                KeyDefinition.special(.globe, label: "🌐"),
                KeyDefinition.special(.space, label: "space", width: .space),
                KeyDefinition.special(.returnKey, label: "⏎", width: .wide)
            ]
        ]
    }

    private var symbolRows: [[KeyDefinition]] {
        [
            [
                KeyDefinition(primary: "["),
                KeyDefinition(primary: "]"),
                KeyDefinition(primary: "{"),
                KeyDefinition(primary: "}"),
                KeyDefinition(primary: "#"),
                KeyDefinition(primary: "%"),
                KeyDefinition(primary: "^"),
                KeyDefinition(primary: "*"),
                KeyDefinition(primary: "+"),
                KeyDefinition(primary: "=")
            ],
            [
                KeyDefinition(primary: "_"),
                KeyDefinition(primary: "\\"),
                KeyDefinition(primary: "|"),
                KeyDefinition(primary: "~"),
                KeyDefinition(primary: "<"),
                KeyDefinition(primary: ">"),
                KeyDefinition(primary: "€"),
                KeyDefinition(primary: "£"),
                KeyDefinition(primary: "¥"),
                KeyDefinition(primary: "•")
            ],
            [
                KeyDefinition.special(.switchLayout, label: "123", width: .wide),
                KeyDefinition(primary: "."),
                KeyDefinition(primary: ","),
                KeyDefinition(primary: "?"),
                KeyDefinition(primary: "!"),
                KeyDefinition(primary: "'"),
                KeyDefinition.special(.backspace, label: "⌫", width: .wide)
            ],
            [
                KeyDefinition.special(.switchLayout, label: "ABC", width: .wide),
                KeyDefinition.special(.globe, label: "🌐"),
                KeyDefinition.special(.space, label: "space", width: .space),
                KeyDefinition.special(.returnKey, label: "⏎", width: .wide)
            ]
        ]
    }
}

// MARK: - Prediction Engine

/// Engine for keyboard predictions
actor KeyboardPredictionEngine {
    private var primaryLanguage: KeyboardLanguage
    private var secondaryLanguage: KeyboardLanguage?

    init(primaryLanguage: KeyboardLanguage, secondaryLanguage: KeyboardLanguage?) {
        self.primaryLanguage = primaryLanguage
        self.secondaryLanguage = secondaryLanguage
    }

    func getPredictions(for input: String, context _: String?, maxResults: Int) async -> [String] {
        guard !input.isEmpty else { return [] }

        let checker = UITextChecker()
        let languageCode = primaryLanguage.rawValue
        let range = NSRange(location: 0, length: input.utf16.count)

        // Get completions from UITextChecker (Apple's built-in autocomplete)
        let completions = checker.completions(
            forPartialWordRange: range,
            in: input,
            language: languageCode
        ) ?? []

        var results = Array(completions.prefix(maxResults))

        // Also check secondary language completions
        if let secondary = secondaryLanguage {
            let secondaryCompletions = checker.completions(
                forPartialWordRange: range,
                in: input,
                language: secondary.rawValue
            ) ?? []
            for completion in secondaryCompletions.prefix(max(1, maxResults - results.count)) {
                if !results.contains(completion) {
                    results.append(completion)
                }
            }
        }

        return Array(results.prefix(maxResults))
    }

    func detectLanguage(text: String) async -> KeyboardLanguage? {
        guard !text.isEmpty else { return nil }

        // Use rawValue mapping: KeyboardLanguage cases match BCP-47 language codes
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        guard let dominant = recognizer.dominantLanguage else { return nil }

        // Map NLLanguage raw value to KeyboardLanguage
        return KeyboardLanguage.allCases.first { $0.rawValue == dominant.rawValue }
    }

    func updateLanguages(primary: KeyboardLanguage, secondary: KeyboardLanguage?) {
        self.primaryLanguage = primary
        self.secondaryLanguage = secondary
    }
}
#endif
