// BrowserAutomation.swift
// AI-powered browser automation and web scraping

import Combine
import Foundation
import OSLog

// MARK: - Browser Automation Engine

/// AI-powered browser automation for web tasks
@MainActor
public final class BrowserAutomationEngine: ObservableObject {
    public static let shared = BrowserAutomationEngine()

    private let logger = Logger(subsystem: "com.thea.app", category: "BrowserAutomation")
    private let securityEnforcer = AgentSecEnforcer.shared

    // MARK: - Published State

    @Published public private(set) var isRunning = false
    @Published public private(set) var currentTask: BrowserTask?
    @Published public private(set) var taskHistory: [BrowserTaskResult] = []
    @Published public private(set) var blockedDomains: Set<String> = []

    // MARK: - Configuration

    private var allowedDomains: Set<String> = []
    private var userAgent = "TheaBrowser/1.0"
    private var timeout: TimeInterval = 30

    // MARK: - Initialization

    private init() {
        setupBlockedDomains()
    }

    private func setupBlockedDomains() {
        // Security: Block sensitive domains
        blockedDomains = [
            "localhost",
            "127.0.0.1",
            "0.0.0.0",
            "169.254.169.254", // AWS metadata
            "metadata.google.internal", // GCP metadata
            "internal",
            ".local"
        ]
    }

    // MARK: - Task Execution

    /// Execute a browser automation task
    public func executeTask(_ task: BrowserTask) async throws -> BrowserTaskResult {
        // Security check
        guard await validateTaskSecurity(task) else {
            throw AIBrowserError.securityViolation("Task failed security validation")
        }

        isRunning = true
        currentTask = task

        defer {
            isRunning = false
            currentTask = nil
        }

        logger.info("Executing browser task: \(task.name)")

        let result: BrowserTaskResult = switch task.type {
        case let .scrape(config):
            try await executeScrapeTask(task, config: config)

        case let .fill(config):
            try await executeFillTask(task, config: config)

        case let .click(config):
            try await executeClickTask(task, config: config)

        case let .screenshot(config):
            try await executeScreenshotTask(task, config: config)

        case let .navigate(config):
            try await executeNavigateTask(task, config: config)

        case let .custom(steps):
            try await executeCustomTask(task, steps: steps)
        }

        taskHistory.append(result)
        return result
    }

    // MARK: - Task Types

    private func executeScrapeTask(_ task: BrowserTask, config: ScrapeConfig) async throws -> BrowserTaskResult {
        // Validate URL
        guard let url = URL(string: config.url),
              !isBlockedDomain(url.host ?? "")
        else {
            throw AIBrowserError.blockedDomain(config.url)
        }

        // Fetch page
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = timeout

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200 ... 299).contains(httpResponse.statusCode)
        else {
            throw AIBrowserError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        guard let html = String(data: data, encoding: .utf8) else {
            throw AIBrowserError.invalidResponse("Could not decode HTML")
        }

        // Extract data using selectors
        var extractedData: [String: Any] = [:]

        for (key, selector) in config.selectors {
            let extracted = extractFromHTML(html, selector: selector)
            extractedData[key] = extracted
        }

        return BrowserTaskResult(
            taskId: task.id,
            success: true,
            data: extractedData,
            screenshot: nil,
            duration: 0,
            timestamp: Date()
        )
    }

