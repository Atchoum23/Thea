// ScreenAnalyzer.swift
// Thea
//
// Coordinates screen capture (via ScreenCapture actor) and text recognition
// (via VisionOCR actor) to produce analyzable screen states for the
// browser automation orchestrator. Includes differential analysis to
// detect meaningful screen changes between cycles.

#if os(macOS)

    import AppKit
    import Foundation
    import os.log

    // MARK: - Screen State

    /// A snapshot of the current screen state including visual content and metadata.
    public struct ScreenState: Sendable {
        public let image: CGImage
        public let text: String
        public let ocrResults: [VisionOCR.OCRResult]
        public let timestamp: Date
        public let windowTitle: String?
        public let activeApp: String?
        public let activeAppBundleId: String?

        /// Number of distinct text blocks recognized
        public var textBlockCount: Int { ocrResults.count }

        /// Whether any text was found on screen
        public var hasText: Bool { !ocrResults.isEmpty }
    }

    // MARK: - Screen Diff

    /// Represents the differences between two consecutive screen states.
    public struct ScreenDiff: Sendable {
        public let addedTexts: Set<String>
        public let removedTexts: Set<String>
        public let appChanged: Bool
        public let windowTitleChanged: Bool
        public let timeDelta: TimeInterval

        /// Whether the change is significant enough to warrant AI analysis
        public var hasSignificantChange: Bool {
            appChanged
                || windowTitleChanged
                || addedTexts.count > 3
                || removedTexts.count > 3
        }

        /// Quick summary for logging
        public var summary: String {
            var parts: [String] = []
            if appChanged { parts.append("app changed") }
            if windowTitleChanged { parts.append("window title changed") }
            if !addedTexts.isEmpty { parts.append("+\(addedTexts.count) text blocks") }
            if !removedTexts.isEmpty { parts.append("-\(removedTexts.count) text blocks") }
            return parts.isEmpty ? "no change" : parts.joined(separator: ", ")
        }
    }

    // MARK: - Screen Analyzer

    /// Captures and analyzes screen content for browser automation.
    /// Combines ScreenCapture (images) with VisionOCR (text recognition)
    /// and adds contextual metadata (active app, window title).
    @MainActor
    public final class ScreenAnalyzer {
        public static let shared = ScreenAnalyzer()

        private let logger = Logger(subsystem: "ai.thea.app", category: "ScreenAnalyzer")

        // MARK: - Configuration

        /// Use fast OCR (less accurate but ~3x faster) vs accurate OCR
        public var useFastOCR: Bool = true

        /// Maximum number of OCR results to include in state
        public var maxOCRResults: Int = 200

        private init() {}

        // MARK: - Capture & Analyze

        /// Capture the current screen and run OCR to produce a ScreenState.
        ///
        /// This is the primary method called each cycle of the automation loop.
        /// It captures a screenshot, runs text recognition, and assembles
        /// contextual metadata.
        public func captureAndAnalyze() async throws -> ScreenState {
            logger.debug("Capturing screen state")

            // Capture screenshot via existing ScreenCapture actor
            let image = try await ScreenCapture.shared.captureScreen()

            // Run OCR via existing VisionOCR actor
            let ocrResults: [VisionOCR.OCRResult]
            if useFastOCR {
                ocrResults = try await VisionOCR.shared.recognizeTextFast(in: image)
            } else {
                ocrResults = try await VisionOCR.shared.recognizeText(in: image)
            }

            // Limit results and sort top-to-bottom for reading order
            let limitedResults = Array(
                ocrResults
                    .sorted { $0.boundingBox.minY > $1.boundingBox.minY }
                    .prefix(maxOCRResults)
            )

            // Build full text from OCR results in reading order
            let fullText = limitedResults
                .map(\.text)
                .joined(separator: "\n")

            // Get active app metadata
            let activeApp = NSWorkspace.shared.frontmostApplication
            let windowTitle = getActiveWindowTitle()

            return ScreenState(
                image: image,
                text: fullText,
                ocrResults: limitedResults,
                timestamp: Date(),
                windowTitle: windowTitle,
                activeApp: activeApp?.localizedName,
                activeAppBundleId: activeApp?.bundleIdentifier
            )
        }

        /// Capture a specific window by its title (partial match).
        public func captureWindow(titled title: String) async throws -> ScreenState {
            logger.debug("Capturing window: \(title)")

            let image = try await ScreenCapture.shared.captureWindow(named: title)

            let ocrResults: [VisionOCR.OCRResult]
            if useFastOCR {
                ocrResults = try await VisionOCR.shared.recognizeTextFast(in: image)
            } else {
                ocrResults = try await VisionOCR.shared.recognizeText(in: image)
            }

            let limitedResults = Array(
                ocrResults
                    .sorted { $0.boundingBox.minY > $1.boundingBox.minY }
                    .prefix(maxOCRResults)
            )

            let fullText = limitedResults.map(\.text).joined(separator: "\n")

            return ScreenState(
                image: image,
                text: fullText,
                ocrResults: limitedResults,
                timestamp: Date(),
                windowTitle: title,
                activeApp: NSWorkspace.shared.frontmostApplication?.localizedName,
                activeAppBundleId: NSWorkspace.shared.frontmostApplication?.bundleIdentifier
            )
        }

        // MARK: - Differential Analysis

        /// Compute the differences between two screen states.
        ///
        /// Uses set comparison on OCR text blocks to efficiently identify
        /// what content appeared/disappeared. This allows the AI to focus
        /// on changes rather than re-analyzing the entire screen.
        public func computeDiff(
            previous: ScreenState,
            current: ScreenState
        ) -> ScreenDiff {
            let prevTexts = Set(previous.ocrResults.map(\.text))
            let currTexts = Set(current.ocrResults.map(\.text))

            return ScreenDiff(
                addedTexts: currTexts.subtracting(prevTexts),
                removedTexts: prevTexts.subtracting(currTexts),
                appChanged: previous.activeApp != current.activeApp,
                windowTitleChanged: previous.windowTitle != current.windowTitle,
                timeDelta: current.timestamp.timeIntervalSince(previous.timestamp)
            )
        }

        /// Find specific text on screen and return its location.
        ///
        /// Useful for the automation orchestrator to locate buttons, fields,
        /// or other UI elements by their text content.
        public func findText(_ searchText: String, in state: ScreenState) -> VisionOCR.OCRResult? {
            let lowered = searchText.lowercased()
            return state.ocrResults.first {
                $0.text.lowercased().contains(lowered)
            }
        }

        /// Find all occurrences of text on screen.
        public func findAllText(_ searchText: String, in state: ScreenState) -> [VisionOCR.OCRResult] {
            let lowered = searchText.lowercased()
            return state.ocrResults.filter {
                $0.text.lowercased().contains(lowered)
            }
        }

        // MARK: - Window Title (Accessibility)

        private func getActiveWindowTitle() -> String? {
            guard let app = NSWorkspace.shared.frontmostApplication else { return nil }

            let appRef = AXUIElementCreateApplication(app.processIdentifier)

            var windowRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(
                appRef,
                kAXFocusedWindowAttribute as CFString,
                &windowRef
            ) == .success else {
                return nil
            }

            // swiftlint:disable:next force_cast
            let windowElement = windowRef as! AXUIElement

            var titleRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(
                windowElement,
                kAXTitleAttribute as CFString,
                &titleRef
            ) == .success else {
                return nil
            }

            return titleRef as? String
        }
    }

#endif
