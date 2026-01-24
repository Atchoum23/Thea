// MultiModalCoordinator.swift
// Coordinates multi-modal AI inputs (text, voice, vision, documents)

import Foundation
import OSLog
import Combine

// MARK: - Multi-Modal Coordinator

/// Coordinates multiple AI input modalities for seamless interaction
@MainActor
public final class MultiModalCoordinator: ObservableObject {
    public static let shared = MultiModalCoordinator()

    private let logger = Logger(subsystem: "com.thea.app", category: "MultiModal")
    private var cancellables = Set<AnyCancellable>()

    // Services
    private let vision = VisionIntelligence.shared
    private let speech = SpeechIntelligence.shared
    private let documents = DocumentIntelligence.shared

    // MARK: - Published State

    @Published public private(set) var activeModalities: Set<Modality> = []
    @Published public private(set) var currentContext: MultiModalContext?
    @Published public private(set) var isProcessing = false
    @Published public private(set) var lastError: String?

    // MARK: - Context Building

    private var contextBuilder = ContextBuilder()

    // MARK: - Initialization

    private init() {
        setupObservers()
    }

    private func setupObservers() {
        // Listen for speech recognition results
        speech.$recognizedText
            .sink { [weak self] text in
                if let text = text, !text.isEmpty {
                    self?.contextBuilder.addVoiceInput(text)
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Modality Control

    /// Enable a modality
    public func enableModality(_ modality: Modality) async throws {
        switch modality {
        case .text:
            // Text is always available
            break

        case .voice:
            try await speech.startRecognition()

        case .vision:
            // Vision processing is on-demand
            break

        case .document:
            // Document processing is on-demand
            break

        case .screen:
            // Screen capture requires setup
            break
        }

        activeModalities.insert(modality)
        logger.info("Enabled modality: \(modality.rawValue)")
    }

    /// Disable a modality
    public func disableModality(_ modality: Modality) async {
        switch modality {
        case .voice:
            await speech.stopRecognition()
        default:
            break
        }

        activeModalities.remove(modality)
        logger.info("Disabled modality: \(modality.rawValue)")
    }

    // MARK: - Multi-Modal Input

    /// Process multi-modal input and generate unified context
    public func processInput(_ input: MultiModalInput) async throws -> ProcessedInput {
        isProcessing = true
        lastError = nil

        defer { isProcessing = false }

        var processedComponents: [ProcessedComponent] = []

        // Process text
        if let text = input.text {
            processedComponents.append(ProcessedComponent(
                type: .text,
                content: text,
                confidence: 1.0,
                metadata: [:]
            ))
        }

        // Process images
        for imageData in input.images {
            do {
                let analysis = try await vision.analyzeForAI(imageData: imageData)
                processedComponents.append(ProcessedComponent(
                    type: .image,
                    content: analysis.description,
                    confidence: analysis.confidence,
                    metadata: [
                        "text": analysis.extractedText ?? "",
                        "objectCount": String(analysis.objectCount)
                    ]
                ))
            } catch {
                logger.error("Image processing failed: \(error.localizedDescription)")
            }
        }

        // Process documents
        for (docData, docType) in input.documents {
            do {
                let analysis = try await documents.analyze(documentData: docData, type: docType)
                processedComponents.append(ProcessedComponent(
                    type: .document,
                    content: analysis.summary,
                    confidence: 1.0,
                    metadata: [
                        "title": analysis.title ?? "",
                        "wordCount": String(analysis.wordCount),
                        "keyTopics": analysis.keyTopics.joined(separator: ", ")
                    ]
                ))
            } catch {
                logger.error("Document processing failed: \(error.localizedDescription)")
            }
        }

        // Process voice
        if let voiceData = input.voiceData {
            do {
                let transcription = try await speech.transcribe(audioData: voiceData)
                processedComponents.append(ProcessedComponent(
                    type: .voice,
                    content: transcription.text,
                    confidence: transcription.confidence,
                    metadata: [
                        "duration": String(format: "%.1f", transcription.duration),
                        "language": transcription.language ?? "unknown"
                    ]
                ))
            } catch {
                logger.error("Voice processing failed: \(error.localizedDescription)")
            }
        }

        // Build unified context
        let unifiedPrompt = buildUnifiedPrompt(from: processedComponents)
        let context = buildContext(from: processedComponents)

        return ProcessedInput(
            components: processedComponents,
            unifiedPrompt: unifiedPrompt,
            context: context,
            timestamp: Date()
        )
    }

    // MARK: - Context Building

    private func buildUnifiedPrompt(from components: [ProcessedComponent]) -> String {
        var prompt = ""

        // Add text components first
        let textComponents = components.filter { $0.type == .text }
        if !textComponents.isEmpty {
            prompt += textComponents.map { $0.content }.joined(separator: "\n")
        }

        // Add voice transcription
        let voiceComponents = components.filter { $0.type == .voice }
        if !voiceComponents.isEmpty {
            if !prompt.isEmpty { prompt += "\n\n" }
            prompt += "[Voice input]: " + voiceComponents.map { $0.content }.joined(separator: " ")
        }

        // Add image descriptions
        let imageComponents = components.filter { $0.type == .image }
        if !imageComponents.isEmpty {
            if !prompt.isEmpty { prompt += "\n\n" }
            prompt += "[Attached images]:\n"
            for (index, component) in imageComponents.enumerated() {
                prompt += "- Image \(index + 1): \(component.content)\n"
                if let text = component.metadata["text"], !text.isEmpty {
                    prompt += "  Text found: \(text)\n"
                }
            }
        }

        // Add document summaries
        let docComponents = components.filter { $0.type == .document }
        if !docComponents.isEmpty {
            if !prompt.isEmpty { prompt += "\n\n" }
            prompt += "[Attached documents]:\n"
            for component in docComponents {
                let title = component.metadata["title"] ?? "Document"
                prompt += "- \(title): \(component.content)\n"
            }
        }

        return prompt
    }

    private func buildContext(from components: [ProcessedComponent]) -> MultiModalContext {
        MultiModalContext(
            hasText: components.contains { $0.type == .text },
            hasImages: components.contains { $0.type == .image },
            hasDocuments: components.contains { $0.type == .document },
            hasVoice: components.contains { $0.type == .voice },
            componentCount: components.count,
            averageConfidence: components.map { $0.confidence }.reduce(0, +) / Double(max(components.count, 1)),
            timestamp: Date()
        )
    }

    // MARK: - Convenience Methods

    /// Quick text + image analysis
    public func analyzeWithImage(text: String, imageData: Data) async throws -> ProcessedInput {
        let input = MultiModalInput(
            text: text,
            images: [imageData],
            documents: [],
            voiceData: nil,
            screenCapture: nil
        )
        return try await processInput(input)
    }

    /// Quick text + document analysis
    public func analyzeWithDocument(text: String, documentData: Data, type: DocumentType) async throws -> ProcessedInput {
        let input = MultiModalInput(
            text: text,
            images: [],
            documents: [(documentData, type)],
            voiceData: nil,
            screenCapture: nil
        )
        return try await processInput(input)
    }

    /// Analyze screen capture with optional question
    public func analyzeScreen(question: String? = nil) async throws -> ProcessedInput {
        // Capture screen
        #if os(macOS)
        // Screen capture implementation for macOS
        let screenData = Data() // Placeholder
        #elseif os(iOS)
        // Screen capture implementation for iOS
        let screenData = Data() // Placeholder
        #else
        let screenData = Data()
        #endif

        let input = MultiModalInput(
            text: question,
            images: [screenData],
            documents: [],
            voiceData: nil,
            screenCapture: screenData
        )
        return try await processInput(input)
    }

    // MARK: - Continuous Mode

    /// Start continuous multi-modal capture
    public func startContinuousCapture(modalities: Set<Modality>) async throws {
        for modality in modalities {
            try await enableModality(modality)
        }

        logger.info("Started continuous capture with modalities: \(modalities.map { $0.rawValue })")
    }

    /// Stop continuous capture
    public func stopContinuousCapture() async {
        for modality in activeModalities {
            await disableModality(modality)
        }

        logger.info("Stopped continuous capture")
    }
}

// MARK: - Context Builder

private class ContextBuilder {
    private var textInputs: [String] = []
    private var voiceInputs: [String] = []
    private var imageDescriptions: [String] = []
    private var documentSummaries: [String] = []

    func addTextInput(_ text: String) {
        textInputs.append(text)
    }

    func addVoiceInput(_ text: String) {
        voiceInputs.append(text)
    }

    func addImageDescription(_ description: String) {
        imageDescriptions.append(description)
    }

    func addDocumentSummary(_ summary: String) {
        documentSummaries.append(summary)
    }

    func build() -> String {
        var context = ""

        if !textInputs.isEmpty {
            context += textInputs.joined(separator: "\n")
        }

        if !voiceInputs.isEmpty {
            context += "\n[Voice]: " + voiceInputs.joined(separator: " ")
        }

        if !imageDescriptions.isEmpty {
            context += "\n[Images]: " + imageDescriptions.joined(separator: "; ")
        }

        if !documentSummaries.isEmpty {
            context += "\n[Documents]: " + documentSummaries.joined(separator: "; ")
        }

        return context
    }

    func clear() {
        textInputs.removeAll()
        voiceInputs.removeAll()
        imageDescriptions.removeAll()
        documentSummaries.removeAll()
    }
}

// MARK: - Types

public enum Modality: String, CaseIterable {
    case text
    case voice
    case vision
    case document
    case screen
}

public struct MultiModalInput {
    public let text: String?
    public let images: [Data]
    public let documents: [(Data, DocumentType)]
    public let voiceData: Data?
    public let screenCapture: Data?

    public init(
        text: String? = nil,
        images: [Data] = [],
        documents: [(Data, DocumentType)] = [],
        voiceData: Data? = nil,
        screenCapture: Data? = nil
    ) {
        self.text = text
        self.images = images
        self.documents = documents
        self.voiceData = voiceData
        self.screenCapture = screenCapture
    }
}

public struct ProcessedInput {
    public let components: [ProcessedComponent]
    public let unifiedPrompt: String
    public let context: MultiModalContext
    public let timestamp: Date
}

public struct ProcessedComponent {
    public let type: ComponentType
    public let content: String
    public let confidence: Double
    public let metadata: [String: String]

    public enum ComponentType {
        case text
        case voice
        case image
        case document
        case screen
    }
}

public struct MultiModalContext {
    public let hasText: Bool
    public let hasImages: Bool
    public let hasDocuments: Bool
    public let hasVoice: Bool
    public let componentCount: Int
    public let averageConfidence: Double
    public let timestamp: Date
}

// MARK: - Context Awareness Service

/// Provides environmental and contextual awareness for AI interactions
@MainActor
public final class ContextAwarenessService: ObservableObject {
    public static let shared = ContextAwarenessService()

    private let logger = Logger(subsystem: "com.thea.app", category: "ContextAwareness")

    // MARK: - Published State

    @Published public private(set) var currentContext: EnvironmentalContext?
    @Published public private(set) var userActivity: UserActivityState = .idle
    @Published public private(set) var timeContext: TimeContext?
    @Published public private(set) var locationContext: LocationContext?

    // MARK: - Initialization

    private init() {
        updateContext()
        startContextUpdates()
    }

    // MARK: - Context Updates

    private func startContextUpdates() {
        // Update context periodically
        Task {
            while true {
                updateContext()
                try? await Task.sleep(nanoseconds: 60_000_000_000) // Every minute
            }
        }
    }

    private func updateContext() {
        updateTimeContext()
        updateEnvironmentalContext()
    }

    private func updateTimeContext() {
        let now = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        let weekday = calendar.component(.weekday, from: now)

        let timeOfDay: TimeOfDay
        switch hour {
        case 5..<12: timeOfDay = .morning
        case 12..<17: timeOfDay = .afternoon
        case 17..<21: timeOfDay = .evening
        default: timeOfDay = .night
        }

        let isWeekend = weekday == 1 || weekday == 7

        timeContext = TimeContext(
            date: now,
            timeOfDay: timeOfDay,
            hour: hour,
            isWeekend: isWeekend,
            isWorkHours: !isWeekend && (9..<18).contains(hour)
        )
    }

    private func updateEnvironmentalContext() {
        #if os(iOS)
        // Check device orientation, battery, etc.
        let batteryLevel = UIDevice.current.batteryLevel
        let isLowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        #else
        let batteryLevel: Float = 1.0
        let isLowPower = false
        #endif

        currentContext = EnvironmentalContext(
            batteryLevel: batteryLevel,
            isLowPowerMode: isLowPower,
            networkStatus: .wifi, // Would need to check actual status
            timestamp: Date()
        )
    }

    // MARK: - User Activity Tracking

    /// Update user activity state
    public func updateUserActivity(_ activity: UserActivityState) {
        userActivity = activity
        logger.debug("User activity: \(activity.rawValue)")
    }

    // MARK: - Context for AI

    /// Get context string for AI prompts
    public func getContextForAI() -> String {
        var contextParts: [String] = []

        // Time context
        if let time = timeContext {
            var timeStr = "Current time: \(time.timeOfDay.rawValue)"
            if time.isWeekend {
                timeStr += " (weekend)"
            } else if time.isWorkHours {
                timeStr += " (work hours)"
            }
            contextParts.append(timeStr)
        }

        // User activity
        switch userActivity {
        case .working:
            contextParts.append("User appears to be working")
        case .browsing:
            contextParts.append("User is browsing/reading")
        case .coding:
            contextParts.append("User is coding")
        case .idle:
            break
        }

        // Environmental context
        if let env = currentContext {
            if env.isLowPowerMode {
                contextParts.append("Device in low power mode")
            }
            if env.batteryLevel < 0.2 {
                contextParts.append("Battery low")
            }
        }

        return contextParts.isEmpty ? "" : "[Context: \(contextParts.joined(separator: ", "))]"
    }

    // MARK: - Proactive Suggestions

    /// Get proactive suggestions based on context
    public func getProactiveSuggestions() -> [ProactiveSuggestion] {
        var suggestions: [ProactiveSuggestion] = []

        // Time-based suggestions
        if let time = timeContext {
            if time.timeOfDay == .morning && !time.isWeekend {
                suggestions.append(ProactiveSuggestion(
                    id: "morning-briefing",
                    title: "Morning Briefing",
                    description: "Get a summary of your day ahead",
                    action: .aiPrompt("Give me a brief summary to start my day. What should I focus on?")
                ))
            }

            if time.timeOfDay == .evening {
                suggestions.append(ProactiveSuggestion(
                    id: "day-review",
                    title: "Day Review",
                    description: "Review what you accomplished today",
                    action: .aiPrompt("Help me review what I accomplished today and plan for tomorrow")
                ))
            }
        }

        // Activity-based suggestions
        switch userActivity {
        case .coding:
            suggestions.append(ProactiveSuggestion(
                id: "code-review",
                title: "Code Review",
                description: "Get AI feedback on your code",
                action: .navigate("code-review")
            ))

        case .working:
            suggestions.append(ProactiveSuggestion(
                id: "focus-timer",
                title: "Focus Session",
                description: "Start a 25-minute focus session",
                action: .navigate("focus-timer")
            ))

        default:
            break
        }

        return suggestions
    }
}

// MARK: - Context Types

public struct EnvironmentalContext {
    public let batteryLevel: Float
    public let isLowPowerMode: Bool
    public let networkStatus: NetworkStatus
    public let timestamp: Date

    public enum NetworkStatus {
        case wifi
        case cellular
        case offline
    }
}

public struct TimeContext {
    public let date: Date
    public let timeOfDay: TimeOfDay
    public let hour: Int
    public let isWeekend: Bool
    public let isWorkHours: Bool
}

public enum TimeOfDay: String {
    case morning
    case afternoon
    case evening
    case night
}

public struct LocationContext {
    public let isHome: Bool
    public let isWork: Bool
    public let city: String?
    public let country: String?
}

public enum UserActivityState: String {
    case idle
    case working
    case browsing
    case coding
}

public struct ProactiveSuggestion: Identifiable {
    public let id: String
    public let title: String
    public let description: String
    public let action: SuggestionAction

    public enum SuggestionAction {
        case aiPrompt(String)
        case navigate(String)
        case shortcut(String)
    }
}
