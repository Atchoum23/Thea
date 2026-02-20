// SoundAnalysisService.swift
// Thea — AAD3-2: Ambient Audio Intelligence
//
// SNClassifySoundRequest(classifierIdentifier: .version1) + SNResultsObserving
// for real-time ambient sound classification (300+ categories).
// Wire in: AmbientIntelligenceEngine.startAudioAnalysis() → SoundAnalysisService.shared.startAnalysis()
// Platform: iOS 15+ / macOS 12+ (#if canImport(SoundAnalysis) guard)

import Foundation
import os.log

private let logger = Logger(subsystem: "app.thea", category: "SoundAnalysisService")

// MARK: - Sound Classification Result

struct SoundClassification: Sendable {
    let identifier: String      // e.g. "music", "speech", "dog_barking"
    let confidence: Double      // 0.0 – 1.0
    // periphery:ignore - Reserved: Wave 10 service — wired in future integration phase
    let classifiedAt: Date
}

// MARK: - SoundAnalysisService

#if canImport(SoundAnalysis)
import SoundAnalysis
import AVFoundation

/// Real-time ambient sound classification using Apple's SoundAnalysis framework.
/// Uses SNClassifySoundRequest with the built-in version1 classifier (300+ sound categories).
/// Requires microphone permission (NSMicrophoneUsageDescription in Info.plist).
@MainActor
final class SoundAnalysisService: NSObject, ObservableObject {

    // periphery:ignore - Reserved: Wave 10 service — wired in future integration phase
    static let shared = SoundAnalysisService()

    // MARK: - Published State

    // periphery:ignore - Reserved: Wave 10 service — wired in future integration phase
    @Published var isAnalyzing: Bool = false
    @Published var topClassification: SoundClassification?
    @Published var recentClassifications: [SoundClassification] = []
    // periphery:ignore - Reserved: Wave 10 service — wired in future integration phase
    @Published var errorMessage: String?

    // MARK: - Private

    // periphery:ignore - Reserved: Wave 10 service — wired in future integration phase
    private var audioEngine: AVAudioEngine?
    // periphery:ignore - Reserved: Wave 10 service — wired in future integration phase
    private var analyzer: SNAudioStreamAnalyzer?
    // periphery:ignore - Reserved: Wave 10 service — wired in future integration phase
    private var analysisRequest: SNClassifySoundRequest?
    // periphery:ignore - Reserved: Wave 10 service — wired in future integration phase
    private var analysisObserver: SoundAnalysisObserver?
    private let maxRecentCount = 20

    override private init() {
        super.init()
        logger.info("SoundAnalysisService initialized")
    }

    // MARK: - Start/Stop

    // periphery:ignore - Reserved: Wave 10 service — wired in future integration phase
    /// Begin real-time sound classification from the device microphone.
    func startAnalysis() {
        guard !isAnalyzing else { return }

        do {
            let request = try SNClassifySoundRequest(classifierIdentifier: .version1)
            request.windowDuration = CMTimeMakeWithSeconds(1.5, preferredTimescale: 44100)

            let engine = AVAudioEngine()
            let inputNode = engine.inputNode
            let format = inputNode.outputFormat(forBus: 0)

            let streamAnalyzer = SNAudioStreamAnalyzer(format: format)
            let observer = SoundAnalysisObserver(service: self)
            try streamAnalyzer.add(request, withObserver: observer)

            inputNode.installTap(onBus: 0, bufferSize: 8192, format: format) { [weak streamAnalyzer] buffer, time in
                streamAnalyzer?.analyze(buffer, atAudioFramePosition: time.sampleTime)
            }

            try engine.start()

            self.audioEngine     = engine
            self.analyzer        = streamAnalyzer
            self.analysisRequest = request
            self.analysisObserver = observer
            self.isAnalyzing     = true
            self.errorMessage    = nil

            logger.info("SoundAnalysisService: started microphone tap for classification")
        } catch {
            errorMessage = error.localizedDescription
            logger.error("SoundAnalysisService: start failed: \(error.localizedDescription)")
        }
    }

    // periphery:ignore - Reserved: Wave 10 service — wired in future integration phase
    /// Stop classification and release audio resources.
    func stopAnalysis() {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine    = nil
        analyzer       = nil
        analysisRequest = nil
        analysisObserver = nil
        isAnalyzing    = false
        logger.info("SoundAnalysisService: stopped")
    }

    // MARK: - Result Ingestion (called from observer)

    func handleClassification(identifier: String, confidence: Double) {
        let classification = SoundClassification(
            identifier: identifier,
            confidence: confidence,
            classifiedAt: Date()
        )

        topClassification = classification
        recentClassifications.insert(classification, at: 0)
        if recentClassifications.count > maxRecentCount {
            recentClassifications.removeLast()
        }

        logger.debug("SoundAnalysisService: '\(identifier)' confidence=\(String(format: "%.2f", confidence))")
    }

    // MARK: - Context Summary

    // periphery:ignore - Reserved: Wave 10 service — wired in future integration phase
    /// Returns a brief summary for AI context injection.
    func contextSummary() -> String? {
        guard let top = topClassification, top.confidence > 0.5 else { return nil }
        let humanReadable = top.identifier.replacingOccurrences(of: "_", with: " ")
        return "Ambient sound: \(humanReadable) (confidence: \(Int(top.confidence * 100))%)."
    }
}

// MARK: - SNResultsObserving

// periphery:ignore - Reserved: Wave 10 service — wired in future integration phase
private final class SoundAnalysisObserver: NSObject, SNResultsObserving, @unchecked Sendable {

    private weak var service: SoundAnalysisService?

    init(service: SoundAnalysisService) {
        self.service = service
    }

    func request(_ request: SNRequest, didProduce result: SNResult) {
        guard let classificationResult = result as? SNClassificationResult,
              let bestClassification = classificationResult.classifications.first else {
            return
        }

        let identifier  = bestClassification.identifier
        let confidence  = bestClassification.confidence

        Task { @MainActor [weak service] in
            service?.handleClassification(identifier: identifier, confidence: confidence)
        }
    }

    func request(_ request: SNRequest, didFailWithError error: Error) {
        logger.error("SoundAnalysisService observer error: \(error.localizedDescription)")
        Task { @MainActor [weak service] in
            service?.errorMessage = error.localizedDescription
        }
    }
}

#else

// MARK: - Fallback Stub (SoundAnalysis not available)

@MainActor
final class SoundAnalysisService: ObservableObject {
    static let shared = SoundAnalysisService()

    @Published var isAnalyzing: Bool = false
    @Published var topClassification: SoundClassification?
    @Published var recentClassifications: [SoundClassification] = []
    @Published var errorMessage: String?

    private init() {
        logger.info("SoundAnalysisService stub: SoundAnalysis not available on this platform")
    }

    func startAnalysis() {
        logger.info("SoundAnalysisService stub: startAnalysis() — SoundAnalysis unavailable")
    }

    func stopAnalysis() {}

    func contextSummary() -> String? { nil }
}

#endif
