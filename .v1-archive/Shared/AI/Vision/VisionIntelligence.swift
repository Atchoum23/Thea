// VisionIntelligence.swift
// AI-powered vision capabilities for image understanding, OCR, and visual analysis

import Foundation
import OSLog
#if canImport(Vision)
    import Vision
#endif
#if canImport(CoreImage)
    import CoreImage
#endif

// MARK: - Vision Intelligence

/// AI-powered vision capabilities for multi-modal input
@MainActor
public final class VisionIntelligence: ObservableObject {
    public static let shared = VisionIntelligence()

    private let logger = Logger(subsystem: "com.thea.app", category: "VisionIntelligence")

    // MARK: - Published State

    @Published public private(set) var isProcessing = false
    @Published public private(set) var lastResult: VisionResult?
    @Published public private(set) var supportedFeatures: Set<VisionFeature> = []

    // MARK: - Initialization

    private init() {
        detectSupportedFeatures()
    }

    // MARK: - Feature Detection

    private func detectSupportedFeatures() {
        var features: Set<VisionFeature> = []

        #if canImport(Vision)
            features.insert(.textRecognition)
            features.insert(.objectDetection)
            features.insert(.faceDetection)
            features.insert(.barcodeDetection)

            if #available(macOS 14.0, iOS 17.0, *) {
                features.insert(.documentDetection)
                features.insert(.subjectLifting)
            }
        #endif

