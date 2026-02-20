import Foundation
import CoreGraphics
import CoreImage

#if os(macOS)
import AppKit

// MARK: - Local Vision Guidance
// Orchestrates live screen monitoring + vision analysis + voice guidance
// Uses Qwen2-VL 7B for on-device vision processing (no API calls)
// Uses Soprano-80M for on-device TTS (no API calls)

@MainActor
@Observable
final class LocalVisionGuidance {
    static let shared = LocalVisionGuidance()

    // MARK: - Dependencies

    private let visionEngine = MLXVisionEngine.shared
    private let voiceBackend = MLXVoiceBackend()
    private let screenCapture = ScreenCaptureManager.shared
    private let pointerTracker = PointerTracker.shared
    private let actionExecutor = CGActionExecutor.shared

    // MARK: - State

    private(set) var isGuiding = false
    private(set) var currentTask = ""
    private(set) var currentInstruction = ""
    private(set) var lastAnalysis = ""
    private(set) var lastError: Error?

    private(set) var isLoadingModels = false
    private(set) var modelsReady = false
    private(set) var visionModelLoaded = false
    private(set) var voiceModelLoaded = false

    // Settings
    var guidanceIntervalSeconds: Double = 3.0  // How often to analyze screen
    var allowControlHandoff = false  // Allow Thea to perform actions
    var voiceGuidanceEnabled = true  // Speak instructions aloud
    var captureMode: ScreenCaptureManager.CaptureMode = .fullScreen

    private var guidanceTask: Task<Void, Never>?

    private init() {}

    // MARK: - Permission Accessors (used by LiveGuidanceSettingsView)

    var screenCaptureIsAuthorized: Bool { screenCapture.isAuthorized }
    var pointerTrackerHasPermission: Bool { pointerTracker.hasPermission }
    var actionExecutorHasPermission: Bool { actionExecutor.hasPermission }

    func requestScreenCapturePermission() async throws {
        try await screenCapture.requestAuthorization()
    }

    func requestPointerPermission() {
        pointerTracker.requestPermission()
    }

    func requestActionExecutorPermission() {
        actionExecutor.requestPermission()
    }

    // MARK: - Model Loading

    /// Load Qwen2-VL 7B vision model and Soprano-80M TTS model
    func loadModels() async throws {
        guard !modelsReady else {
            print("[LocalVisionGuidance] Models already loaded")
            return
        }

        isLoadingModels = true
        lastError = nil
        defer { isLoadingModels = false }

        do {
            print("[LocalVisionGuidance] Loading vision and voice models...")

            // Load Qwen2-VL 7B vision model
            let visionModelID = "mlx-community/Qwen2-VL-7B-Instruct-4bit"
            _ = try await visionEngine.loadModel(id: visionModelID)
            visionModelLoaded = true
            print("[LocalVisionGuidance] ✅ Loaded Qwen2-VL vision model")

            // Load Soprano-80M TTS model
            let ttsEngine = MLXAudioEngine.shared
            try await ttsEngine.loadTTSModel()
            voiceModelLoaded = true
            print("[LocalVisionGuidance] ✅ Loaded Soprano-80M TTS model")

            modelsReady = true
            print("[LocalVisionGuidance] All models ready")
        } catch {
            lastError = error
            print("[LocalVisionGuidance] ❌ Failed to load models: \(error)")
            throw error
        }
    }

    func unloadModels() {
        visionEngine.unloadModel()
        let ttsEngine = MLXAudioEngine.shared
        Task { @MainActor in
            ttsEngine.unloadTTSModel()
        }
        visionModelLoaded = false
        voiceModelLoaded = false
        modelsReady = false
        print("[LocalVisionGuidance] Models unloaded")
    }

    // MARK: - Guidance Session

    /// Start live guidance for a specific task
    func startGuidance(task: String) async throws {
        guard !isGuiding else {
            print("[LocalVisionGuidance] Already guiding")
            return
        }

        // Ensure models are loaded
        if !modelsReady {
            try await loadModels()
        }

        // Check permissions
        guard screenCapture.isAuthorized else {
            throw LiveGuidanceError.screenCapturePermissionDenied
        }

        if allowControlHandoff && !actionExecutor.hasPermission {
            throw LiveGuidanceError.accessibilityPermissionDenied
        }

        currentTask = task
        isGuiding = true
        lastError = nil

        // Speak introduction
        let intro = "Starting live guidance for: \(task)"
        currentInstruction = intro
        if voiceGuidanceEnabled {
            try? await voiceBackend.speak(text: intro) // Safe: intro speech is optional UX enhancement; failure doesn't block guidance
        }

        // Start pointer tracking (if control handoff enabled)
        if allowControlHandoff {
            pointerTracker.startTracking()
        }

        // Start guidance loop
        guidanceTask = Task {
            await runGuidanceLoop()
        }

        print("[LocalVisionGuidance] Started guidance for task: \(task)")
    }

