import Foundation
#if os(macOS)
import WebKit
#endif

/// Browser automation service for web interaction (ChatGPT Agent equivalent)
/// Provides navigation, form filling, data extraction, and screenshot capture
///
/// Security Note: All user inputs are properly escaped to prevent JavaScript injection.
/// The WebView is configured with restricted permissions for security.
@MainActor
public final class BrowserAutomationService {
    // MARK: - Properties

    #if os(macOS)
    private var webView: WebViewWrapper?
    #endif
    private var navigationHistory: [URL] = []
    private var currentURL: URL?

    // MARK: - Initialization

    public init() {}

    // MARK: - Navigation

    /// Navigate to a URL
    public func navigate(to url: URL) async throws {
        #if os(macOS)
        if webView == nil {
            webView = WebViewWrapper()
        }

        try await webView?.load(url: url)
        currentURL = url
        navigationHistory.append(url)
        #else
        throw BrowserAutomationError.unsupportedPlatform
        #endif
    }

    /// Navigate to a URL string
    public func navigate(to urlString: String) async throws {
        guard let url = URL(string: urlString) else {
            throw BrowserAutomationError.invalidURL(urlString)
        }
        try await navigate(to: url)
    }

    /// Go back in navigation history
    public func goBack() async throws {
        #if os(macOS)
        guard let webView = webView else {
            throw BrowserAutomationError.noWebView
        }
        try await webView.goBack()
        #else
        throw BrowserAutomationError.unsupportedPlatform
        #endif
    }

    /// Go forward in navigation history
    public func goForward() async throws {
        #if os(macOS)
        guard let webView = webView else {
            throw BrowserAutomationError.noWebView
        }
        try await webView.goForward()
        #else
        throw BrowserAutomationError.unsupportedPlatform
        #endif
    }

    /// Reload current page
    public func reload() async throws {
        #if os(macOS)
        guard let webView = webView else {
            throw BrowserAutomationError.noWebView
        }
        try await webView.reload()
        #else
        throw BrowserAutomationError.unsupportedPlatform
        #endif
    }

    // MARK: - Form Interaction

    /// Fill a form field by selector
    /// - Parameters:
    ///   - selector: CSS selector for the element (safely escaped)
    ///   - value: Value to set (safely escaped)
    public func fillField(selector: String, value: String) async throws {
        #if os(macOS)
        guard let webView = webView else {
            throw BrowserAutomationError.noWebView
        }

        // Use JSON encoding to safely pass parameters
        let params = try encodeJSONParameters(["selector": selector, "value": value])
        let script = """
        (function() {
            const params = \(params);
            const el = document.querySelector(params.selector);
            if (el) { el.value = params.value; return true; }
            return false;
        })();
        """
        _ = try await webView.executeJavaScript(script)
        #else
        throw BrowserAutomationError.unsupportedPlatform
        #endif
    }

    /// Click an element by selector
    /// - Parameter selector: CSS selector for the element (safely escaped)
    public func click(selector: String) async throws {
        #if os(macOS)
        guard let webView = webView else {
            throw BrowserAutomationError.noWebView
        }

        let params = try encodeJSONParameters(["selector": selector])
        let script = """
        (function() {
            const params = \(params);
            const el = document.querySelector(params.selector);
            if (el) { el.click(); return true; }
            return false;
        })();
        """
        _ = try await webView.executeJavaScript(script)
        #else
        throw BrowserAutomationError.unsupportedPlatform
        #endif
    }

    /// Submit a form by selector
    /// - Parameter selector: CSS selector for the form (safely escaped)
    public func submitForm(selector: String) async throws {
        #if os(macOS)
        guard let webView = webView else {
            throw BrowserAutomationError.noWebView
        }

        let params = try encodeJSONParameters(["selector": selector])
        let script = """
        (function() {
            const params = \(params);
            const el = document.querySelector(params.selector);
            if (el) { el.submit(); return true; }
            return false;
        })();
        """
        _ = try await webView.executeJavaScript(script)
        #else
        throw BrowserAutomationError.unsupportedPlatform
        #endif
    }

    // MARK: - Data Extraction

    /// Extract text content by selector
    /// - Parameter selector: CSS selector for the element (safely escaped)
    /// - Returns: Text content of the element
    public func extractText(selector: String) async throws -> String {
        #if os(macOS)
        guard let webView = webView else {
            throw BrowserAutomationError.noWebView
        }

        let params = try encodeJSONParameters(["selector": selector])
        let script = """
        (function() {
            const params = \(params);
            const el = document.querySelector(params.selector);
            return el ? el.textContent : null;
        })();
        """
        let result = try await webView.executeJavaScript(script)

        guard let text = result as? String else {
            return ""
        }
        return text
        #else
        throw BrowserAutomationError.unsupportedPlatform
        #endif
    }

    /// Extract attribute value by selector
    /// - Parameters:
    ///   - selector: CSS selector for the element (safely escaped)
    ///   - attribute: Attribute name to extract (safely escaped)
    /// - Returns: Attribute value
    public func extractAttribute(selector: String, attribute: String) async throws -> String {
        #if os(macOS)
        guard let webView = webView else {
            throw BrowserAutomationError.noWebView
        }

        let params = try encodeJSONParameters(["selector": selector, "attribute": attribute])
        let script = """
        (function() {
            const params = \(params);
            const el = document.querySelector(params.selector);
            return el ? el.getAttribute(params.attribute) : null;
        })();
        """
        let result = try await webView.executeJavaScript(script)

        guard let value = result as? String else {
            return ""
        }
        return value
        #else
        throw BrowserAutomationError.unsupportedPlatform
        #endif
    }

