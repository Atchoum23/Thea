//
//  AccessibilityObserver.swift
//  Thea
//
//  Created by Thea
//  Deep System Awareness - Accessibility Integration
//

#if os(macOS)
    import AppKit
    import Foundation
    import os.log

    // MARK: - Accessibility Observer

    /// Observes system-wide accessibility events for deep context awareness
    /// Requires Accessibility permission to be granted by the user
    public final class AccessibilityObserver: @unchecked Sendable {
        public static let shared = AccessibilityObserver()

        private let logger = Logger(subsystem: "app.thea", category: "AccessibilityObserver")
        private var isRunning = false
        private let queue = DispatchQueue(label: "app.thea.accessibility", qos: .userInitiated)

        // Observation state
        private var focusedWindowObserver: AnyObject?
        private var focusedAppObserver: AnyObject?
        private var frontmostApp: NSRunningApplication?

        // Callbacks
        public var onWindowFocusChanged: ((WindowFocusInfo) -> Void)?
        public var onAppFocusChanged: ((AppFocusInfo) -> Void)?
        public var onTextSelectionChanged: ((TextSelectionInfo) -> Void)?
        public var onUIElementChanged: ((AccessibilityElementInfo) -> Void)?

        private init() {}

        // MARK: - Public API

        /// Check if accessibility access is granted
        public var isAccessibilityEnabled: Bool {
            AXIsProcessTrusted()
        }

        /// Request accessibility access from the user
        public func requestAccessibilityAccess() {
            // Using a string literal instead of the constant to avoid concurrency issues
            let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
        }

        /// Start observing accessibility events
        public func start() {
            guard !isRunning else { return }
            guard isAccessibilityEnabled else {
                logger.warning("Accessibility access not granted")
                requestAccessibilityAccess()
                return
            }

            isRunning = true
            logger.info("Starting accessibility observer")

            // Observe app focus changes
            focusedAppObserver = NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.didActivateApplicationNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                self?.handleAppActivation(notification)
            }

            // Initial state
            if let frontApp = NSWorkspace.shared.frontmostApplication {
                frontmostApp = frontApp
                notifyAppFocus(app: frontApp)
            }

            // Start polling for focused element changes (AX callbacks are unreliable)
            startFocusPolling()
        }

        /// Stop observing accessibility events
        public func stop() {
            guard isRunning else { return }

            isRunning = false
            logger.info("Stopping accessibility observer")

            if let observer = focusedAppObserver {
                NSWorkspace.shared.notificationCenter.removeObserver(observer)
            }
            focusedAppObserver = nil
            focusedWindowObserver = nil
        }

        // MARK: - Private Methods

        private func handleAppActivation(_ notification: Notification) {
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
                return
            }

            frontmostApp = app
            notifyAppFocus(app: app)

            // Get window info for the activated app
            queue.async { [weak self] in
                self?.updateFocusedWindow(for: app)
            }
        }

        private func notifyAppFocus(app: NSRunningApplication) {
            let info = AppFocusInfo(
                bundleIdentifier: app.bundleIdentifier,
                localizedName: app.localizedName,
                processIdentifier: app.processIdentifier,
                isActive: app.isActive,
                launchDate: app.launchDate
            )

            DispatchQueue.main.async { [weak self] in
                self?.onAppFocusChanged?(info)
            }
        }

        private func updateFocusedWindow(for app: NSRunningApplication) {
            let pid = app.processIdentifier

            // Get AXUIElement for the app
            let appElement = AXUIElementCreateApplication(pid)

            // Get focused window
            var focusedWindow: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWindow)

            guard result == .success, let window = focusedWindow else {
                return
            }

            // Get window properties
            let windowInfo = extractWindowInfo(from: window as! AXUIElement, app: app)

            DispatchQueue.main.async { [weak self] in
                self?.onWindowFocusChanged?(windowInfo)
            }
        }

        private func extractWindowInfo(from window: AXUIElement, app: NSRunningApplication) -> WindowFocusInfo {
            var title: String?
            var titleValue: CFTypeRef?
            if AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleValue) == .success {
                title = titleValue as? String
            }

            var position: CGPoint?
            var positionValue: CFTypeRef?
            if AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &positionValue) == .success {
                var point = CGPoint.zero
                AXValueGetValue(positionValue as! AXValue, .cgPoint, &point)
                position = point
            }

            var size: CGSize?
            var sizeValue: CFTypeRef?
            if AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeValue) == .success {
                var cgSize = CGSize.zero
                AXValueGetValue(sizeValue as! AXValue, .cgSize, &cgSize)
                size = cgSize
            }

            // Try to get document path if available
            var documentPath: String?
            var documentValue: CFTypeRef?
            if AXUIElementCopyAttributeValue(window, kAXDocumentAttribute as CFString, &documentValue) == .success {
                documentPath = documentValue as? String
            }

            return WindowFocusInfo(
                appBundleIdentifier: app.bundleIdentifier,
                appName: app.localizedName,
                windowTitle: title,
                documentPath: documentPath,
                position: position,
                size: size
            )
        }

        private func startFocusPolling() {
            // Poll for focused element changes every 500ms
            queue.async { [weak self] in
                while self?.isRunning == true {
                    self?.pollFocusedElement()
                    Thread.sleep(forTimeInterval: 0.5)
                }
            }
        }

        private func pollFocusedElement() {
            guard let app = frontmostApp else { return }

            let appElement = AXUIElementCreateApplication(app.processIdentifier)

            // Get focused UI element
            var focusedElement: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedElement)

            guard result == .success, let element = focusedElement else { return }

            let elementInfo = extractAccessibilityElementInfo(from: element as! AXUIElement, app: app)

            DispatchQueue.main.async { [weak self] in
                self?.onUIElementChanged?(elementInfo)
            }

            // Check for text selection in text elements
            checkTextSelection(element: element as! AXUIElement, app: app)
        }

        private func extractAccessibilityElementInfo(from element: AXUIElement, app: NSRunningApplication) -> AccessibilityElementInfo {
            var role: String?
            var roleValue: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleValue) == .success {
                role = roleValue as? String
            }

            var roleDescription: String?
            var roleDescValue: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXRoleDescriptionAttribute as CFString, &roleDescValue) == .success {
                roleDescription = roleDescValue as? String
            }

            var title: String?
            var titleValue: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &titleValue) == .success {
                title = titleValue as? String
            }

            var value: String?
            var valueRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valueRef) == .success {
                value = valueRef as? String
            }

            return AccessibilityElementInfo(
                appBundleIdentifier: app.bundleIdentifier,
                role: role,
                roleDescription: roleDescription,
                title: title,
                value: value
            )
        }

        private func checkTextSelection(element: AXUIElement, app: NSRunningApplication) {
            // Check if element has selected text
            var selectedText: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &selectedText)

            guard result == .success, let text = selectedText as? String, !text.isEmpty else {
                return
            }

            // Get selection range if available
            var rangeValue: CFTypeRef?
            var range: CFRange?
            if AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &rangeValue) == .success {
                var cfRange = CFRange()
                AXValueGetValue(rangeValue as! AXValue, .cfRange, &cfRange)
                range = cfRange
            }

            let selectionInfo = TextSelectionInfo(
                appBundleIdentifier: app.bundleIdentifier,
                selectedText: text,
                selectionStart: range?.location,
                selectionLength: range?.length
            )

            DispatchQueue.main.async { [weak self] in
                self?.onTextSelectionChanged?(selectionInfo)
            }
        }

        // MARK: - Utility Methods

        /// Get the current focused window title
        public func getCurrentWindowTitle() -> String? {
            guard let app = NSWorkspace.shared.frontmostApplication else { return nil }

            let appElement = AXUIElementCreateApplication(app.processIdentifier)

            var focusedWindow: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWindow)

            guard result == .success, let window = focusedWindow else { return nil }

            var title: CFTypeRef?
            if AXUIElementCopyAttributeValue(window as! AXUIElement, kAXTitleAttribute as CFString, &title) == .success {
                return title as? String
            }

            return nil
        }

        /// Get the current focused app name
        public func getCurrentAppName() -> String? {
            NSWorkspace.shared.frontmostApplication?.localizedName
        }

        /// Get the currently selected text in any app
        public func getSelectedText() -> String? {
            guard let app = NSWorkspace.shared.frontmostApplication else { return nil }

            let appElement = AXUIElementCreateApplication(app.processIdentifier)

            var focusedElement: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedElement)

            guard result == .success, let element = focusedElement else { return nil }

            var selectedText: CFTypeRef?
            if AXUIElementCopyAttributeValue(element as! AXUIElement, kAXSelectedTextAttribute as CFString, &selectedText) == .success {
                return selectedText as? String
            }

            return nil
        }
    }

    // MARK: - Data Types

    public struct WindowFocusInfo: Sendable {
        public let appBundleIdentifier: String?
        public let appName: String?
        public let windowTitle: String?
        public let documentPath: String?
        public let position: CGPoint?
        public let size: CGSize?
        public let timestamp = Date()
    }

    public struct AppFocusInfo: Sendable {
        public let bundleIdentifier: String?
        public let localizedName: String?
        public let processIdentifier: pid_t
        public let isActive: Bool
        public let launchDate: Date?
        public let timestamp = Date()
    }

    public struct TextSelectionInfo: Sendable {
        public let appBundleIdentifier: String?
        public let selectedText: String
        public let selectionStart: Int?
        public let selectionLength: Int?
        public let timestamp = Date()
    }

    public struct AccessibilityElementInfo: Sendable {
        public let appBundleIdentifier: String?
        public let role: String?
        public let roleDescription: String?
        public let title: String?
        public let value: String?
        public let timestamp = Date()
    }
#endif
