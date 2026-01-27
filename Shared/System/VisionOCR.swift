import CoreGraphics
import Foundation
import OSLog

#if os(macOS) || os(iOS)
    import Vision
#endif

// MARK: - VisionOCR

// Text recognition using Apple Vision framework

public actor VisionOCR {
    public static let shared = VisionOCR()

    private let logger = Logger(subsystem: "com.thea.system", category: "VisionOCR")

    private init() {}

    // MARK: - Public Types

    public struct OCRResult: Sendable, Identifiable {
        public let id: UUID
        public let text: String
        public let boundingBox: CGRect
        public let confidence: Float

        public init(text: String, boundingBox: CGRect, confidence: Float) {
            id = UUID()
            self.text = text
            self.boundingBox = boundingBox
            self.confidence = confidence
        }
    }

    public enum OCRError: LocalizedError, Sendable {
        case notSupported
        case recognitionFailed(String)
        case noTextFound

        public var errorDescription: String? {
            switch self {
            case .notSupported:
                "OCR is not supported on this platform"
            case let .recognitionFailed(message):
                "Text recognition failed: \(message)"
            case .noTextFound:
                "No text found in image"
            }
        }
    }

    // MARK: - Recognize Text

    public func recognizeText(in image: CGImage) async throws -> [OCRResult] {
        #if os(macOS) || os(iOS)
            logger.info("Starting text recognition")

            return try await withCheckedThrowingContinuation { continuation in
                let request = VNRecognizeTextRequest { request, error in
                    if let error {
                        continuation.resume(throwing: OCRError.recognitionFailed(error.localizedDescription))
                        return
                    }

                    guard let observations = request.results as? [VNRecognizedTextObservation] else {
                        continuation.resume(throwing: OCRError.noTextFound)
                        return
                    }

                    let results = observations.compactMap { observation -> OCRResult? in
                        guard let candidate = observation.topCandidates(1).first else {
                            return nil
                        }

                        return OCRResult(
                            text: candidate.string,
                            boundingBox: observation.boundingBox,
                            confidence: candidate.confidence
                        )
                    }

                    if results.isEmpty {
                        continuation.resume(throwing: OCRError.noTextFound)
                    } else {
                        continuation.resume(returning: results)
                    }
                }

                // Configure for accurate recognition
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true

                // Perform request
                let handler = VNImageRequestHandler(cgImage: image, options: [:])

                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(throwing: OCRError.recognitionFailed(error.localizedDescription))
                }
            }
        #else
            throw OCRError.notSupported
        #endif
    }

    // MARK: - Find Text

    public func findText(_ searchText: String, in image: CGImage) async throws -> [OCRResult] {
        let allResults = try await recognizeText(in: image)

        let matches = allResults.filter { result in
            result.text.localizedCaseInsensitiveContains(searchText)
        }

        logger.info("Found \(matches.count) matches for '\(searchText)'")
        return matches
    }

    // MARK: - Extract All Text

    public func extractAllText(from image: CGImage) async throws -> String {
        let results = try await recognizeText(in: image)

        let allText = results
            .sorted { $0.boundingBox.minY > $1.boundingBox.minY } // Sort top to bottom
            .map(\.text)
            .joined(separator: "\n")

        logger.info("Extracted \(results.count) text blocks")
        return allText
    }

    // MARK: - Fast Recognition

    public func recognizeTextFast(in image: CGImage) async throws -> [OCRResult] {
        #if os(macOS) || os(iOS)
            logger.info("Starting fast text recognition")

            return try await withCheckedThrowingContinuation { continuation in
                let request = VNRecognizeTextRequest { request, error in
                    if let error {
                        continuation.resume(throwing: OCRError.recognitionFailed(error.localizedDescription))
                        return
                    }

                    guard let observations = request.results as? [VNRecognizedTextObservation] else {
                        continuation.resume(throwing: OCRError.noTextFound)
                        return
                    }

                    let results = observations.compactMap { observation -> OCRResult? in
                        guard let candidate = observation.topCandidates(1).first else {
                            return nil
                        }

                        return OCRResult(
                            text: candidate.string,
                            boundingBox: observation.boundingBox,
                            confidence: candidate.confidence
                        )
                    }

                    if results.isEmpty {
                        continuation.resume(throwing: OCRError.noTextFound)
                    } else {
                        continuation.resume(returning: results)
                    }
                }

                // Configure for fast recognition
                request.recognitionLevel = .fast
                request.usesLanguageCorrection = false

                // Perform request
                let handler = VNImageRequestHandler(cgImage: image, options: [:])

                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(throwing: OCRError.recognitionFailed(error.localizedDescription))
                }
            }
        #else
            throw OCRError.notSupported
        #endif
    }
}
