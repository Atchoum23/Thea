import Foundation
import WebKit

// MARK: - Browser Automation
// Automated web browsing, scraping, and interaction

@MainActor
final class BrowserAutomation: NSObject {
  static let shared = BrowserAutomation()

  private var webView: WKWebView?
  private var navigationDelegate: WebNavigationDelegate?

  private override init() {
    super.init()
    setupWebView()
  }

  private func setupWebView() {
    let configuration = WKWebViewConfiguration()
    configuration.websiteDataStore = .nonPersistent()

    webView = WKWebView(frame: .zero, configuration: configuration)
    navigationDelegate = WebNavigationDelegate()
    webView?.navigationDelegate = navigationDelegate
  }

  // MARK: - Navigation

  func navigate(to url: URL) async throws -> String {
    guard let webView = webView else {
      throw BrowserError.notInitialized
    }

    return try await withCheckedThrowingContinuation { continuation in
      navigationDelegate?.onComplete = { html in
        continuation.resume(returning: html)
      }
      navigationDelegate?.onError = { error in
        continuation.resume(throwing: error)
      }

      webView.load(URLRequest(url: url))
    }
  }

  // MARK: - Element Interaction

  func click(selector: String) async throws {
    guard let webView = webView else {
      throw BrowserError.notInitialized
    }

    let script = """
      document.querySelector('\(selector)').click();
      """

    try await webView.evaluateJavaScript(script)
  }

  func type(text: String, in selector: String) async throws {
    guard let webView = webView else {
      throw BrowserError.notInitialized
    }

    let script = """
      var element = document.querySelector('\(selector)');
      element.value = '\(text)';
      element.dispatchEvent(new Event('input', { bubbles: true }));
      """

    try await webView.evaluateJavaScript(script)
  }

  // MARK: - Data Extraction

  func extractText(from selector: String) async throws -> String {
    guard let webView = webView else {
      throw BrowserError.notInitialized
    }

    let script = """
      document.querySelector('\(selector)').innerText;
      """

    let result = try await webView.evaluateJavaScript(script)
    return result as? String ?? ""
  }

  func extractHTML(from selector: String) async throws -> String {
    guard let webView = webView else {
      throw BrowserError.notInitialized
    }

    let script = """
      document.querySelector('\(selector)').innerHTML;
      """

    let result = try await webView.evaluateJavaScript(script)
    return result as? String ?? ""
  }

  func extractAllLinks() async throws -> [String] {
    guard let webView = webView else {
      throw BrowserError.notInitialized
    }

    let script = """
      Array.from(document.querySelectorAll('a')).map(a => a.href);
      """

    let result = try await webView.evaluateJavaScript(script)
    return result as? [String] ?? []
  }

  // MARK: - Screenshots

  func takeScreenshot() async throws -> Data {
    guard let webView = webView else {
      throw BrowserError.notInitialized
    }

    let configuration = WKSnapshotConfiguration()
    let image = try await webView.takeSnapshot(configuration: configuration)

    #if os(macOS)
      guard let tiffData = image.tiffRepresentation,
        let bitmapImage = NSBitmapImageRep(data: tiffData),
        let pngData = bitmapImage.representation(using: .png, properties: [:])
      else {
        throw BrowserError.screenshotFailed
      }
      return pngData
    #else
      guard let pngData = image.pngData() else {
        throw BrowserError.screenshotFailed
      }
      return pngData
    #endif
  }

  // MARK: - Form Handling

  func fillForm(_ fields: [String: String]) async throws {
    for (selector, value) in fields {
      try await type(text: value, in: selector)
    }
  }

  func submitForm(_ selector: String) async throws {
    guard let webView = webView else {
      throw BrowserError.notInitialized
    }

    let script = """
      document.querySelector('\(selector)').submit();
      """

    try await webView.evaluateJavaScript(script)
  }

  // MARK: - Waiting

  func waitForElement(_ selector: String, timeout: TimeInterval = 10) async throws {
    guard let webView = webView else {
      throw BrowserError.notInitialized
    }

    let startTime = Date()

    while Date().timeIntervalSince(startTime) < timeout {
      let script = """
        document.querySelector('\(selector)') !== null;
        """

      if let exists = try await webView.evaluateJavaScript(script) as? Bool, exists {
        return
      }

      try await Task.sleep(nanoseconds: 100_000_000)  // 100ms
    }

    throw BrowserError.elementNotFound
  }
}

// MARK: - Navigation Delegate

@MainActor
class WebNavigationDelegate: NSObject, WKNavigationDelegate {
  var onComplete: ((String) -> Void)?
  var onError: ((Error) -> Void)?

  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    webView.evaluateJavaScript("document.documentElement.outerHTML") { html, error in
      if let error = error {
        self.onError?(error)
      } else if let html = html as? String {
        self.onComplete?(html)
      }
    }
  }

  func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
    onError?(error)
  }
}

// MARK: - Errors

enum BrowserError: LocalizedError {
  case notInitialized
  case navigationFailed
  case elementNotFound
  case screenshotFailed

  var errorDescription: String? {
    switch self {
    case .notInitialized:
      return "Browser not initialized"
    case .navigationFailed:
      return "Navigation failed"
    case .elementNotFound:
      return "Element not found"
    case .screenshotFailed:
      return "Screenshot failed"
    }
  }
}
