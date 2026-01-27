//
//  FilterDataProvider.swift
//  Thea Network Extension
//
//  Created by Thea
//  Content filter for network traffic monitoring
//

import NetworkExtension
import os.log

/// Provides content filtering for network traffic
/// Requires com.apple.developer.networking.networkextension entitlement
@available(macOS 11.0, iOS 15.0, *)
class FilterDataProvider: NEFilterDataProvider {
    private let logger = Logger(subsystem: "app.thea.networkextension", category: "FilterDataProvider")

    // MARK: - Shared State

    private static var blockedDomains: Set<String> = []
    private static var allowedDomains: Set<String> = []
    private static var monitoredApps: Set<String> = []
    private static var trafficLog: [NetworkTrafficEntry] = []

    // MARK: - Configuration

    struct Configuration {
        var enableBlocking: Bool = false
        var enableMonitoring: Bool = true
        var logTraffic: Bool = true
        var blockCategories: Set<ContentCategory> = []
    }

    private var configuration = Configuration()

    // MARK: - Lifecycle

    override func startFilter(completionHandler: @escaping (Error?) -> Void) {
        logger.info("Starting network content filter")

        // Load configuration from app group
        loadConfiguration()

        completionHandler(nil)
    }

    override func stopFilter(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        logger.info("Stopping network content filter: \(String(describing: reason))")

        // Save any pending data
        saveTrafficLog()

        completionHandler()
    }

    // MARK: - Filtering

    override func handleNewFlow(_ flow: NEFilterFlow) -> NEFilterNewFlowVerdict {
        guard let socketFlow = flow as? NEFilterSocketFlow,
              let remoteEndpoint = socketFlow.remoteEndpoint as? NWHostEndpoint
        else {
            return .allow()
        }

        let hostname = remoteEndpoint.hostname
        let port = remoteEndpoint.port
        let appIdentifier = socketFlow.sourceAppIdentifier ?? "unknown"

        // Log traffic if enabled
        if configuration.logTraffic {
            logTraffic(
                hostname: hostname,
                port: port,
                app: appIdentifier,
                direction: .outbound
            )
        }

        // Check if domain is explicitly allowed
        if Self.allowedDomains.contains(hostname) {
            return .allow()
        }

        // Check if domain is blocked
        if configuration.enableBlocking {
            if Self.blockedDomains.contains(hostname) {
                logger.info("Blocked connection to \(hostname) from \(appIdentifier)")
                return .drop()
            }

            // Check for category-based blocking
            if let category = categorize(hostname: hostname),
               configuration.blockCategories.contains(category)
            {
                logger.info("Blocked \(category.rawValue) connection to \(hostname)")
                return .drop()
            }
        }

        // Check if we need to inspect this flow further
        if Self.monitoredApps.contains(appIdentifier) {
            return .filterDataVerdict(withFilterInbound: true, peekInboundBytes: 4096, filterOutbound: true, peekOutboundBytes: 4096)
        }

        return .allow()
    }

    override func handleInboundData(from flow: NEFilterFlow, readBytesStartOffset _: Int, readBytes: Data) -> NEFilterDataVerdict {
        // Inspect inbound data if needed
        if let socketFlow = flow as? NEFilterSocketFlow {
            analyzeInboundData(readBytes, for: socketFlow)
        }

        return .allow()
    }

    override func handleOutboundData(from flow: NEFilterFlow, readBytesStartOffset _: Int, readBytes: Data) -> NEFilterDataVerdict {
        // Inspect outbound data if needed
        if let socketFlow = flow as? NEFilterSocketFlow {
            analyzeOutboundData(readBytes, for: socketFlow)
        }

        return .allow()
    }

    // MARK: - Analysis

    private func analyzeInboundData(_ data: Data, for flow: NEFilterSocketFlow) {
        // Analyze content type, detect sensitive data, etc.
        let size = data.count

        // Check for potential threats or unwanted content
        if containsSuspiciousPatterns(data) {
            logger.warning("Suspicious inbound data detected from \(flow.remoteEndpoint?.debugDescription ?? "unknown")")
        }
    }

    private func analyzeOutboundData(_ data: Data, for flow: NEFilterSocketFlow) {
        // Check for data exfiltration patterns
        let size = data.count

        // Large outbound transfers might be suspicious
        if size > 1_000_000 { // 1MB
            logger.info("Large outbound transfer: \(size) bytes to \(flow.remoteEndpoint?.debugDescription ?? "unknown")")
        }
    }