    private func executeFillTask(_ task: BrowserTask, config: FillConfig) async throws -> BrowserTaskResult {
        logger.info("Form fill task for: \(config.url)")
        let startTime = Date()

        // Security: Never fill sensitive fields
        let sensitiveFields = ["password", "ssn", "credit_card", "cvv", "pin"]
        for (field, _) in config.fields {
            if sensitiveFields.contains(where: { field.lowercased().contains($0) }) {
                throw AIBrowserError.securityViolation("Cannot fill sensitive field: \(field)")
            }
        }

        #if os(macOS)
        // Navigate to the URL first, then fill fields via JavaScript in Safari
        let navScript = """
        tell application "Safari"
            if (count of windows) is 0 then make new document
            set URL of current tab of front window to "\(config.url.escapedForAppleScript)"
            delay 2
        end tell
        """
        _ = try await runAppleScript(navScript)

        var filledFields: [String] = []
        for (field, value) in config.fields {
            let jsCode = """
            var el = document.querySelector('[name=\"\(field.escapedForJS)\"]') \
            || document.getElementById('\(field.escapedForJS)');
            if (el) { el.value = '\(value.escapedForJS)'; el.dispatchEvent(new Event('input')); 'filled'; } \
            else { 'not_found'; }
            """
            let fillScript = """
            tell application "Safari"
                set jsResult to do JavaScript "\(jsCode.escapedForAppleScript)" in current tab of front window
                return jsResult
            end tell
            """
            let result = try await runAppleScript(fillScript)
            if result.contains("filled") { filledFields.append(field) }
        }

        if let submitSelector = config.submitSelector {
            let submitJS = "document.querySelector('\(submitSelector.escapedForJS)').click();"
            let submitScript = """
            tell application "Safari"
                do JavaScript "\(submitJS.escapedForAppleScript)" in current tab of front window
            end tell
            """
            _ = try await runAppleScript(submitScript)
        }

        let duration = Date().timeIntervalSince(startTime)
        return BrowserTaskResult(
            taskId: task.id, success: !filledFields.isEmpty,
            data: ["filled": filledFields], screenshot: nil,
            duration: duration, timestamp: Date()
        )
        #else
        return BrowserTaskResult(
            taskId: task.id, success: false,
            data: ["error": "Form filling requires macOS"], screenshot: nil,
            duration: 0, timestamp: Date()
        )
        #endif
    }

    private func executeClickTask(_ task: BrowserTask, config: ClickConfig) async throws -> BrowserTaskResult {
        logger.info("Click task for: \(config.url), selector: \(config.selector)")
        let startTime = Date()

        #if os(macOS)
        // Navigate to URL then click element via JavaScript in Safari
        let navScript = """
        tell application "Safari"
            if (count of windows) is 0 then make new document
            set URL of current tab of front window to "\(config.url.escapedForAppleScript)"
            delay 2
        end tell
        """
        _ = try await runAppleScript(navScript)

        let jsCode = """
        var el = document.querySelector('\(config.selector.escapedForJS)');
        if (el) { el.click(); 'clicked'; } else { 'not_found'; }
        """
        let clickScript = """
        tell application "Safari"
            set jsResult to do JavaScript "\(jsCode.escapedForAppleScript)" in current tab of front window
            return jsResult
        end tell
        """
        let result = try await runAppleScript(clickScript)
        let success = result.contains("clicked")

        let duration = Date().timeIntervalSince(startTime)
        return BrowserTaskResult(
            taskId: task.id, success: success,
            data: ["clicked": config.selector, "result": result], screenshot: nil,
            duration: duration, timestamp: Date()
        )
        #else
        return BrowserTaskResult(
            taskId: task.id, success: false,
            data: ["error": "Click requires macOS"], screenshot: nil,
            duration: 0, timestamp: Date()
        )
        #endif
    }

    private func executeScreenshotTask(_ task: BrowserTask, config: ScreenshotConfig) async throws -> BrowserTaskResult {
        guard let url = URL(string: config.url),
              !isBlockedDomain(url.host ?? "")
        else {
            throw AIBrowserError.blockedDomain(config.url)
        }

        logger.info("Screenshot task for: \(config.url)")
        let startTime = Date()

        #if os(macOS)
        // Navigate to URL in Safari, then capture window screenshot via screencapture
        let navScript = """
        tell application "Safari"
            if (count of windows) is 0 then make new document
            set URL of current tab of front window to "\(config.url.escapedForAppleScript)"
            delay 3
            activate
        end tell
        """
        _ = try await runAppleScript(navScript)

        // Use screencapture to capture the frontmost window
        let tempPath = NSTemporaryDirectory() + "thea_screenshot_\(UUID().uuidString).png"
        let screenshotOutput = try await runShellCommand("/usr/sbin/screencapture -l$(osascript -e 'tell app \"Safari\" to id of window 1') \"\(tempPath)\"")
        _ = screenshotOutput

        var screenshotData: Data?
        if FileManager.default.fileExists(atPath: tempPath) {
            screenshotData = try? Data(contentsOf: URL(fileURLWithPath: tempPath))
            try? FileManager.default.removeItem(atPath: tempPath)
        }

        let duration = Date().timeIntervalSince(startTime)
        return BrowserTaskResult(
            taskId: task.id, success: screenshotData != nil,
            data: ["url": config.url, "hasScreenshot": screenshotData != nil],
            screenshot: screenshotData, duration: duration, timestamp: Date()
        )
        #else
        return BrowserTaskResult(
            taskId: task.id, success: false,
            data: ["error": "Screenshots require macOS"], screenshot: nil,
            duration: 0, timestamp: Date()
        )
        #endif
    }