        supportedFeatures = features
        logger.info("Vision features detected: \(features.map(\.rawValue).joined(separator: ", "))")
    }

    // MARK: - Text Recognition (OCR)

    /// Recognize text from an image
    public func recognizeText(from imageData: Data, languages: [String] = ["en"]) async throws -> TextRecognitionResult {
        guard supportedFeatures.contains(.textRecognition) else {
            throw VisionError.featureNotSupported(.textRecognition)
        }

        isProcessing = true
        defer { isProcessing = false }

        #if canImport(Vision)
            guard let cgImage = createCGImage(from: imageData) else {
                throw VisionError.invalidImage
            }

            return try await withCheckedThrowingContinuation { continuation in
                let request = VNRecognizeTextRequest { request, error in
                    if let error {
                        continuation.resume(throwing: VisionError.processingFailed(error.localizedDescription))
                        return
                    }

                    guard let observations = request.results as? [VNRecognizedTextObservation] else {
                        continuation.resume(returning: TextRecognitionResult(text: "", blocks: [], confidence: 0))
                        return
                    }

                    var fullText = ""
                    var blocks: [TextBlock] = []
                    var totalConfidence: Float = 0

                    for observation in observations {
                        if let topCandidate = observation.topCandidates(1).first {
                            fullText += topCandidate.string + "\n"
                            totalConfidence += topCandidate.confidence

                            blocks.append(TextBlock(
                                text: topCandidate.string,
                                boundingBox: observation.boundingBox,
                                confidence: topCandidate.confidence
                            ))
                        }
                    }

                    let avgConfidence = observations.isEmpty ? 0 : totalConfidence / Float(observations.count)

                    continuation.resume(returning: TextRecognitionResult(
                        text: fullText.trimmingCharacters(in: .whitespacesAndNewlines),
                        blocks: blocks,
                        confidence: avgConfidence
                    ))
                }

                request.recognitionLevel = .accurate
                request.recognitionLanguages = languages
                request.usesLanguageCorrection = true

                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(throwing: VisionError.processingFailed(error.localizedDescription))
                }
            }
        #else
            throw VisionError.featureNotSupported(.textRecognition)
        #endif
    }

    // MARK: - Object Detection

    /// Detect objects in an image
    public func detectObjects(from imageData: Data) async throws -> [DetectedObject] {
        guard supportedFeatures.contains(.objectDetection) else {
            throw VisionError.featureNotSupported(.objectDetection)
        }

        isProcessing = true
        defer { isProcessing = false }

        #if canImport(Vision)
            guard let cgImage = createCGImage(from: imageData) else {
                throw VisionError.invalidImage
            }

            return try await withCheckedThrowingContinuation { continuation in
                let request = VNRecognizeAnimalsRequest { request, error in
                    if let error {
                        continuation.resume(throwing: VisionError.processingFailed(error.localizedDescription))
                        return
                    }

                    guard let observations = request.results as? [VNRecognizedObjectObservation] else {
                        continuation.resume(returning: [])
                        return
                    }

                    let objects = observations.map { observation -> DetectedObject in
                        let labels = observation.labels.prefix(3).map { label in
                            ObjectLabel(
                                identifier: label.identifier,
                                confidence: label.confidence
                            )
                        }

                        return DetectedObject(
                            labels: Array(labels),
                            boundingBox: observation.boundingBox,
                            confidence: observation.confidence
                        )
                    }

                    continuation.resume(returning: objects)
                }

                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(throwing: VisionError.processingFailed(error.localizedDescription))
                }
            }
        #else
            throw VisionError.featureNotSupported(.objectDetection)
        #endif
    }

    // MARK: - Face Detection

    /// Detect faces in an image
    public func detectFaces(from imageData: Data) async throws -> [DetectedFace] {
        guard supportedFeatures.contains(.faceDetection) else {
            throw VisionError.featureNotSupported(.faceDetection)
        }

        isProcessing = true
        defer { isProcessing = false }

        #if canImport(Vision)
            guard let cgImage = createCGImage(from: imageData) else {
                throw VisionError.invalidImage
            }

            return try await withCheckedThrowingContinuation { continuation in
                let request = VNDetectFaceRectanglesRequest { request, error in
                    if let error {
                        continuation.resume(throwing: VisionError.processingFailed(error.localizedDescription))
                        return
                    }

                    guard let observations = request.results as? [VNFaceObservation] else {
                        continuation.resume(returning: [])
                        return
                    }

                    let faces = observations.map { observation -> DetectedFace in
                        DetectedFace(
                            boundingBox: observation.boundingBox,
                            confidence: observation.confidence,
                            roll: observation.roll?.floatValue,
                            yaw: observation.yaw?.floatValue
                        )
                    }

                    continuation.resume(returning: faces)
                }

                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(throwing: VisionError.processingFailed(error.localizedDescription))
                }
            }
        #else
            throw VisionError.featureNotSupported(.faceDetection)
        #endif
    }

    // MARK: - Barcode Detection

    /// Detect barcodes and QR codes in an image
    public func detectBarcodes(from imageData: Data) async throws -> [DetectedBarcode] {
        guard supportedFeatures.contains(.barcodeDetection) else {
            throw VisionError.featureNotSupported(.barcodeDetection)
        }

        isProcessing = true
        defer { isProcessing = false }

        #if canImport(Vision)
            guard let cgImage = createCGImage(from: imageData) else {
                throw VisionError.invalidImage
            }

            return try await withCheckedThrowingContinuation { continuation in
                let request = VNDetectBarcodesRequest { request, error in
                    if let error {
                        continuation.resume(throwing: VisionError.processingFailed(error.localizedDescription))
                        return
                    }

                    guard let observations = request.results as? [VNBarcodeObservation] else {
                        continuation.resume(returning: [])
                        return
                    }

                    let barcodes = observations.compactMap { observation -> DetectedBarcode? in
                        guard let payload = observation.payloadStringValue else { return nil }

                        return DetectedBarcode(
                            payload: payload,
                            symbology: observation.symbology.rawValue,
                            boundingBox: observation.boundingBox,
                            confidence: observation.confidence
                        )
                    }

                    continuation.resume(returning: barcodes)
                }

                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(throwing: VisionError.processingFailed(error.localizedDescription))
                }
            }
        #else
            throw VisionError.featureNotSupported(.barcodeDetection)
        #endif
    }

    // MARK: - Document Detection

    /// Detect and extract documents from an image
    @available(macOS 14.0, iOS 17.0, *)
    public func detectDocument(from imageData: Data) async throws -> DetectedDocument? {
        guard supportedFeatures.contains(.documentDetection) else {
            throw VisionError.featureNotSupported(.documentDetection)
        }

        isProcessing = true
        defer { isProcessing = false }

        #if canImport(Vision)
            guard let cgImage = createCGImage(from: imageData) else {
                throw VisionError.invalidImage
            }

            return try await withCheckedThrowingContinuation { continuation in
                let request = VNDetectDocumentSegmentationRequest { request, error in
                    if let error {
                        continuation.resume(throwing: VisionError.processingFailed(error.localizedDescription))
                        return
                    }

                    guard let observation = request.results?.first as? VNRectangleObservation else {
                        continuation.resume(returning: nil)
                        return
                    }

                    let document = DetectedDocument(
                        topLeft: observation.topLeft,
                        topRight: observation.topRight,
                        bottomLeft: observation.bottomLeft,
                        bottomRight: observation.bottomRight,
                        confidence: observation.confidence
                    )

                    continuation.resume(returning: document)
                }

                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(throwing: VisionError.processingFailed(error.localizedDescription))
                }
            }
        #else
            throw VisionError.featureNotSupported(.documentDetection)
        #endif
    }

    // MARK: - Image Analysis for AI

    /// Analyze an image and generate a description for AI context
    public func analyzeForAI(imageData: Data) async throws -> ImageAnalysis {
        isProcessing = true
        defer { isProcessing = false }

        // Run multiple analyses in parallel
        async let textResult = try? recognizeText(from: imageData)
        async let objectsResult = try? detectObjects(from: imageData)
        async let facesResult = try? detectFaces(from: imageData)
        async let barcodesResult = try? detectBarcodes(from: imageData)

        let text = await textResult
        let objects = await objectsResult ?? []
        let faces = await facesResult ?? []
        let barcodes = await barcodesResult ?? []

        // Build analysis summary
        var summary = ""

        if let textContent = text?.text, !textContent.isEmpty {
            summary += "Text detected: \(textContent.prefix(500))\n"
        }

        if !objects.isEmpty {
            let labels = objects.flatMap { $0.labels.map(\.identifier) }.prefix(10)
            summary += "Objects detected: \(labels.joined(separator: ", "))\n"
        }

        if !faces.isEmpty {
            summary += "Faces detected: \(faces.count)\n"
        }

        if !barcodes.isEmpty {
            summary += "Barcodes detected: \(barcodes.map(\.payload).joined(separator: ", "))\n"
        }

        return ImageAnalysis(
            text: text,
            objects: objects,
            faces: faces,
            barcodes: barcodes,
            summary: summary.isEmpty ? "No significant content detected" : summary
        )
    }

    // MARK: - Helpers

    private func createCGImage(from data: Data) -> CGImage? {
        #if canImport(CoreImage)
            guard let ciImage = CIImage(data: data) else { return nil }
            let context = CIContext()
            return context.createCGImage(ciImage, from: ciImage.extent)
        #else
            return nil
        #endif
    }
}