    private func containsSuspiciousPatterns(_ data: Data) -> Bool {
        // Check for common malware patterns, encoded payloads, etc.
        // This is a simplified check
        guard let string = String(data: data.prefix(1024), encoding: .utf8) else {
            return false
        }

        let suspiciousPatterns = [
            "eval(", "base64_decode", "<script>", "powershell",
            "cmd.exe", "/bin/sh", "wget ", "curl "
        ]

        for pattern in suspiciousPatterns {
            if string.lowercased().contains(pattern.lowercased()) {
                return true
            }
        }

        return false
    }

    // MARK: - Categorization

    private func categorize(hostname: String) -> ContentCategory? {
        // Simple categorization based on domain patterns
        // In production, this would use a categorization service or database

        let lowercased = hostname.lowercased()

        if lowercased.contains("facebook") || lowercased.contains("instagram") ||
            lowercased.contains("twitter") || lowercased.contains("tiktok")
        {
            return .socialMedia
        }

        if lowercased.contains("youtube") || lowercased.contains("netflix") ||
            lowercased.contains("twitch") || lowercased.contains("spotify")
        {
            return .streaming
        }

        if lowercased.contains("reddit") || lowercased.contains("news") ||
            lowercased.contains("cnn") || lowercased.contains("bbc")
        {
            return .news
        }

        if lowercased.contains("game") || lowercased.contains("steam") ||
            lowercased.contains("epic")
        {
            return .gaming
        }

        if lowercased.contains("shop") || lowercased.contains("amazon") ||
            lowercased.contains("ebay")
        {
            return .shopping
        }

        if lowercased.contains("ads") || lowercased.contains("tracking") ||
            lowercased.contains("analytics") || lowercased.contains("doubleclick")
        {
            return .advertising
        }

        return nil
    }

    // MARK: - Traffic Logging

    private func logTraffic(hostname: String, port: String, app: String, direction: TrafficDirection) {
        let entry = NetworkTrafficEntry(
            timestamp: Date(),
            hostname: hostname,
            port: port,
            appIdentifier: app,
            direction: direction,
            bytesTransferred: 0
        )

        Self.trafficLog.append(entry)

        // Trim log if too large
        if Self.trafficLog.count > 10000 {
            Self.trafficLog = Array(Self.trafficLog.suffix(5000))
        }
    }

    // MARK: - Configuration

    private func loadConfiguration() {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.app.thea"
        ) else { return }

        let configURL = containerURL.appendingPathComponent("network_filter_config.json")

        guard let data = try? Data(contentsOf: configURL),
              let config = try? JSONDecoder().decode(FilterConfiguration.self, from: data)
        else {
            return
        }

        configuration.enableBlocking = config.enableBlocking
        configuration.enableMonitoring = config.enableMonitoring
        configuration.logTraffic = config.logTraffic
        configuration.blockCategories = Set(config.blockCategories.compactMap { ContentCategory(rawValue: $0) })

        Self.blockedDomains = Set(config.blockedDomains)
        Self.allowedDomains = Set(config.allowedDomains)
        Self.monitoredApps = Set(config.monitoredApps)

        logger.info("Loaded filter configuration")
    }

    private func saveTrafficLog() {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.app.thea"
        ) else { return }

        let logURL = containerURL.appendingPathComponent("network_traffic_log.json")

        if let data = try? JSONEncoder().encode(Self.trafficLog) {
            try? data.write(to: logURL)
        }
    }
}

// MARK: - Supporting Types

enum ContentCategory: String, Codable, CaseIterable {
    case socialMedia = "social_media"
    case streaming
    case news
    case gaming
    case shopping
    case advertising
    case adult
    case gambling
    case malware
}

enum TrafficDirection: String, Codable {
    case inbound
    case outbound
}

struct NetworkTrafficEntry: Codable {
    let timestamp: Date
    let hostname: String
    let port: String
    let appIdentifier: String
    let direction: TrafficDirection
    var bytesTransferred: Int
}

struct FilterConfiguration: Codable {
    var enableBlocking: Bool
    var enableMonitoring: Bool
    var logTraffic: Bool
    var blockCategories: [String]
    var blockedDomains: [String]
    var allowedDomains: [String]
    var monitoredApps: [String]
}