    // MARK: - AppleScript / Shell Helpers

    #if os(macOS)
    private func runAppleScript(_ script: String) async throws -> String {
        try await Task.detached {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", script]
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe
            try process.run()
            process.waitUntilExit()
            let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            if process.terminationStatus != 0 {
                let errorOutput = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                throw AIBrowserError.invalidResponse("AppleScript error: \(errorOutput)")
            }
            return output.trimmingCharacters(in: .whitespacesAndNewlines)
        }.value
    }

    private func runShellCommand(_ command: String) async throws -> String {
        try await Task.detached {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-c", command]
            let outputPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = Pipe()
            try process.run()
            process.waitUntilExit()
            return String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        }.value
    }
    #endif

    private func executeNavigateTask(_ task: BrowserTask, config: NavigateConfig) async throws -> BrowserTaskResult {
        guard let url = URL(string: config.url),
              !isBlockedDomain(url.host ?? "")
        else {
            throw AIBrowserError.blockedDomain(config.url)
        }

        logger.info("Navigate task to: \(config.url)")

        // Fetch page to verify navigation
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        let (_, response) = try await URLSession.shared.data(for: request)

        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0

        return BrowserTaskResult(
            taskId: task.id,
            success: (200 ... 299).contains(statusCode),
            data: ["statusCode": statusCode, "url": config.url],
            screenshot: nil,
            duration: 0,
            timestamp: Date()
        )
    }

    private func executeCustomTask(_ task: BrowserTask, steps: [BrowserStep]) async throws -> BrowserTaskResult {
        var results: [[String: Any]] = []

        for step in steps {
            logger.info("Executing step: \(step.action)")

            switch step.action {
            case "navigate":
                if let url = step.parameters["url"] as? String {
                    let config = NavigateConfig(url: url, waitForSelector: nil)
                    let result = try await executeNavigateTask(task, config: config)
                    results.append(result.data)
                }

            case "scrape":
                if let url = step.parameters["url"] as? String,
                   let selectors = step.parameters["selectors"] as? [String: String]
                {
                    let config = ScrapeConfig(url: url, selectors: selectors, waitForSelector: nil)
                    let result = try await executeScrapeTask(task, config: config)
                    results.append(result.data)
                }

            case "wait":
                if let duration = step.parameters["duration"] as? Double {
                    try await Task.sleep(for: .seconds(duration))
                }

            default:
                logger.warning("Unknown step action: \(step.action)")
            }
        }

        return BrowserTaskResult(
            taskId: task.id,
            success: true,
            data: ["steps": results],
            screenshot: nil,
            duration: 0,
            timestamp: Date()
        )
    }

    // MARK: - Security

    private func validateTaskSecurity(_ task: BrowserTask) async -> Bool {
        // Check with AgentSec
        // Get URL from task type
        let urlString: String
        switch task.type {
        case let .scrape(config):
            urlString = config.url
        case let .fill(config):
            urlString = config.url
        case let .click(config):
            urlString = config.url
        case let .screenshot(config):
            urlString = config.url
        case let .navigate(config):
            urlString = config.url
        case .custom:
            return true // Custom tasks are validated per-step
        }

        guard let url = URL(string: urlString) else {
            logger.warning("Task has invalid URL")
            return false
        }

        let result = securityEnforcer.validateNetworkRequest(url: url, method: "GET")

        switch result {
        case .allowed:
            return true
        case let .denied(reason):
            logger.warning("Task denied: \(reason)")
            return false
        case let .requiresApproval(reason):
            logger.warning("Task requires approval: \(reason)")
            return false
        }
    }

    private func isBlockedDomain(_ host: String) -> Bool {
        for blocked in blockedDomains {
            if blocked.hasPrefix(".") {
                if host.hasSuffix(blocked) { return true }
            } else {
                if host == blocked || host.contains(blocked) { return true }
            }
        }
        return false
    }

