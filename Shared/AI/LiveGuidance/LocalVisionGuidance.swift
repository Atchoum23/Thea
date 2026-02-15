import Foundation
import CoreGraphics
import AppKit
import SwiftUI

#if os(macOS)

// MARK: - Local Vision Guidance
// Integrates Qwen2-VL 7B vision model with screen capture and voice guidance
// Provides real-time interactive voice guidance for user actions

@MainActor
@Observable
final class LocalVisionGuidance {
    static let shared = LocalVisionGuidance()

    // MARK: - Dependencies

    let visionEngine = MLXVisionEngine.shared
    let voiceBackend = MLXVoiceBackend()
    let screenCapture = ScreenCaptureManager()
    let pointerTracker = PointerTracker()
    let actionExecutor = SystemActionExecutor()

    // MARK: - State

    private(set) var currentInstruction: String = ""
    private(set) var isGuiding: Bool = false
    private(set) var currentTask: String = ""
    private(set) var isVisionModelLoaded: Bool = false
    private(set) var lastAnalysis: VisionAnalysis?
    private(set) var lastError: Error?

    // Settings
    var captureMode: CaptureMode = .fullScreen
    var enableVoice: Bool = true
    var allowControlHandoff: Bool = false
    var analyzeInterval: TimeInterval = 2.0 // seconds

    private var guidanceTask: Task<Void, Never>?

    private init() {}

    // MARK: - Capture Mode

    enum CaptureMode {
        case fullScreen
        case activeWindow
        case region(CGRect)
    }

    // MARK: - Vision Analysis Result

    struct VisionAnalysis {
        let timestamp: Date
        let screenDescription: String
        let pointerContext: String
        let suggestedAction: String
        let confidence: Double
    }

    // MARK: - Model Management

    func loadVisionModel() async throws {
        guard !isVisionModelLoaded else { return }

        // Load Qwen2-VL 7B
        let modelID = "mlx-community/Qwen2-VL-7B-Instruct-4bit"

        do {
            _ = try await visionEngine.loadModel(id: modelID)
            isVisionModelLoaded = true
            print("✅ LocalVisionGuidance: Qwen2-VL loaded successfully")
        } catch {
            lastError = error
            print("❌ LocalVisionGuidance: Failed to load Qwen2-VL - \(error)")
            throw error
        }
    }

    func unloadVisionModel() {
        visionEngine.unloadModel()
        isVisionModelLoaded = false
    }

    // MARK: - Guidance Control

    func startGuidance(task: String) async throws {
        guard !isGuiding else { return }

        // Ensure vision model is loaded
        if !isVisionModelLoaded {
            try await loadVisionModel()
        }

        // Check authorizations
        if !screenCapture.isAuthorized {
            try await screenCapture.requestAuthorization()
        }

        if !pointerTracker.isAuthorized {
            pointerTracker.requestAuthorization()
        }

        currentTask = task
        isGuiding = true
        lastError = nil

        // Start pointer tracking
        pointerTracker.startTracking()

        // Speak initial message
        if enableVoice {
            try? await voiceBackend.speak(text: "Starting live guidance for: \(task)")
        }

        // Start guidance loop
        guidanceTask = Task { @MainActor in
            await guidanceLoop()
        }

        print("✅ LocalVisionGuidance: Started guidance for task - \(task)")
    }

    func stopGuidance() async {
        guard isGuiding else { return }

        isGuiding = false
        guidanceTask?.cancel()
        guidanceTask = nil

        pointerTracker.stopTracking()

        if enableVoice {
            try? await voiceBackend.speak(text: "Guidance stopped")
        }

        print("🛑 LocalVisionGuidance: Stopped guidance")
    }

    // MARK: - Guidance Loop

    private func guidanceLoop() async {
        while isGuiding {
            do {
                // Capture screen based on mode
                let screenshot = try await captureScreenshot()

                // Get current pointer position
                let pointerPos = pointerTracker.currentPosition

                // Analyze with Qwen2-VL
                let analysis = try await analyzeScreen(screenshot: screenshot, pointerPosition: pointerPos)

                // Update state
                lastAnalysis = analysis

                // Check if instruction changed
                if analysis.suggestedAction != currentInstruction {
                    currentInstruction = analysis.suggestedAction

                    // Speak the instruction
                    if enableVoice && !analysis.suggestedAction.isEmpty {
                        try? await voiceBackend.speak(text: analysis.suggestedAction)
                    }

                    print("📋 LocalVisionGuidance: New instruction - \(analysis.suggestedAction)")
                }

                // Wait before next analysis
                try? await Task.sleep(for: .seconds(analyzeInterval))

            } catch {
                lastError = error
                print("❌ LocalVisionGuidance: Analysis failed - \(error)")

                // Continue despite errors
                try? await Task.sleep(for: .seconds(analyzeInterval))
            }
        }
    }

    // MARK: - Screen Capture

