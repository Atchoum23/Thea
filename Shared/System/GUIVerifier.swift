import CoreGraphics
import Foundation
import OSLog

// MARK: - GUIVerifier
// Visual verification of GUI actions using screenshot + OCR

public actor GUIVerifier {
    public static let shared = GUIVerifier()

    private let logger = Logger(subsystem: "com.thea.system", category: "GUIVerifier")

    private init() {}

    // MARK: - Public Types

    public struct VerificationResult: Sendable {
        public let success: Bool
        public let confidence: Double
        public let screenshot: Data?
        public let recognizedText: [String]
        public let failureReason: String?

        public init(
            success: Bool,
            confidence: Double,
            screenshot: Data?,
            recognizedText: [String],
            failureReason: String?
        ) {
            self.success = success
            self.confidence = confidence
            self.screenshot = screenshot
            self.recognizedText = recognizedText
            self.failureReason = failureReason
        }
    }

    public enum VerificationError: LocalizedError, Sendable {
        case screenshotFailed
        case ocrFailed
        case verificationFailed(String)

        public var errorDescription: String? {
            switch self {
            case .screenshotFailed:
                return "Failed to capture screenshot"
            case .ocrFailed:
                return "Failed to perform OCR"
            case .verificationFailed(let message):
                return "Verification failed: \(message)"
            }
        }
    }

    // MARK: - Verify Expected Text

    public func verifyExpectedText(
        _ expectedText: String,
        waitSeconds: TimeInterval = 0.5
    ) async throws -> VerificationResult {
        logger.info("Verifying expected text: '\(expectedText)'")

        // Wait for UI to settle
        if waitSeconds > 0 {
            try await Task.sleep(nanoseconds: UInt64(waitSeconds * 1_000_000_000))
        }

        // Capture screenshot
        let screenshot: CGImage
        do {
            screenshot = try await ScreenCapture.shared.captureScreen()
        } catch {
            throw VerificationError.screenshotFailed
        }

        // Run OCR
        let ocrResults: [VisionOCR.OCRResult]
        do {
            ocrResults = try await VisionOCR.shared.recognizeText(in: screenshot)
        } catch {
            throw VerificationError.ocrFailed
        }

        let recognizedText = ocrResults.map { $0.text }
        logger.info("Recognized \(recognizedText.count) text blocks")

        // Check if expected outcome is present
        let matches = recognizedText.filter { text in
            text.localizedCaseInsensitiveContains(expectedText)
        }

        let outcomeFound = !matches.isEmpty
        let confidence = outcomeFound ? 0.9 : 0.1

        // Convert screenshot to PNG data
        var screenshotData: Data?
        #if os(macOS)
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("verification_\(UUID().uuidString).png")
        try? await ScreenCapture.shared.saveToFile(screenshot, path: tempURL.path)
        screenshotData = try? Data(contentsOf: tempURL)
        try? FileManager.default.removeItem(at: tempURL)
        #endif

        let result = VerificationResult(
            success: outcomeFound,
            confidence: confidence,
            screenshot: screenshotData,
            recognizedText: recognizedText,
            failureReason: outcomeFound ? nil : "Expected '\(expectedText)' not found in screen. Found: \(recognizedText.prefix(5).joined(separator: ", "))"
        )

        if result.success {
            logger.info("✅ Verification successful: found '\(expectedText)'")
        } else {
            logger.warning("❌ Verification failed: \(result.failureReason ?? "unknown")")
        }

        return result
    }

    // MARK: - Verify Window Title

    public func verifyWindowTitle(
        _ expectedTitle: String,
        waitSeconds: TimeInterval = 0.5
    ) async throws -> VerificationResult {
        logger.info("Verifying window title: '\(expectedTitle)'")

        // Wait for UI to settle
        if waitSeconds > 0 {
            try await Task.sleep(nanoseconds: UInt64(waitSeconds * 1_000_000_000))
        }

        // Capture screenshot (top portion where title usually is)
        let titleRegion = CGRect(x: 0, y: 0, width: 1_000, height: 100)
        let screenshot: CGImage
        do {
            screenshot = try await ScreenCapture.shared.captureRegion(titleRegion)
        } catch {
            throw VerificationError.screenshotFailed
        }

        // Run OCR
        let ocrResults: [VisionOCR.OCRResult]
        do {
            ocrResults = try await VisionOCR.shared.recognizeText(in: screenshot)
        } catch {
            throw VerificationError.ocrFailed
        }

        let recognizedText = ocrResults.map { $0.text }

        // Check for title
        let titleFound = recognizedText.contains { text in
            text.localizedCaseInsensitiveContains(expectedTitle)
        }

        return VerificationResult(
            success: titleFound,
            confidence: titleFound ? 0.9 : 0.1,
            screenshot: nil,
            recognizedText: recognizedText,
            failureReason: titleFound ? nil : "Window title '\(expectedTitle)' not found"
        )
    }

    // MARK: - Verify Build Success

    public func verifyBuildSuccess(waitSeconds: TimeInterval = 1.0) async throws -> VerificationResult {
        logger.info("Verifying build success message")

        // Common build success indicators
        let successIndicators = ["BUILD SUCCEEDED", "Build succeeded", "✓ Build"]

        // Wait for build to complete
        if waitSeconds > 0 {
            try await Task.sleep(nanoseconds: UInt64(waitSeconds * 1_000_000_000))
        }

        // Capture screenshot
        let screenshot = try await ScreenCapture.shared.captureScreen()

        // Run OCR
        let ocrResults = try await VisionOCR.shared.recognizeText(in: screenshot)
        let recognizedText = ocrResults.map { $0.text }

        // Check for success indicators
        let foundIndicator = successIndicators.first { indicator in
            recognizedText.contains { text in
                text.localizedCaseInsensitiveContains(indicator)
            }
        }

        let success = foundIndicator != nil

        return VerificationResult(
            success: success,
            confidence: success ? 0.95 : 0.1,
            screenshot: nil,
            recognizedText: recognizedText,
            failureReason: success ? nil : "Build success message not found on screen"
        )
    }

    // MARK: - Custom Verification

    public func verifyCustomCondition(
        condition: @Sendable ([ String]) -> Bool,
        waitSeconds: TimeInterval = 0.5
    ) async throws -> VerificationResult {
        logger.info("Running custom verification")

        if waitSeconds > 0 {
            try await Task.sleep(nanoseconds: UInt64(waitSeconds * 1_000_000_000))
        }

        let screenshot = try await ScreenCapture.shared.captureScreen()
        let ocrResults = try await VisionOCR.shared.recognizeText(in: screenshot)
        let recognizedText = ocrResults.map { $0.text }

        let success = condition(recognizedText)

        return VerificationResult(
            success: success,
            confidence: success ? 0.9 : 0.1,
            screenshot: nil,
            recognizedText: recognizedText,
            failureReason: success ? nil : "Custom condition not met"
        )
    }
}
