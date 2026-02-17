#if os(macOS)
    import Foundation

    /// Represents a single step in a Cowork task execution
    struct CoworkStep: Identifiable, Codable, Equatable {
        let id: UUID
        var stepNumber: Int
        var description: String
        var status: StepStatus
        var toolsUsed: [String]
        var inputFiles: [URL]
        var outputFiles: [URL]
        var startedAt: Date?
        var completedAt: Date?
        var error: String?
        var logs: [LogEntry]

        /// Whether this step is considered high-risk (e.g. deletes files, modifies system state).
        /// High-risk steps require explicit acknowledgement before the plan can execute.
        var isHighRisk: Bool

        /// Optional notes shown in the plan checklist; populated by the planner with context.
        var notes: String?

        /// Set to true when the user acknowledges a high-risk step in the plan preview.
        var riskAcknowledged: Bool

        enum StepStatus: String, Codable, CaseIterable {
            case pending = "Pending"
            case inProgress = "In Progress"
            case completed = "Completed"
            case failed = "Failed"
            case skipped = "Skipped"

            var icon: String {
                switch self {
                case .pending: "circle"
                case .inProgress: "play.circle.fill"
                case .completed: "checkmark.circle.fill"
                case .failed: "xmark.circle.fill"
                case .skipped: "forward.circle"
                }
            }

            var color: String {
                switch self {
                case .pending: "secondary"
                case .inProgress: "blue"
                case .completed: "green"
                case .failed: "red"
                case .skipped: "orange"
                }
            }
        }

        struct LogEntry: Codable, Identifiable, Equatable {
            let id: UUID
            let timestamp: Date
            let level: LogLevel
            let message: String
            let details: String?

            enum LogLevel: String, Codable {
                case info, warning, error, debug

                var icon: String {
                    switch self {
                    case .info: "info.circle"
                    case .warning: "exclamationmark.triangle"
                    case .error: "xmark.circle"
                    case .debug: "ladybug"
                    }
                }
            }

            init(level: LogLevel, message: String, details: String? = nil) {
                id = UUID()
                timestamp = Date()
                self.level = level
                self.message = message
                self.details = details
            }
        }

        init(
            id: UUID = UUID(),
            stepNumber: Int,
            description: String,
            status: StepStatus = .pending,
            toolsUsed: [String] = [],
            inputFiles: [URL] = [],
            outputFiles: [URL] = [],
            isHighRisk: Bool = false,
            notes: String? = nil
        ) {
            self.id = id
            self.stepNumber = stepNumber
            self.description = description
            self.status = status
            self.toolsUsed = toolsUsed
            self.inputFiles = inputFiles
            self.outputFiles = outputFiles
            self.isHighRisk = isHighRisk
            self.notes = notes
            self.riskAcknowledged = false
            logs = []
        }

        var duration: TimeInterval? {
            guard let start = startedAt, let end = completedAt else { return nil }
            return end.timeIntervalSince(start)
        }

        mutating func start() {
            status = .inProgress
            startedAt = Date()
            addLog(.info, "Step started")
        }

        mutating func complete() {
            status = .completed
            completedAt = Date()
            addLog(.info, "Step completed successfully")
        }

        mutating func fail(with error: String) {
            status = .failed
            completedAt = Date()
            self.error = error
            addLog(.error, "Step failed: \(error)")
        }

        mutating func skip(reason: String? = nil) {
            status = .skipped
            completedAt = Date()
            addLog(.info, "Step skipped\(reason.map { ": \($0)" } ?? "")")
        }

        mutating func addLog(_ level: LogEntry.LogLevel, _ message: String, details: String? = nil) {
            logs.append(LogEntry(level: level, message: message, details: details))
        }

        mutating func addInputFile(_ url: URL) {
            if !inputFiles.contains(url) {
                inputFiles.append(url)
            }
        }

        mutating func addOutputFile(_ url: URL) {
            if !outputFiles.contains(url) {
                outputFiles.append(url)
            }
        }

        mutating func addTool(_ tool: String) {
            if !toolsUsed.contains(tool) {
                toolsUsed.append(tool)
            }
        }
    }

    // MARK: - Step Builder

    extension CoworkStep {
        /// Builder for creating steps with fluent API
        class Builder {
            private var stepNumber: Int = 0
            private var description: String = ""
            private var tools: [String] = []
            private var inputs: [URL] = []
            private var outputs: [URL] = []
            private var highRisk: Bool = false
            private var stepNotes: String?

            func number(_ n: Int) -> Builder {
                stepNumber = n
                return self
            }

            func description(_ desc: String) -> Builder {
                description = desc
                return self
            }

            func tool(_ tool: String) -> Builder {
                tools.append(tool)
                return self
            }

            func tools(_ tools: [String]) -> Builder {
                self.tools.append(contentsOf: tools)
                return self
            }

            func input(_ url: URL) -> Builder {
                inputs.append(url)
                return self
            }

            func output(_ url: URL) -> Builder {
                outputs.append(url)
                return self
            }

            func highRisk(_ flag: Bool = true) -> Builder {
                highRisk = flag
                return self
            }

            func notes(_ text: String) -> Builder {
                stepNotes = text
                return self
            }

            func build() -> CoworkStep {
                CoworkStep(
                    stepNumber: stepNumber,
                    description: description,
                    toolsUsed: tools,
                    inputFiles: inputs,
                    outputFiles: outputs,
                    isHighRisk: highRisk,
                    notes: stepNotes
                )
            }
        }

        static func builder() -> Builder {
            Builder()
        }
    }

#endif
