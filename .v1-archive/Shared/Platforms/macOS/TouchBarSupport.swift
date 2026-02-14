//
//  TouchBarSupport.swift
//  Thea
//
//  Created by Thea
//  Touch Bar support for MacBook Pro with Touch Bar (legacy)
//

#if os(macOS)
    import AppKit
    import os.log

    // MARK: - Touch Bar Manager

    /// Manages Touch Bar integration for MacBook Pro models with Touch Bar
    @MainActor
    public final class TouchBarManager: NSObject, ObservableObject {
        public static let shared = TouchBarManager()

        private let logger = Logger(subsystem: "app.thea.touchbar", category: "TouchBarManager")

        // MARK: - Touch Bar Items

        private var touchBar: NSTouchBar?

        // Touch Bar Item Identifiers
        public enum TouchBarItem: String {
            case quickAsk = "app.thea.touchbar.quickAsk"
            case voiceInput = "app.thea.touchbar.voiceInput"
            case statusIndicator = "app.thea.touchbar.status"
            case conversationPicker = "app.thea.touchbar.conversations"
            case actionButtons = "app.thea.touchbar.actions"
            case slider = "app.thea.touchbar.slider"

            var identifier: NSTouchBarItem.Identifier {
                NSTouchBarItem.Identifier(rawValue)
            }
        }

        // MARK: - State

        @Published public var isAvailable: Bool = false
        @Published public var currentStatus: TouchBarStatus = .ready

        public enum TouchBarStatus: String {
            case ready = "Ready"
            case thinking = "Thinking..."
            case processing = "Processing..."
            case listening = "Listening..."
            case error = "Error"

            var color: NSColor {
                switch self {
                case .ready: .systemGreen
                case .thinking: .systemBlue
                case .processing: .systemOrange
                case .listening: .systemPurple
                case .error: .systemRed
                }
            }

            var icon: String {
                switch self {
                case .ready: "checkmark.circle.fill"
                case .thinking: "brain"
                case .processing: "gearshape.2"
                case .listening: "ear"
                case .error: "exclamationmark.triangle"
                }
            }
        }

        // MARK: - Callbacks

        public var onQuickAskPressed: (() -> Void)?
        public var onVoiceInputPressed: (() -> Void)?
        public var onConversationSelected: ((String) -> Void)?
        public var onCustomActionPressed: ((String) -> Void)?

        // MARK: - Initialization

        override private init() {
            super.init()
            checkAvailability()
        }

        private func checkAvailability() {
            // Touch Bar is available on certain MacBook Pro models (2016-2020)
            // Check if NSTouchBar class responds to appropriate methods
            isAvailable = NSClassFromString("NSTouchBar") != nil

            if isAvailable {
                logger.info("Touch Bar support available")
            }
        }

        // MARK: - Touch Bar Setup

        /// Create the application Touch Bar
        public func createTouchBar() -> NSTouchBar? {
            guard isAvailable else { return nil }

            let touchBar = NSTouchBar()
            touchBar.delegate = self
            touchBar.customizationIdentifier = NSTouchBar.CustomizationIdentifier("app.thea.touchbar")
            touchBar.defaultItemIdentifiers = [
                TouchBarItem.statusIndicator.identifier,
                .flexibleSpace,
                TouchBarItem.quickAsk.identifier,
                TouchBarItem.voiceInput.identifier,
                .flexibleSpace,
                TouchBarItem.actionButtons.identifier
            ]
            touchBar.customizationAllowedItemIdentifiers = [
                TouchBarItem.statusIndicator.identifier,
                TouchBarItem.quickAsk.identifier,
                TouchBarItem.voiceInput.identifier,
                TouchBarItem.conversationPicker.identifier,
                TouchBarItem.actionButtons.identifier,
                TouchBarItem.slider.identifier
            ]

            self.touchBar = touchBar
            return touchBar
        }

        // MARK: - Status Updates

        public func updateStatus(_ status: TouchBarStatus) {
            currentStatus = status

            // Update the status indicator item if it exists
            if let item = touchBar?.item(forIdentifier: TouchBarItem.statusIndicator.identifier) as? NSCustomTouchBarItem {
                if let button = item.view as? NSButton {
                    button.title = status.rawValue
                    button.image = NSImage(systemSymbolName: status.icon, accessibilityDescription: status.rawValue)
                    button.bezelColor = status.color
                }
            }
        }

        // MARK: - Actions

        @objc private func quickAskAction(_: Any?) {
            logger.debug("Touch Bar: Quick Ask pressed")
            onQuickAskPressed?()
            NotificationCenter.default.post(name: .theaQuickAsk, object: nil)
        }

        @objc private func voiceInputAction(_: Any?) {
            logger.debug("Touch Bar: Voice Input pressed")
            onVoiceInputPressed?()
            NotificationCenter.default.post(name: .theaVoiceInput, object: nil)
        }

        @objc private func screenshotAction(_: Any?) {
            logger.debug("Touch Bar: Screenshot pressed")
            NotificationCenter.default.post(name: .theaScreenshotAsk, object: nil)
        }

        @objc private func focusAction(_: Any?) {
            logger.debug("Touch Bar: Focus pressed")
            NotificationCenter.default.post(name: .theaFocusSession, object: nil)
        }
    }

    // MARK: - NSTouchBarDelegate

    extension TouchBarManager: NSTouchBarDelegate {
        public func touchBar(_: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
            switch identifier {
            case TouchBarItem.statusIndicator.identifier:
                createStatusItem(identifier: identifier)

            case TouchBarItem.quickAsk.identifier:
                createQuickAskItem(identifier: identifier)

            case TouchBarItem.voiceInput.identifier:
                createVoiceInputItem(identifier: identifier)

            case TouchBarItem.actionButtons.identifier:
                createActionButtonsItem(identifier: identifier)

            case TouchBarItem.conversationPicker.identifier:
                createConversationPicker(identifier: identifier)

            case TouchBarItem.slider.identifier:
                createSliderItem(identifier: identifier)

            default:
                nil
            }
        }

        // MARK: - Item Creation

        private func createStatusItem(identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem {
            let item = NSCustomTouchBarItem(identifier: identifier)
            let button = NSButton(
                title: currentStatus.rawValue,
                image: NSImage(systemSymbolName: currentStatus.icon, accessibilityDescription: nil)!,
                target: nil,
                action: nil
            )
            button.imagePosition = .imageLeading
            button.bezelColor = currentStatus.color
            item.view = button
            item.customizationLabel = "Status"
            return item
        }

        private func createQuickAskItem(identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem {
            let item = NSCustomTouchBarItem(identifier: identifier)
            let button = NSButton(
                title: "Ask Thea",
                image: NSImage(systemSymbolName: "bubble.left.fill", accessibilityDescription: nil)!,
                target: self,
                action: #selector(quickAskAction(_:))
            )
            button.imagePosition = .imageLeading
            button.bezelColor = .systemBlue
            item.view = button
            item.customizationLabel = "Quick Ask"
            return item
        }

        private func createVoiceInputItem(identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem {
            let item = NSCustomTouchBarItem(identifier: identifier)
            let button = NSButton(
                image: NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "Voice Input")!,
                target: self,
                action: #selector(voiceInputAction(_:))
            )
            button.bezelColor = .systemPurple
            item.view = button
            item.customizationLabel = "Voice Input"
            return item
        }

        private func createActionButtonsItem(identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem {
            let item = NSCustomTouchBarItem(identifier: identifier)

            let screenshotButton = NSButton(
                image: NSImage(systemSymbolName: "camera.viewfinder", accessibilityDescription: "Screenshot")!,
                target: self,
                action: #selector(screenshotAction(_:))
            )

            let focusButton = NSButton(
                image: NSImage(systemSymbolName: "timer", accessibilityDescription: "Focus")!,
                target: self,
                action: #selector(focusAction(_:))
            )

            let stackView = NSStackView(views: [screenshotButton, focusButton])
            stackView.spacing = 8

            item.view = stackView
            item.customizationLabel = "Actions"
            return item
        }

        private func createConversationPicker(identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem {
            let item = NSPopoverTouchBarItem(identifier: identifier)
            item.customizationLabel = "Conversations"
            item.collapsedRepresentationImage = NSImage(systemSymbolName: "list.bullet", accessibilityDescription: "Conversations")

            // Would populate with recent conversations
            let popoverTouchBar = NSTouchBar()
            popoverTouchBar.delegate = self
            item.popoverTouchBar = popoverTouchBar

            return item
        }

        private func createSliderItem(identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem {
            let item = NSSliderTouchBarItem(identifier: identifier)
            item.label = "Speed"
            item.slider.minValue = 0
            item.slider.maxValue = 100
            item.slider.doubleValue = 50
            item.customizationLabel = "Speed Slider"
            return item
        }
    }

    // MARK: - Additional Notification Names

    public extension Notification.Name {
        static let theaFocusSession = Notification.Name("theaFocusSession")
    }

    // MARK: - Window Controller Extension

    public extension NSWindowController {
        /// Get the Touch Bar for this window
        @MainActor
        var theaTouchBar: NSTouchBar? {
            TouchBarManager.shared.createTouchBar()
        }
    }
#endif