// MARK: - Vision Feature Enum

public enum VisionFeature: String, CaseIterable, Sendable {
    case textRecognition = "text_recognition"
    case objectDetection = "object_detection"
    case faceDetection = "face_detection"
    case barcodeDetection = "barcode_detection"
    case documentDetection = "document_detection"
    case subjectLifting = "subject_lifting"
}

// MARK: - Vision Error

public enum VisionError: Error, LocalizedError {
    case featureNotSupported(VisionFeature)
    case invalidImage
    case processingFailed(String)

    public var errorDescription: String? {
        switch self {
        case let .featureNotSupported(feature):
            "Vision feature not supported: \(feature.rawValue)"
        case .invalidImage:
            "Invalid or corrupt image data"
        case let .processingFailed(reason):
            "Vision processing failed: \(reason)"
        }
    }
}

// MARK: - Result Types

public struct VisionResult: Sendable {
    public let timestamp: Date
    public let analysis: ImageAnalysis
}

public struct TextRecognitionResult: Sendable {
    public let text: String
    public let blocks: [TextBlock]
    public let confidence: Float
}

public struct TextBlock: Sendable {
    public let text: String
    public let boundingBox: CGRect
    public let confidence: Float
}

public struct DetectedObject: Sendable {
    public let labels: [ObjectLabel]
    public let boundingBox: CGRect
    public let confidence: Float
}

public struct ObjectLabel: Sendable {
    public let identifier: String
    public let confidence: Float
}

public struct DetectedFace: Sendable {
    public let boundingBox: CGRect
    public let confidence: Float
    public let roll: Float?
    public let yaw: Float?
}

public struct DetectedBarcode: Sendable {
    public let payload: String
    public let symbology: String
    public let boundingBox: CGRect
    public let confidence: Float
}

public struct DetectedDocument: Sendable {
    public let topLeft: CGPoint
    public let topRight: CGPoint
    public let bottomLeft: CGPoint
    public let bottomRight: CGPoint
    public let confidence: Float
}

public struct ImageAnalysis: Sendable {
    public let text: TextRecognitionResult?
    public let objects: [DetectedObject]
    public let faces: [DetectedFace]
    public let barcodes: [DetectedBarcode]
    public let summary: String
}