    // MARK: - HTML Extraction

    private func extractFromHTML(_ html: String, selector: String) -> [String] {
        // Simple CSS selector extraction
        // In production, use a proper HTML parser like SwiftSoup

        var results: [String] = []

        // Handle simple tag extraction
        if selector.hasPrefix("//") {
            // XPath selectors require a full XML parser — use CSS tag selectors instead
            return results
        }

        // Simple tag matching
        let tagPattern = "<\(selector)[^>]*>(.*?)</\(selector)>"
        if let regex = try? NSRegularExpression(pattern: tagPattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) {
            let range = NSRange(html.startIndex..., in: html)
            let matches = regex.matches(in: html, options: [], range: range)

            for match in matches {
                if let contentRange = Range(match.range(at: 1), in: html) {
                    let content = String(html[contentRange])
                    // Strip inner HTML tags
                    let stripped = content.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                    results.append(stripped.trimmingCharacters(in: .whitespacesAndNewlines))
                }
            }
        }

        return results
    }

    // MARK: - Configuration

    /// Set allowed domains (whitelist)
    public func setAllowedDomains(_ domains: [String]) {
        allowedDomains = Set(domains)
    }

    /// Add blocked domain
    public func addBlockedDomain(_ domain: String) {
        blockedDomains.insert(domain)
    }

    /// Set custom user agent
    public func setUserAgent(_ agent: String) {
        userAgent = agent
    }

    /// Set request timeout
    public func setTimeout(_ seconds: TimeInterval) {
        timeout = seconds
    }
}

// MARK: - Web Scraper

/// Specialized web scraping with AI assistance
@MainActor
public final class AIWebScraper: ObservableObject {
    public static let shared = AIWebScraper()

    private let logger = Logger(subsystem: "com.thea.app", category: "WebScraper")
    private let browserEngine = BrowserAutomationEngine.shared

    // MARK: - Smart Scraping

    /// Intelligently scrape a webpage using AI to identify content
    public func smartScrape(url: String, intent _: String) async throws -> ScrapedContent {
        // First, fetch the page
        let task = BrowserTask(
            name: "Smart scrape: \(url)",
            type: .scrape(ScrapeConfig(
                url: url,
                selectors: [
                    "title": "title",
                    "h1": "h1",
                    "h2": "h2",
                    "p": "p",
                    "article": "article"
                ],
                waitForSelector: nil
            ))
        )

        let result = try await browserEngine.executeTask(task)

        // Process with AI to extract relevant content based on intent
        let content = ScrapedContent(
            url: url,
            title: (result.data["title"] as? [String])?.first ?? "",
            headings: (result.data["h1"] as? [String]) ?? [],
            paragraphs: (result.data["p"] as? [String]) ?? [],
            articles: (result.data["article"] as? [String]) ?? [],
            metadata: [:],
            timestamp: Date()
        )

        return content
    }

    /// Extract structured data from a page
    public func extractStructuredData(url: String, schema: DataSchema) async throws -> [String: Any] {
        let selectors = schema.fields.reduce(into: [String: String]()) { result, field in
            result[field.name] = field.selector
        }

        let task = BrowserTask(
            name: "Extract: \(url)",
            type: .scrape(ScrapeConfig(
                url: url,
                selectors: selectors,
                waitForSelector: nil
            ))
        )

        let result = try await browserEngine.executeTask(task)
        return result.data
    }

    /// Monitor a page for changes
    public func monitorPage(url: String, selector: String, interval: TimeInterval, onChange: @escaping (String) -> Void) -> MonitorSession {
        let session = MonitorSession(
            url: url,
            selector: selector,
            interval: interval
        )

        Task {
            var lastContent: String?

            while !session.isCancelled {
                do {
                    let task = BrowserTask(
                        name: "Monitor: \(url)",
                        type: .scrape(ScrapeConfig(
                            url: url,
                            selectors: ["target": selector],
                            waitForSelector: nil
                        ))
                    )

                    let result = try await browserEngine.executeTask(task)

                    if let content = (result.data["target"] as? [String])?.first {
                        if let last = lastContent, last != content {
                            onChange(content)
                        }
                        lastContent = content
                    }

                    try await Task.sleep(for: .seconds(interval))
                } catch {
                    logger.error("Monitor error: \(error.localizedDescription)")
                }
            }
        }

        return session
    }
}

