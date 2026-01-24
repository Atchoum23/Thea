// TheaSafariExtension.swift
// Safari Web Extension implementation for macOS, iOS, and iPadOS

import Foundation
import SafariServices
import OSLog

// MARK: - Safari Extension Handler

/// Main handler for Safari extension events
public final class TheaSafariExtensionHandler: NSObject, NSExtensionRequestHandling {

    private let logger = Logger(subsystem: "com.thea.safari-extension", category: "Handler")

    // MARK: - NSExtensionRequestHandling

    public func beginRequest(with context: NSExtensionContext) {
        // Handle extension requests from Safari
        guard let inputItems = context.inputItems as? [NSExtensionItem] else {
            context.completeRequest(returningItems: nil, completionHandler: nil)
            return
        }

        for item in inputItems {
            if let attachments = item.attachments {
                for attachment in attachments {
                    if attachment.hasItemConformingToTypeIdentifier("public.url") {
                        attachment.loadItem(forTypeIdentifier: "public.url", options: nil) { [weak self] (url, error) in
                            if let url = url as? URL {
                                self?.handleURL(url, context: context)
                            }
                        }
                    }
                }
            }
        }
    }

    private func handleURL(_ url: URL, context: NSExtensionContext) {
        // Process URL with extension features
        logger.info("Processing URL: \(url.absoluteString)")
        context.completeRequest(returningItems: nil, completionHandler: nil)
    }
}

// MARK: - Safari Extension View Controller (iOS/iPadOS)

#if os(iOS)
import UIKit

public class TheaSafariExtensionViewController: UIViewController {

    override public func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    private func setupUI() {
        view.backgroundColor = .systemBackground

        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false

        // Title
        let titleLabel = UILabel()
        titleLabel.text = "Thea"
        titleLabel.font = .preferredFont(forTextStyle: .largeTitle)
        titleLabel.textAlignment = .center

        // Status indicator
        let statusLabel = UILabel()
        statusLabel.text = "Protection Active"
        statusLabel.font = .preferredFont(forTextStyle: .headline)
        statusLabel.textColor = .systemGreen
        statusLabel.textAlignment = .center

        // Quick actions
        let actionsStack = createQuickActionsStack()

        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(statusLabel)
        stackView.addArrangedSubview(actionsStack)

        view.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stackView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20)
        ])
    }

    private func createQuickActionsStack() -> UIStackView {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 12
        stack.distribution = .fillEqually

        let actions: [(String, String, UIAction)] = [
            ("Dark Mode", "moon.fill", UIAction { _ in self.toggleDarkMode() }),
            ("Clean Page", "doc.text", UIAction { _ in self.cleanPage() }),
            ("Settings", "gear", UIAction { _ in self.openSettings() })
        ]

        for (title, icon, action) in actions {
            var config = UIButton.Configuration.filled()
            config.title = title
            config.image = UIImage(systemName: icon)
            config.imagePlacement = .top
            config.imagePadding = 8

            let button = UIButton(configuration: config, primaryAction: action)
            stack.addArrangedSubview(button)
        }

        return stack
    }

    private func toggleDarkMode() {
        // Toggle dark mode via native messaging
        sendMessage(["action": "toggleDarkMode"])
    }

    private func cleanPage() {
        sendMessage(["action": "cleanPage"])
    }

    private func openSettings() {
        // Open Thea app settings
        if let url = URL(string: "thea://settings/extension") {
            UIApplication.shared.open(url)
        }
    }

    private func sendMessage(_ message: [String: Any]) {
        // Send message to content script
        // This would use SFSafariApplication messaging
    }
}
#endif

// MARK: - Safari Extension View Controller (macOS)

#if os(macOS)
import AppKit

public class TheaSafariExtensionViewController: SFSafariExtensionViewController {

    public static let shared = TheaSafariExtensionViewController()

    private var statusLabel: NSTextField?
    private var statsLabel: NSTextField?

