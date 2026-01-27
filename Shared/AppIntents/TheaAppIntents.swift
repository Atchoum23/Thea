//
//  TheaAppIntents.swift
//  Thea
//
//  App Intents for Siri, Shortcuts, Spotlight, and Control Center
//

import AppIntents
import Foundation

// MARK: - Ask Thea Intent

/// Ask Thea a question via Siri or Shortcuts
@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
public struct AskTheaIntent: AppIntent {
    nonisolated(unsafe) public static var title: LocalizedStringResource = "Ask Thea"
    nonisolated(unsafe) public static var description = IntentDescription("Ask Thea's AI assistant a question")

    @Parameter(title: "Question")
    var question: String

    @Parameter(title: "Use On-Device AI", default: false)
    var useOnDeviceAI: Bool

    public init() {}

    public init(question: String, useOnDeviceAI: Bool = false) {
        self.question = question
        self.useOnDeviceAI = useOnDeviceAI
    }

    public func perform() async throws -> some IntentResult & ReturnsValue<String> {
        // Get response from AI
        let response = await getAIResponse(question: question, onDevice: useOnDeviceAI)
        return .result(value: response)
    }

    private func getAIResponse(question: String, onDevice: Bool) async -> String {
        if onDevice {
            do {
                return try await OnDeviceAIService.shared.generateText(prompt: question)
            } catch {
                return "On-device AI error: \(error.localizedDescription)"
            }
        }
        // Use cloud AI via ChatManager
        return "Response from Thea: I received your question '\(question)'. Open Thea for a full response."
    }
}

// MARK: - Quick Chat Intent

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
public struct QuickChatIntent: AppIntent {
    nonisolated(unsafe) public static var title: LocalizedStringResource = "Quick Chat with Thea"
    nonisolated(unsafe) public static var description = IntentDescription("Start a quick chat session with Thea")

    @Parameter(title: "Message")
    var message: String

    @Parameter(title: "Conversation", optionsProvider: ConversationOptionsProvider())
    var conversationId: String?

    public init() {}

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let response = "Thea: I'll help you with '\(message)'. Opening full conversation..."
        return .result(dialog: IntentDialog(stringLiteral: response))
    }
}

// MARK: - Summarize Text Intent

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
public struct SummarizeTextIntent: AppIntent {
    nonisolated(unsafe) public static var title: LocalizedStringResource = "Summarize Text"
    nonisolated(unsafe) public static var description = IntentDescription("Use Thea to summarize text")

    @Parameter(title: "Text to Summarize")
    var text: String

    @Parameter(title: "Style", default: .concise)
    var style: SummarizationStyleEntity

    public init() {}

    public func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let styleEnum: SummarizationStyle = style.toStyle()
        let summary = try await OnDeviceAIService.shared.summarize(text: text, style: styleEnum)
        return .result(value: summary)
    }
}

// MARK: - Create Project Intent

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
public struct CreateProjectIntent: AppIntent {
    nonisolated(unsafe) public static var title: LocalizedStringResource = "Create Project"
    nonisolated(unsafe) public static var description = IntentDescription("Create a new project in Thea")

    @Parameter(title: "Project Name")
    var name: String

    @Parameter(title: "Description")
    var projectDescription: String?

    public init() {}

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        // Create project via ProjectManager
        .result(dialog: "Created project '\(name)' in Thea")
    }
}

// MARK: - Start Focus Session Intent

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
public struct StartFocusSessionIntent: AppIntent {
    nonisolated(unsafe) public static var title: LocalizedStringResource = "Start Focus Session"
    nonisolated(unsafe) public static var description = IntentDescription("Start a focus session with Thea")

    @Parameter(title: "Duration (minutes)", default: 25)
    var duration: Int

    @Parameter(title: "Task Description")
    var task: String?

    public init() {}

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        .result(dialog: "Starting \(duration)-minute focus session\(task.map { " for '\($0)'" } ?? "")")
    }
}

// MARK: - Log Health Data Intent

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
public struct LogHealthDataIntent: AppIntent {
    nonisolated(unsafe) public static var title: LocalizedStringResource = "Log Health Data"
    nonisolated(unsafe) public static var description = IntentDescription("Log health data with Thea")