    /// Extract all links on the page
    public func extractLinks() async throws -> [URL] {
        #if os(macOS)
        guard let webView = webView else {
            throw BrowserAutomationError.noWebView
        }

        // This script doesn't take user input, so it's safe
        let script = """
        Array.from(document.querySelectorAll('a')).map(a => a.href);
        """
        let result = try await webView.executeJavaScript(script)

        guard let urlStrings = result as? [String] else {
            return []
        }
        return urlStrings.compactMap { URL(string: $0) }
        #else
        throw BrowserAutomationError.unsupportedPlatform
        #endif
    }

    // MARK: - Screenshots

    /// Capture screenshot of current page
    public func captureScreenshot() async throws -> Data {
        #if os(macOS)
        guard let webView = webView else {
            throw BrowserAutomationError.noWebView
        }
        return try await webView.takeSnapshot()
        #else
        throw BrowserAutomationError.unsupportedPlatform
        #endif
    }

    // MARK: - Page Information

    /// Get current page title
    public func getTitle() async throws -> String {
        #if os(macOS)
        guard let webView = webView else {
            throw BrowserAutomationError.noWebView
        }
        return try await webView.getTitle()
        #else
        throw BrowserAutomationError.unsupportedPlatform
        #endif
    }

    /// Get current URL
    public func getCurrentURL() -> URL? {
        currentURL
    }

    /// Get navigation history
    public func getHistory() -> [URL] {
        navigationHistory
    }

    // MARK: - JavaScript Execution

    /// Execute arbitrary JavaScript
    /// - Warning: This method executes raw JavaScript. Ensure input is trusted or sanitized.
    /// - Parameter script: JavaScript code to execute
    /// - Returns: Result of execution as string, if any
    public func executeJavaScript(_ script: String) async throws -> String? {
        #if os(macOS)
        guard let webView = webView else {
            throw BrowserAutomationError.noWebView
        }
        let result = try await webView.executeJavaScript(script)
        return result as? String
        #else
        throw BrowserAutomationError.unsupportedPlatform
        #endif
    }

    // MARK: - Cleanup

    /// Close the web view
    public func close() async {
        #if os(macOS)
        webView = nil
        #endif
        currentURL = nil
    }
    
    // MARK: - Security Helpers
    
    /// Encode parameters as JSON for safe JavaScript injection
    /// This prevents injection attacks by properly escaping all values
    private func encodeJSONParameters(_ params: [String: String]) throws -> String {
        let data = try JSONEncoder().encode(params)
        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw BrowserAutomationError.extractionFailed("Failed to encode parameters")
        }
        return jsonString
    }
}

// MARK: - WebView Wrapper (macOS only)

#if os(macOS)
@MainActor
private final class WebViewWrapper: NSObject, WKNavigationDelegate {
    private let webView: WKWebView
    private var navigationContinuation: CheckedContinuation<Void, Error>?

    override init() {
        let configuration = WKWebViewConfiguration()
        // SECURITY: Disable file access from file URLs to prevent local file exfiltration
        // This was previously enabled which allowed JavaScript to read local files
        configuration.preferences.setValue(false, forKey: "allowFileAccessFromFileURLs")
        
        // SECURITY: Set additional security preferences
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        
        self.webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()
        webView.navigationDelegate = self
    }

    func load(url: URL) async throws {
        try await withCheckedThrowingContinuation { continuation in
            navigationContinuation = continuation
            webView.load(URLRequest(url: url))
        }
    }

    func goBack() async throws {
        guard webView.canGoBack else {
            throw BrowserAutomationError.cannotNavigate("No back history")
        }
        return try await withCheckedThrowingContinuation { continuation in
            navigationContinuation = continuation
            webView.goBack()
        }
    }

    func goForward() async throws {
        guard webView.canGoForward else {
            throw BrowserAutomationError.cannotNavigate("No forward history")
        }
        return try await withCheckedThrowingContinuation { continuation in
            navigationContinuation = continuation
            webView.goForward()
        }
    }

    func reload() async throws {
        try await withCheckedThrowingContinuation { continuation in
            navigationContinuation = continuation
            webView.reload()
        }
    }

    func executeJavaScript(_ script: String) async throws -> Any? {
        try await webView.evaluateJavaScript(script)
    }

    func takeSnapshot() async throws -> Data {
        let config = WKSnapshotConfiguration()
        let image = try await webView.takeSnapshot(configuration: config)

        guard let tiffData = image.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
            throw BrowserAutomationError.screenshotFailed
        }
        return pngData
    }

    func getTitle() async throws -> String {
        webView.title ?? ""
    }

    // MARK: - WKNavigationDelegate

    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor in
            navigationContinuation?.resume()
            navigationContinuation = nil
        }
    }

    nonisolated func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in
            navigationContinuation?.resume(throwing: error)
            navigationContinuation = nil
        }
    }

    nonisolated func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in
            navigationContinuation?.resume(throwing: error)
            navigationContinuation = nil
        }
    }
}
#endif

// MARK: - Errors

public enum BrowserAutomationError: Error, LocalizedError, Sendable {
    case unsupportedPlatform
    case noWebView
    case invalidURL(String)
    case cannotNavigate(String)
    case extractionFailed(String)
    case screenshotFailed

    public var errorDescription: String? {
        switch self {
        case .unsupportedPlatform:
            return "Browser automation is only supported on macOS"
        case .noWebView:
            return "No web view available. Navigate to a URL first."
        case .invalidURL(let url):
            return "Invalid URL: \(url)"
        case .cannotNavigate(let reason):
            return "Cannot navigate: \(reason)"
        case .extractionFailed(let reason):
            return "Data extraction failed: \(reason)"
        case .screenshotFailed:
            return "Failed to capture screenshot"
        }
    }
}