    private func captureScreenshot() async throws -> CGImage {
        switch captureMode {
        case .fullScreen:
            return try await screenCapture.captureScreen()
        case .activeWindow:
            return try await screenCapture.captureActiveWindow()
        case .region(let rect):
            return try await screenCapture.captureRegion(rect)
        }
    }

    // MARK: - Vision Analysis

    private func analyzeScreen(screenshot: CGImage, pointerPosition: CGPoint) async throws -> VisionAnalysis {
        // Convert CGImage to Data
        guard let data = screenshot.pngData() else {
            throw LiveGuidanceError.imageConversionFailed
        }

        // Build prompt for vision model
        let prompt = buildAnalysisPrompt(pointerPosition: pointerPosition)

        // Analyze with Qwen2-VL
        let stream = try await visionEngine.analyzeImage(
            imageData: data,
            prompt: prompt
        )

        // Collect streamed response
        var fullResponse = ""
        for try await chunk in stream {
            fullResponse += chunk
        }

        // Parse response into structured analysis
        return parseAnalysis(response: fullResponse, pointerPosition: pointerPosition)
    }

    private func buildAnalysisPrompt(pointerPosition: CGPoint) -> String {
        """
        You are a helpful AI assistant providing step-by-step guidance for the following task:
        **Task:** \(currentTask)

        Current mouse position: (\(Int(pointerPosition.x)), \(Int(pointerPosition.y)))

        Analyze the screenshot and provide:
        1. Brief description of what's visible on screen (1-2 sentences)
        2. What UI element the user is hovering over (if any)
        3. The NEXT SPECIFIC ACTION the user should take to complete the task

        Be concise and actionable. Focus on the immediate next step.

        Format your response as:
        SCREEN: <description>
        POINTER: <context about hovered element>
        ACTION: <next step instruction>
        """
    }

    private func parseAnalysis(response: String, pointerPosition: CGPoint) -> VisionAnalysis {
        var screenDesc = ""
        var pointerContext = ""
        var suggestedAction = ""

        // Parse structured response
        let lines = response.components(separatedBy: "\n")
        for line in lines {
            if line.hasPrefix("SCREEN:") {
                screenDesc = line.replacingOccurrences(of: "SCREEN:", with: "").trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("POINTER:") {
                pointerContext = line.replacingOccurrences(of: "POINTER:", with: "").trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("ACTION:") {
                suggestedAction = line.replacingOccurrences(of: "ACTION:", with: "").trimmingCharacters(in: .whitespaces)
            }
        }

        // Fallback: use entire response as suggested action if parsing failed
        if suggestedAction.isEmpty {
            suggestedAction = response.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return VisionAnalysis(
            timestamp: Date(),
            screenDescription: screenDesc,
            pointerContext: pointerContext,
            suggestedAction: suggestedAction,
            confidence: 0.8 // TODO: Extract confidence from model if available
        )
    }

    // MARK: - Control Handoff

    func executeAction(_ action: GuidanceAction) async throws {
        guard allowControlHandoff else {
            throw LiveGuidanceError.controlHandoffDisabled
        }

        switch action {
        case .click(let point):
            try actionExecutor.click(at: point)

        case .doubleClick(let point):
            try actionExecutor.doubleClick(at: point)

        case .type(let text):
            try actionExecutor.type(text)

        case .moveTo(let point):
            try actionExecutor.movePointer(to: point, animated: true)

        case .pressKey(let keyCode):
            try actionExecutor.pressKey(keyCode)
        }

        print("✅ LocalVisionGuidance: Executed action - \(action)")
    }
}

// MARK: - Guidance Action

enum GuidanceAction {
    case click(CGPoint)
    case doubleClick(CGPoint)
    case type(String)
    case moveTo(CGPoint)
    case pressKey(CGKeyCode)
}

// MARK: - Live Guidance Errors

enum LiveGuidanceError: Error, LocalizedError {
    case visionModelNotLoaded
    case screenCaptureNotAuthorized
    case imageConversionFailed
    case analysisTimeout
    case controlHandoffDisabled

    var errorDescription: String? {
        switch self {
        case .visionModelNotLoaded:
            return "Vision model is not loaded. Load Qwen2-VL first."
        case .screenCaptureNotAuthorized:
            return "Screen recording permission not granted."
        case .imageConversionFailed:
            return "Failed to convert screenshot to image data."
        case .analysisTimeout:
            return "Vision analysis timed out."
        case .controlHandoffDisabled:
            return "Control handoff is disabled in settings."
        }
    }
}

#endif

// MARK: - CGImage PNG Extension

extension CGImage {
    func pngData() -> Data? {
        guard let mutableData = CFDataCreateMutable(nil, 0),
              let destination = CGImageDestinationCreateWithData(mutableData, "public.png" as CFString, 1, nil) else {
            return nil
        }

        CGImageDestinationAddImage(destination, self, nil)
        guard CGImageDestinationFinalize(destination) else {
            return nil
        }

        return mutableData as Data
    }
}