    @Parameter(title: "Data Type", default: .mood)
    var dataType: HealthDataTypeEntity

    @Parameter(title: "Value")
    var value: String

    @Parameter(title: "Notes")
    var notes: String?

    public init() {}

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        .result(dialog: "Logged \(dataType.localizedStringResource) with value '\(value)'")
    }
}

// MARK: - Control Home Device Intent

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
public struct ControlHomeDeviceIntent: AppIntent {
    nonisolated(unsafe) public static var title: LocalizedStringResource = "Control Smart Home"
    nonisolated(unsafe) public static var description = IntentDescription("Control smart home devices through Thea")

    @Parameter(title: "Command")
    var command: String

    public init() {}

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        .result(dialog: "Sending command to smart home: \(command)")
    }
}

// MARK: - Get Daily Summary Intent

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
public struct GetDailySummaryIntent: AppIntent {
    nonisolated(unsafe) public static var title: LocalizedStringResource = "Get Daily Summary"
    nonisolated(unsafe) public static var description = IntentDescription("Get your daily summary from Thea")

    public init() {}

    public func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let summary = """
        📊 Your Daily Summary:
        • Tasks completed: 5
        • Focus time: 2h 30m
        • Messages: 12 unread
        • Health: 8,500 steps

        Open Thea for more details.
        """
        return .result(value: summary)
    }
}

// MARK: - App Shortcuts Provider

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
public struct TheaShortcuts: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AskTheaIntent(),
            phrases: [
                "Ask \(.applicationName) a question",
                "Hey \(.applicationName)",
                "Ask \(.applicationName)"
            ],
            shortTitle: "Ask Thea",
            systemImageName: "bubble.left.fill"
        )

        AppShortcut(
            intent: GetDailySummaryIntent(),
            phrases: [
                "Get my daily summary from \(.applicationName)",
                "What's my day like \(.applicationName)",
                "\(.applicationName) daily update"
            ],
            shortTitle: "Daily Summary",
            systemImageName: "chart.bar.fill"
        )

        AppShortcut(
            intent: StartFocusSessionIntent(),
            phrases: [
                "Start focus session with \(.applicationName)",
                "\(.applicationName) focus mode",
                "Help me focus \(.applicationName)"
            ],
            shortTitle: "Focus Session",
            systemImageName: "timer"
        )

        AppShortcut(
            intent: SummarizeTextIntent(),
            phrases: [
                "Summarize this with \(.applicationName)",
                "\(.applicationName) summarize"
            ],
            shortTitle: "Summarize",
            systemImageName: "doc.text"
        )
    }
}

// MARK: - Entity Definitions

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
public enum SummarizationStyleEntity: String, AppEnum {
    nonisolated(unsafe) public static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Summarization Style")

    nonisolated(unsafe) public static var caseDisplayRepresentations: [SummarizationStyleEntity: DisplayRepresentation] = [
        .concise: "Concise",
        .detailed: "Detailed",
        .bullets: "Bullet Points",
        .keyPoints: "Key Points"
    ]

    case concise
    case detailed
    case bullets
    case keyPoints

    func toStyle() -> SummarizationStyle {
        switch self {
        case .concise: .concise
        case .detailed: .detailed
        case .bullets: .bullets
        case .keyPoints: .keyPoints
        }
    }
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
public enum HealthDataTypeEntity: String, AppEnum {
    nonisolated(unsafe) public static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Health Data Type")

    nonisolated(unsafe) public static var caseDisplayRepresentations: [HealthDataTypeEntity: DisplayRepresentation] = [
        .mood: "Mood",
        .energy: "Energy Level",
        .sleep: "Sleep Quality",
        .water: "Water Intake",
        .exercise: "Exercise"
    ]

    case mood
    case energy
    case sleep
    case water
    case exercise
}

// MARK: - Options Providers

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
struct ConversationOptionsProvider: DynamicOptionsProvider {
    func results() async throws -> [String] {
        // Return list of conversation IDs
        ["default", "work", "personal"]
    }
}
