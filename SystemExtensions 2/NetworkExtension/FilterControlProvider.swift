//
//  FilterControlProvider.swift
//  Thea Network Extension
//
//  Created by Thea
//  Control provider for network content filter
//

import NetworkExtension
import os.log

/// Controls the network content filter configuration
@available(macOS 11.0, iOS 15.0, *)
class FilterControlProvider: NEFilterControlProvider {
    private let logger = Logger(subsystem: "app.thea.networkextension", category: "FilterControlProvider")

    // MARK: - Lifecycle

    override func startFilter(completionHandler: @escaping (Error?) -> Void) {
        logger.info("FilterControlProvider starting")
        completionHandler(nil)
    }

    override func stopFilter(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        logger.info("FilterControlProvider stopping: \(String(describing: reason))")
        completionHandler()
    }

    // MARK: - URL Handling

    override func handleNewFlow(_ flow: NEFilterFlow, completionHandler: @escaping (NEFilterControlVerdict) -> Void) {
        // The control provider can make decisions about new flows
        // In most cases, we defer to the data provider

        guard let browserFlow = flow as? NEFilterBrowserFlow else {
            completionHandler(.allow(withUpdateRules: false))
            return
        }

        // For browser flows, we can access the URL
        if let url = browserFlow.url {
            logger.debug("Browser flow to: \(url.absoluteString)")

            // Check for blocked URLs
            if shouldBlock(url: url) {
                completionHandler(.drop(withUpdateRules: false))
                return
            }
        }

        completionHandler(.allow(withUpdateRules: false))
    }

    // MARK: - Remediation

    override func handleRemediation(for _: NEFilterFlow, completionHandler: @escaping (NEFilterControlVerdict) -> Void) {
        // Handle requests to unblock specific flows
        logger.info("Remediation requested for flow")

        // For now, allow remediation
        completionHandler(.allow(withUpdateRules: false))
    }

    // MARK: - Rules Update

    override func notifyRulesChanged() {
        logger.info("Filter rules changed notification")

        // Reload configuration
        loadConfiguration()
    }

    // MARK: - Helpers

    private var blockedURLPatterns: [String] = []
    private var blockedDomains: Set<String> = []

    private func shouldBlock(url: URL) -> Bool {
        let host = url.host?.lowercased() ?? ""
        let urlString = url.absoluteString.lowercased()

        // Check exact domain match
        if blockedDomains.contains(host) {
            return true
        }

        // Check domain suffix
        for domain in blockedDomains {
            if host.hasSuffix("." + domain) {
                return true
            }
        }

        // Check URL patterns
        for pattern in blockedURLPatterns {
            if urlString.contains(pattern.lowercased()) {
                return true
            }
        }

        return false
    }

    private func loadConfiguration() {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.app.theathe"
        ) else { return }

        let configURL = containerURL.appendingPathComponent("network_filter_config.json")

        guard let data = try? Data(contentsOf: configURL),
              let config = try? JSONDecoder().decode(FilterConfiguration.self, from: data)
        else {
            return
        }

        blockedDomains = Set(config.blockedDomains)
        blockedURLPatterns = config.blockedDomains // Could be separate in production

        logger.info("Loaded \(blockedDomains.count) blocked domains")
    }
}