    override public func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadStatus()
    }

    private func setupUI() {
        preferredContentSize = NSSize(width: 320, height: 400)

        let containerView = NSView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)

        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16)
        ])

        // Header
        let headerStack = createHeader()
        containerView.addSubview(headerStack)

        // Feature toggles
        let togglesStack = createFeatureToggles()
        containerView.addSubview(togglesStack)

        // Stats
        let statsStack = createStatsView()
        containerView.addSubview(statsStack)

        // Layout
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        togglesStack.translatesAutoresizingMaskIntoConstraints = false
        statsStack.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            headerStack.topAnchor.constraint(equalTo: containerView.topAnchor),
            headerStack.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            headerStack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),

            togglesStack.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: 20),
            togglesStack.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            togglesStack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),

            statsStack.topAnchor.constraint(equalTo: togglesStack.bottomAnchor, constant: 20),
            statsStack.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            statsStack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor)
        ])
    }

    private func createHeader() -> NSStackView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 8

        // Logo and title
        let titleStack = NSStackView()
        titleStack.orientation = .horizontal
        titleStack.spacing = 8

        let iconView = NSImageView()
        iconView.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "Thea")
        iconView.contentTintColor = .systemBlue

        let titleLabel = NSTextField(labelWithString: "Thea Extension")
        titleLabel.font = .boldSystemFont(ofSize: 16)

        titleStack.addArrangedSubview(iconView)
        titleStack.addArrangedSubview(titleLabel)

        // Status
        let status = NSTextField(labelWithString: "All protections active")
        status.font = .systemFont(ofSize: 12)
        status.textColor = .systemGreen
        self.statusLabel = status

        stack.addArrangedSubview(titleStack)
        stack.addArrangedSubview(status)

        return stack
    }

    private func createFeatureToggles() -> NSStackView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 12
        stack.alignment = .leading

        let features: [(String, String, Bool)] = [
            ("Ad Blocker", "shield.fill", true),
            ("Tracker Protection", "eye.slash.fill", true),
            ("Dark Mode", "moon.fill", false),
            ("Email Protection", "envelope.badge.shield.half.filled", true),
            ("Password Autofill", "key.fill", true)
        ]

        for (title, icon, enabled) in features {
            let row = createToggleRow(title: title, icon: icon, isOn: enabled)
            stack.addArrangedSubview(row)
        }

        return stack
    }

    private func createToggleRow(title: String, icon: String, isOn: Bool) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let iconView = NSImageView()
        iconView.image = NSImage(systemSymbolName: icon, accessibilityDescription: title)
        iconView.translatesAutoresizingMaskIntoConstraints = false

        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 13)
        label.translatesAutoresizingMaskIntoConstraints = false

        let toggle = NSSwitch()
        toggle.state = isOn ? .on : .off
        toggle.target = self
        toggle.action = #selector(toggleChanged(_:))
        toggle.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(iconView)
        container.addSubview(label)
        container.addSubview(toggle)

        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 28),

            iconView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            iconView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 20),

            label.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),

            toggle.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            toggle.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])

        return container
    }

    @objc private func toggleChanged(_ sender: NSSwitch) {
        // Handle toggle change
        updateExtensionState()
    }

    private func createStatsView() -> NSStackView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 8
        stack.alignment = .leading

        let titleLabel = NSTextField(labelWithString: "Today's Stats")
        titleLabel.font = .boldSystemFont(ofSize: 13)

        let stats = NSTextField(labelWithString: "Ads blocked: 0\nTrackers blocked: 0\nData saved: 0 KB")
        stats.font = .systemFont(ofSize: 11)
        stats.textColor = .secondaryLabelColor
        self.statsLabel = stats

        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(stats)

        return stack
    }

    private func loadStatus() {
        // Load extension state from app group
        Task {
            await updateStatsDisplay()
        }
    }

    private func updateExtensionState() {
        // Save state to app group for sharing with main app
        let userDefaults = UserDefaults(suiteName: "group.com.thea.extension")
        // Save toggle states...
    }

    @MainActor
    private func updateStatsDisplay() {
        let stats = TheaExtensionState.shared.stats
        statsLabel?.stringValue = """
        Ads blocked: \(stats.adsBlocked)
        Trackers blocked: \(stats.trackersBlocked)
        Data saved: \(formatBytes(stats.dataSaved))
        """
    }

    private func formatBytes(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

// MARK: - Safari Extension Handler (macOS)

public class TheaSafariExtensionHandlerMac: SFSafariExtensionHandler {

    private let logger = Logger(subsystem: "com.thea.safari-extension", category: "Handler")

    override public func messageReceived(withName messageName: String, from page: SFSafariPage, userInfo: [String: Any]?) {
        logger.info("Received message: \(messageName)")

        Task {
            await handleMessage(messageName, from: page, userInfo: userInfo)
        }
    }

    @MainActor
    private func handleMessage(_ name: String, from page: SFSafariPage, userInfo: [String: Any]?) {
        switch name {
        case "getState":
            sendState(to: page)

        case "pageLoaded":
            handlePageLoad(page, userInfo: userInfo)

        case "requestBlocking":
            handleBlockingRequest(page, userInfo: userInfo)

        case "autofillRequest":
            handleAutofillRequest(page, userInfo: userInfo)

        case "darkModeRequest":
            handleDarkModeRequest(page, userInfo: userInfo)

        case "printFriendly":
            handlePrintFriendlyRequest(page, userInfo: userInfo)

        case "generateAlias":
            handleGenerateAliasRequest(page, userInfo: userInfo)

        default:
            logger.warning("Unknown message: \(name)")
        }
    }

    private func sendState(to page: SFSafariPage) {
        let state = TheaExtensionState.shared
        page.dispatchMessageToScript(withName: "state", userInfo: [
            "adBlockerEnabled": state.adBlockerEnabled,
            "darkModeEnabled": state.darkModeEnabled,
            "privacyProtectionEnabled": state.privacyProtectionEnabled,
            "passwordManagerEnabled": state.passwordManagerEnabled,
            "emailProtectionEnabled": state.emailProtectionEnabled,
            "printFriendlyEnabled": state.printFriendlyEnabled
        ])
    }

    private func handlePageLoad(_ page: SFSafariPage, userInfo: [String: Any]?) {
        guard let urlString = userInfo?["url"] as? String,
              let url = URL(string: urlString) else { return }

        let domain = url.host ?? ""

        Task { @MainActor in
            // Get cosmetic CSS for ad blocking
            let adBlockCSS = TheaAdBlockerManager.shared.getCosmeticCSS(for: domain)

            // Get dark mode CSS if enabled
            var darkModeCSS = ""
            if TheaDarkModeManager.shared.isEnabled {
                let context = PageContext(url: url, domain: domain, title: "", tabId: "")
                if let css = try? await TheaDarkModeManager.shared.enableDarkMode(on: context) {
                    darkModeCSS = css.combined
                }
            }

            // Get fingerprint protection script
            let fingerprintScript = TheaPrivacyProtectionManager.shared.getFingerprintProtectionScript()

            page.dispatchMessageToScript(withName: "applyProtections", userInfo: [
                "adBlockCSS": adBlockCSS,
                "darkModeCSS": darkModeCSS,
                "fingerprintScript": fingerprintScript
            ])
        }
    }

    private func handleBlockingRequest(_ page: SFSafariPage, userInfo: [String: Any]?) {
        guard let urlString = userInfo?["url"] as? String,
              let url = URL(string: urlString),
              let resourceType = userInfo?["resourceType"] as? String else { return }

        let request = NetworkRequest(
            url: url,
            sourceURL: nil,
            resourceType: NetworkRequest.ResourceType(rawValue: resourceType) ?? .other,
            method: "GET"
        )

        let decision = TheaAdBlockerManager.shared.shouldBlock(request: request)

        page.dispatchMessageToScript(withName: "blockingDecision", userInfo: [
            "url": urlString,
            "shouldBlock": decision.shouldBlock,
            "reason": decision.reason ?? ""
        ])
    }

    private func handleAutofillRequest(_ page: SFSafariPage, userInfo: [String: Any]?) {
        guard let domain = userInfo?["domain"] as? String else { return }

        Task { @MainActor in
            do {
                let credentials = try await TheaPasswordManager.shared.getCredentials(for: domain)

                page.dispatchMessageToScript(withName: "autofillResponse", userInfo: [
                    "hasCredentials": !credentials.isEmpty,
                    "count": credentials.count
                ])
            } catch {
                logger.error("Autofill error: \(error.localizedDescription)")
            }
        }
    }

    private func handleDarkModeRequest(_ page: SFSafariPage, userInfo: [String: Any]?) {
        guard let urlString = userInfo?["url"] as? String,
              let url = URL(string: urlString) else { return }

        let domain = url.host ?? ""

        Task { @MainActor in
            let context = PageContext(url: url, domain: domain, title: "", tabId: "")

            if let css = try? await TheaDarkModeManager.shared.enableDarkMode(on: context) {
                page.dispatchMessageToScript(withName: "darkModeCSS", userInfo: [
                    "css": css.combined
                ])
            }
        }
    }

    private func handlePrintFriendlyRequest(_ page: SFSafariPage, userInfo: [String: Any]?) {
        guard let html = userInfo?["html"] as? String,
              let urlString = userInfo?["url"] as? String,
              let url = URL(string: urlString) else { return }

        Task { @MainActor in
            do {
                let cleanedPage = try await TheaPrintFriendlyManager.shared.cleanPage(
                    html: html,
                    url: url
                )

                page.dispatchMessageToScript(withName: "printFriendlyResult", userInfo: [
                    "title": cleanedPage.title,
                    "content": cleanedPage.content,
                    "wordCount": cleanedPage.wordCount,
                    "readTime": cleanedPage.estimatedReadTime
                ])
            } catch {
                logger.error("Print friendly error: \(error.localizedDescription)")
            }
        }
    }

    private func handleGenerateAliasRequest(_ page: SFSafariPage, userInfo: [String: Any]?) {
        guard let domain = userInfo?["domain"] as? String else { return }

        Task { @MainActor in
            do {
                let alias = try await TheaEmailProtectionManager.shared.generateAlias(for: domain)

                page.dispatchMessageToScript(withName: "aliasGenerated", userInfo: [
                    "alias": alias.alias,
                    "domain": domain
                ])
            } catch {
                logger.error("Alias generation error: \(error.localizedDescription)")
            }
        }
    }

    override public func toolbarItemClicked(in window: SFSafariWindow) {
        window.getToolbarItem { item in
            // Show popover
        }
    }

    override public func validateToolbarItem(in window: SFSafariWindow, validationHandler: @escaping (Bool, String) -> Void) {
        validationHandler(true, "")
    }

    override public func popoverViewController() -> SFSafariExtensionViewController {
        return TheaSafariExtensionViewController.shared
    }
}
#endif