    /// Stop live guidance
    func stopGuidance() async {
        guard isGuiding else { return }

        isGuiding = false
        guidanceTask?.cancel()
        guidanceTask = nil

        // Stop pointer tracking
        pointerTracker.stopTracking()

        // Stop any ongoing speech
        await voiceBackend.stopSpeaking()

        let outro = "Guidance stopped"
        if voiceGuidanceEnabled {
            try? await voiceBackend.speak(text: outro) // Safe: outro speech is optional UX enhancement; failure doesn't block shutdown
        }

        print("[LocalVisionGuidance] Stopped guidance")
    }

    // MARK: - Guidance Loop

    private func runGuidanceLoop() async {
        while isGuiding {
            do {
                // Capture screen
                let screenshot = try await captureCurrentView()

                // Get pointer position
                let pointerPos = pointerTracker.getCurrentPosition()

                // Analyze with Qwen2-VL
                let analysis = try await analyzeScreenWithVision(
                    screenshot: screenshot,
                    pointerPosition: pointerPos
                )

                lastAnalysis = analysis

                // Extract next instruction
                let instruction = parseNextInstruction(from: analysis)

                // Only speak if instruction changed
                if instruction != currentInstruction {
                    currentInstruction = instruction

                    if voiceGuidanceEnabled && !instruction.isEmpty {
                        try? await voiceBackend.speak(text: instruction) // Safe: voice guidance is optional; text display remains; non-fatal
                    }
                }

                // Execute action if control handoff enabled and analysis suggests action
                if allowControlHandoff {
                    try? await executeActionIfSuggested(analysis: analysis) // Safe: control action is best-effort; non-execution means user takes manual control
                }

            } catch {
                lastError = error
                print("[LocalVisionGuidance] Error in guidance loop: \(error)")
            }

            // Wait before next iteration
            try? await Task.sleep(for: .seconds(guidanceIntervalSeconds)) // Safe: guidance loop interval; cancellation exits loop when isGuiding becomes false; non-fatal
        }
    }

    // MARK: - Screen Capture

    private func captureCurrentView() async throws -> CGImage {
        switch captureMode {
        case .fullScreen:
            return try await screenCapture.captureScreen()
        case .activeWindow:
            return try await screenCapture.captureActiveWindow()
        case .window(let bundleID):
            return try await screenCapture.captureWindow(bundleID: bundleID)
        case .region(let rect):
            return try await screenCapture.captureRegion(rect)
        }
    }

    // MARK: - Vision Analysis

    private func analyzeScreenWithVision(
        screenshot: CGImage,
        pointerPosition: CGPoint
    ) async throws -> String {
        // Convert CGImage to Data
        let nsImage = NSImage(cgImage: screenshot, size: NSSize(width: screenshot.width, height: screenshot.height))
        guard let tiffData = nsImage.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData),
              let imageData = bitmapImage.representation(using: .png, properties: [:]) else {
            throw LiveGuidanceError.imageConversionFailed
        }

        // Build prompt for Qwen2-VL
        let prompt = buildVisionPrompt(pointerPosition: pointerPosition)

        // Analyze image with streaming response
        let stream = try await visionEngine.analyzeImage(
            imageData: imageData,
            prompt: prompt
        )

        var fullResponse = ""
        for try await chunk in stream {
            fullResponse += chunk
        }

        return fullResponse.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func buildVisionPrompt(pointerPosition: CGPoint) -> String {
        """
        You are a helpful assistant guiding a user through a task.

        Current task: \(currentTask)
        Mouse cursor position: (\(Int(pointerPosition.x)), \(Int(pointerPosition.y)))

        Analyze this screenshot and provide guidance:

        1. What UI elements are visible on screen?
        2. What is the user hovering over or near (based on mouse position)?
        3. What should the user do next to complete the task? Be specific and concise.
        4. If the next action is a click or keyboard input, specify the exact location or key.

        Format your response as:
        OBSERVATION: [What you see]
        NEXT_STEP: [What the user should do next]
        ACTION: [Optional: Click(x,y) or Type("text") or Key(keyname) if actionable]
        """
    }