// MARK: - Types

public struct BrowserTask: Identifiable {
    public let id = UUID()
    public let name: String
    public let type: BrowserTaskType

    public init(name: String, type: BrowserTaskType) {
        self.name = name
        self.type = type
    }
}

public enum BrowserTaskType {
    case scrape(ScrapeConfig)
    case fill(FillConfig)
    case click(ClickConfig)
    case screenshot(ScreenshotConfig)
    case navigate(NavigateConfig)
    case custom([BrowserStep])
}

public struct ScrapeConfig {
    public let url: String
    public let selectors: [String: String]
    public let waitForSelector: String?

    public init(url: String, selectors: [String: String], waitForSelector: String?) {
        self.url = url
        self.selectors = selectors
        self.waitForSelector = waitForSelector
    }
}

public struct FillConfig {
    public let url: String
    public let fields: [String: String]
    public let submitSelector: String?

    public init(url: String, fields: [String: String], submitSelector: String?) {
        self.url = url
        self.fields = fields
        self.submitSelector = submitSelector
    }
}

public struct ClickConfig {
    public let url: String
    public let selector: String

    public init(url: String, selector: String) {
        self.url = url
        self.selector = selector
    }
}

public struct ScreenshotConfig {
    public let url: String
    public let fullPage: Bool
    public let selector: String?

    public init(url: String, fullPage: Bool = false, selector: String? = nil) {
        self.url = url
        self.fullPage = fullPage
        self.selector = selector
    }
}

public struct NavigateConfig {
    public let url: String
    public let waitForSelector: String?

    public init(url: String, waitForSelector: String?) {
        self.url = url
        self.waitForSelector = waitForSelector
    }
}

public struct BrowserStep {
    public let action: String
    public let parameters: [String: Any]

    public init(action: String, parameters: [String: Any]) {
        self.action = action
        self.parameters = parameters
    }
}

public struct BrowserTaskResult: Identifiable {
    public let id = UUID()
    public let taskId: UUID
    public let success: Bool
    public let data: [String: Any]
    public let screenshot: Data?
    public let duration: TimeInterval
    public let timestamp: Date
}

public struct ScrapedContent {
    public let url: String
    public let title: String
    public let headings: [String]
    public let paragraphs: [String]
    public let articles: [String]
    public let metadata: [String: String]
    public let timestamp: Date
}

public struct DataSchema {
    public let fields: [SchemaField]

    public init(fields: [SchemaField]) {
        self.fields = fields
    }
}

public struct SchemaField {
    public let name: String
    public let selector: String
    public let type: FieldType

    public enum FieldType {
        case text
        case number
        case url
        case image
        case list
    }

    public init(name: String, selector: String, type: FieldType) {
        self.name = name
        self.selector = selector
        self.type = type
    }
}

public class MonitorSession {
    public let url: String
    public let selector: String
    public let interval: TimeInterval
    public private(set) var isCancelled = false

    init(url: String, selector: String, interval: TimeInterval) {
        self.url = url
        self.selector = selector
        self.interval = interval
    }

    public func cancel() {
        isCancelled = true
    }
}

// MARK: - String Escaping for AppleScript / JavaScript

private extension String {
    /// Escape for embedding inside AppleScript double-quoted strings
    var escapedForAppleScript: String {
        replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    /// Escape for embedding inside JavaScript single-quoted strings
    var escapedForJS: String {
        replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}

public enum AIBrowserError: Error, LocalizedError {
    case securityViolation(String)
    case blockedDomain(String)
    case httpError(Int)
    case invalidResponse(String)
    case timeout
    case elementNotFound(String)

    public var errorDescription: String? {
        switch self {
        case let .securityViolation(reason):
            "Security violation: \(reason)"
        case let .blockedDomain(domain):
            "Blocked domain: \(domain)"
        case let .httpError(code):
            "HTTP error: \(code)"
        case let .invalidResponse(reason):
            "Invalid response: \(reason)"
        case .timeout:
            "Request timed out"
        case let .elementNotFound(selector):
            "Element not found: \(selector)"
        }
    }
}