    // MARK: - Instruction Parsing

    private func parseNextInstruction(from analysis: String) -> String {
        // Extract NEXT_STEP from structured response
        let lines = analysis.components(separatedBy: .newlines)

        for line in lines {
            if line.uppercased().hasPrefix("NEXT_STEP:") {
                let instruction = line.replacingOccurrences(of: "NEXT_STEP:", with: "", options: .caseInsensitive)
                return instruction.trimmingCharacters(in: .whitespaces)
            }
        }

        // Fallback: return first non-empty line
        return lines.first { !$0.isEmpty } ?? ""
    }

    // MARK: - Action Execution

    private func executeActionIfSuggested(analysis: String) async throws {
        let lines = analysis.components(separatedBy: .newlines)

        for line in lines {
            if line.uppercased().hasPrefix("ACTION:") {
                let actionLine = line.replacingOccurrences(of: "ACTION:", with: "", options: .caseInsensitive)
                    .trimmingCharacters(in: .whitespaces)

                try await parseAndExecuteAction(actionLine)
            }
        }
    }

    private func parseAndExecuteAction(_ actionLine: String) async throws {
        // Parse Click(x,y)
        if actionLine.uppercased().hasPrefix("CLICK") {
            if let match = actionLine.range(of: #"CLICK\((\d+),\s*(\d+)\)"#, options: .regularExpression) {
                let coords = actionLine[match].replacingOccurrences(of: "CLICK(", with: "").replacingOccurrences(of: ")", with: "")
                let parts = coords.components(separatedBy: ",")
                if parts.count == 2,
                   let x = Double(parts[0].trimmingCharacters(in: .whitespaces)),
                   let y = Double(parts[1].trimmingCharacters(in: .whitespaces)) {
                    try await actionExecutor.click(at: CGPoint(x: x, y: y))
                    print("[LocalVisionGuidance] Executed click at (\(x), \(y))")
                }
            }
        }

        // Parse Type("text")
        if actionLine.uppercased().hasPrefix("TYPE") {
            if let match = actionLine.range(of: #"TYPE\("([^"]+)"\)"#, options: .regularExpression) {
                let textPart = actionLine[match]
                    .replacingOccurrences(of: #"TYPE\("#, with: "", options: .regularExpression)
                    .replacingOccurrences(of: #"\)"#, with: "", options: .regularExpression)
                try await actionExecutor.type(textPart)
                print("[LocalVisionGuidance] Executed type: '\(textPart)'")
            }
        }

        // Parse Key(keyname)
        if actionLine.uppercased().hasPrefix("KEY") {
            if let match = actionLine.range(of: #"KEY\((\w+)\)"#, options: .regularExpression) {
                let keyName = actionLine[match]
                    .replacingOccurrences(of: "KEY(", with: "")
                    .replacingOccurrences(of: ")", with: "")
                    .lowercased()

                // Map key names to KeyCode
                let keyCode: CGActionExecutor.KeyCode? = {
                    switch keyName {
                    case "return", "enter": return .returnKey
                    case "tab": return .tab
                    case "space": return .space
                    case "escape", "esc": return .escape
                    case "delete", "backspace": return .delete
                    default: return nil
                    }
                }()

                if let code = keyCode {
                    try await actionExecutor.pressKey(code)
                    print("[LocalVisionGuidance] Executed key press: \(keyName)")
                }
            }
        }
    }
}

// MARK: - Errors

enum LiveGuidanceError: Error, LocalizedError {
    case screenCapturePermissionDenied
    case accessibilityPermissionDenied
    case modelsNotLoaded
    case imageConversionFailed
    case visionAnalysisFailed(String)
    case voiceSynthesisFailed(String)

    var errorDescription: String? {
        switch self {
        case .screenCapturePermissionDenied:
            "Screen Recording permission required. Grant in System Settings → Privacy & Security → Screen Recording."
        case .accessibilityPermissionDenied:
            "Accessibility permission required for control handoff. Grant in System Settings → Privacy & Security → Accessibility."
        case .modelsNotLoaded:
            "Vision and voice models not loaded. Load models first."
        case .imageConversionFailed:
            "Failed to convert screenshot to image data for analysis"
        case .visionAnalysisFailed(let reason):
            "Vision analysis failed: \(reason)"
        case .voiceSynthesisFailed(let reason):
            "Voice synthesis failed: \(reason)"
        }
    }
}

#endif
