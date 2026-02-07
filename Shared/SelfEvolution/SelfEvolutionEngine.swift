// SelfEvolutionEngine.swift
// Autonomous feature implementation and codebase evolution

import Combine
import Foundation
import OSLog

// MARK: - Self Evolution Engine

/// Enables Thea to implement new features to its own codebase
@MainActor
public final class SelfEvolutionEngine: ObservableObject {
    public static let shared = SelfEvolutionEngine()

    private let logger = Logger(subsystem: "com.thea.app", category: "SelfEvolution")
    private let fileManager = FileManager.default

    // MARK: - Published State

    @Published public private(set) var currentTask: EvolutionTask?
    @Published public private(set) var taskHistory: [EvolutionTask] = []
    @Published public private(set) var isAnalyzing = false
    @Published public private(set) var isImplementing = false
    @Published public private(set) var isTesting = false
    @Published public private(set) var isBuilding = false
    @Published public private(set) var buildProgress: BuildProgress?
    @Published public private(set) var lastBuildResult: BuildResult?
    @Published public private(set) var pendingUpdate: PendingUpdate?

    // MARK: - Paths

    private var projectRoot: URL {
        // Get the Thea project root
        Bundle.main.bundleURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private var sourceDirectory: URL {
        projectRoot.appendingPathComponent("Shared")
    }

    private var buildDirectory: URL {
        projectRoot.appendingPathComponent("Build")
    }

    // MARK: - Configuration

    private let xcodeProjectName = "Thea.xcodeproj"
    private let schemeName = "Thea"

    // MARK: - Initialization

    private init() {
        loadTaskHistory()
    }

    // MARK: - Feature Request Processing

    /// Process a feature request from the user
    public func processFeatureRequest(_ request: String) async throws -> EvolutionTask {
        isAnalyzing = true
        defer { isAnalyzing = false }

        logger.info("Processing feature request: \(request)")

        // Create evolution task
        let task = EvolutionTask(
            id: UUID(),
            request: request,
            status: .analyzing,
            createdAt: Date()
        )

        currentTask = task

        // Phase 1: Analyze the request
        let analysis = try await analyzeRequest(request)
        task.analysis = analysis

        // Phase 2: Plan implementation
        let plan = try await planImplementation(analysis)
        task.plan = plan

        // Phase 3: Estimate complexity
        let estimate = estimateComplexity(plan)
        task.estimate = estimate

        task.status = .planned

        // Save to history
        taskHistory.insert(task, at: 0)
        saveTaskHistory()

        return task
    }

    // MARK: - Analysis

    private func analyzeRequest(_ request: String) async throws -> FeatureAnalysis {
        // Analyze what files need to be created/modified
        var affectedFiles: [AffectedFile] = []
        var dependencies: [String] = []
        var risks: [ImplementationRisk] = []

        // Use AI to analyze the request
        // This would integrate with the AI provider to understand the request

        // For now, create a structured analysis
        let category = categorizeRequest(request)
        let scope = determineScope(request)

        // Identify affected areas
        let areas = identifyAffectedAreas(request, category: category)

        for area in areas {
            affectedFiles.append(AffectedFile(
                path: area.path,
                action: area.isNew ? .create : .modify,
                description: area.description
            ))
        }

        // Identify dependencies
        dependencies = identifyDependencies(category)

        // Assess risks
        risks = assessRisks(scope: scope, affectedFiles: affectedFiles)

        return FeatureAnalysis(
            category: category,
            scope: scope,
            affectedFiles: affectedFiles,
            dependencies: dependencies,
            risks: risks,
            summary: "Feature request analyzed: \(request)"
        )
    }

    private func categorizeRequest(_ request: String) -> FeatureCategory {
        let lowercased = request.lowercased()

        if lowercased.contains("ui") || lowercased.contains("view") || lowercased.contains("screen") {
            return .ui
        }
        if lowercased.contains("api") || lowercased.contains("network") || lowercased.contains("server") {
            return .networking
        }
        if lowercased.contains("ai") || lowercased.contains("model") || lowercased.contains("intelligence") {
            return .ai
        }
        if lowercased.contains("data") || lowercased.contains("storage") || lowercased.contains("persist") {
            return .data
        }
        if lowercased.contains("setting") || lowercased.contains("preference") || lowercased.contains("config") {
            return .settings
        }
        if lowercased.contains("security") || lowercased.contains("auth") || lowercased.contains("permission") {
            return .security
        }

        return .core
    }

    private func determineScope(_ request: String) -> ImplementationScope {
        let wordCount = request.split(separator: " ").count

        if wordCount < 10 {
            return .minor
        } else if wordCount < 30 {
            return .moderate
        } else {
            return .major
        }
    }

    private func identifyAffectedAreas(_: String, category: FeatureCategory) -> [(path: String, isNew: Bool, description: String)] {
        var areas: [(path: String, isNew: Bool, description: String)] = []

        switch category {
        case .ui:
            areas.append(("Shared/UI/Views/", true, "New view implementation"))
            areas.append(("Shared/UI/Components/", false, "Component updates"))
        case .networking:
            areas.append(("Shared/Networking/", false, "Network layer updates"))
        case .ai:
            areas.append(("Shared/AI/", true, "AI feature implementation"))
        case .data:
            areas.append(("Shared/Core/DataModel/", false, "Data model updates"))
        case .settings:
            areas.append(("Shared/Core/Managers/SettingsManager.swift", false, "Settings updates"))
            areas.append(("Shared/UI/Views/Settings/", false, "Settings UI updates"))
        case .security:
            areas.append(("Shared/AgentSec/", false, "Security updates"))
        case .core:
            areas.append(("Shared/Core/", false, "Core functionality updates"))
        }

        return areas
    }

    private func identifyDependencies(_ category: FeatureCategory) -> [String] {
        switch category {
        case .ui: ["SwiftUI", "Combine"]
        case .networking: ["Foundation", "Network"]
        case .ai: ["NaturalLanguage", "CoreML"]
        case .data: ["SwiftData", "Foundation"]
        case .settings: ["SwiftUI", "Combine"]
        case .security: ["CryptoKit", "LocalAuthentication"]
        case .core: ["Foundation", "Combine"]
        }
    }

    private func assessRisks(scope: ImplementationScope, affectedFiles: [AffectedFile]) -> [ImplementationRisk] {
        var risks: [ImplementationRisk] = []

        if scope == .major {
            risks.append(ImplementationRisk(
                level: .high,
                description: "Major scope change may affect multiple subsystems",
                mitigation: "Implement incrementally with extensive testing"
            ))
        }

        let modifyCount = affectedFiles.count { $0.action == .modify }
        if modifyCount > 5 {
            risks.append(ImplementationRisk(
                level: .medium,
                description: "Multiple file modifications increase regression risk",
                mitigation: "Run full test suite after implementation"
            ))
        }

        return risks
    }

    // MARK: - Planning

    private func planImplementation(_ analysis: FeatureAnalysis) async throws -> ImplementationPlan {
        var steps: [ImplementationStep] = []

        // Step 1: Create/modify files
        for (index, file) in analysis.affectedFiles.enumerated() {
            steps.append(ImplementationStep(
                order: index + 1,
                title: file.action == .create ? "Create \(file.path)" : "Modify \(file.path)",
                description: file.description,
                type: file.action == .create ? .createFile : .modifyFile,
                filePath: file.path,
                estimatedDuration: file.action == .create ? 300 : 180 // seconds
            ))
        }

        // Step 2: Update integration points
        steps.append(ImplementationStep(
            order: steps.count + 1,
            title: "Update integration hub",
            description: "Register new components in TheaIntegrationHub",
            type: .modifyFile,
            filePath: "Shared/Core/TheaIntegrationHub.swift",
            estimatedDuration: 60
        ))

        // Step 3: Write tests
        steps.append(ImplementationStep(
            order: steps.count + 1,
            title: "Write unit tests",
            description: "Create tests for new functionality",
            type: .createFile,
            filePath: "Tests/",
            estimatedDuration: 300
        ))

        // Step 4: Build and verify
        steps.append(ImplementationStep(
            order: steps.count + 1,
            title: "Build and verify",
            description: "Compile and run tests",
            type: .build,
            filePath: nil,
            estimatedDuration: 120
        ))

        let totalDuration = steps.reduce(0) { $0 + $1.estimatedDuration }

        return ImplementationPlan(
            steps: steps,
            estimatedTotalDuration: totalDuration,
            requiredCapabilities: analysis.dependencies
        )
    }

    private func estimateComplexity(_ plan: ImplementationPlan) -> ComplexityEstimate {
        let stepCount = plan.steps.count
        let duration = plan.estimatedTotalDuration

        let level: ComplexityLevel = if stepCount <= 3, duration < 600 {
            .low
        } else if stepCount <= 6, duration < 1800 {
            .medium
        } else {
            .high
        }

        return ComplexityEstimate(
            level: level,
            estimatedSteps: stepCount,
            estimatedDuration: duration,
            confidence: 0.8
        )
    }

    // MARK: - Implementation

    /// Execute the implementation plan
    public func executeImplementation(_ task: EvolutionTask) async throws {
        guard let plan = task.plan else {
            throw EvolutionError.noPlan
        }

        isImplementing = true
        task.status = .implementing
        currentTask = task

        defer {
            isImplementing = false
        }

        logger.info("Starting implementation for task: \(task.id)")

        for step in plan.steps {
            task.currentStep = step.order

            do {
                try await executeStep(step, task: task)
                task.completedSteps.append(step.order)
            } catch {
                task.status = .failed
                task.error = error.localizedDescription
                throw error
            }
        }

        // Implementation complete, start build
        task.status = .building
        try await buildProject(task: task)
    }

    private func executeStep(_ step: ImplementationStep, task: EvolutionTask) async throws {
        logger.info("Executing step \(step.order): \(step.title)")

        switch step.type {
        case .createFile:
            try await createFile(at: step.filePath!, for: task)
        case .modifyFile:
            try await modifyFile(at: step.filePath!, for: task)
        case .deleteFile:
            try await deleteFile(at: step.filePath!)
        case .build:
            // Handled separately
            break
        case .test:
            try await runTests()
        }

        // Simulate implementation time
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
    }

    private func createFile(at path: String, for task: EvolutionTask) async throws {
        let fullPath = sourceDirectory.appendingPathComponent(path)

        // Ensure directory exists
        let directory = fullPath.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        // Generate file content using AI
        let content = try await generateFileContent(for: path, task: task)

        try content.write(to: fullPath, atomically: true, encoding: .utf8)

        logger.info("Created file: \(path)")
    }

    private func modifyFile(at path: String, for task: EvolutionTask) async throws {
        let fullPath = sourceDirectory.appendingPathComponent(path)

        guard fileManager.fileExists(atPath: fullPath.path) else {
            throw EvolutionError.fileNotFound(path)
        }

        // Read existing content
        let existingContent = try String(contentsOf: fullPath, encoding: .utf8)

        // Generate modifications using AI
        let modifiedContent = try await generateModifications(
            original: existingContent,
            path: path,
            task: task
        )

        try modifiedContent.write(to: fullPath, atomically: true, encoding: .utf8)

        logger.info("Modified file: \(path)")
    }

    private func deleteFile(at path: String) async throws {
        let fullPath = sourceDirectory.appendingPathComponent(path)
        try fileManager.removeItem(at: fullPath)
        logger.info("Deleted file: \(path)")
    }

    private func generateFileContent(for path: String, task: EvolutionTask) async throws -> String {
        let fileName = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent

        // Try to use AI for code generation
        if let provider = ProviderRegistry.shared.getProvider(id: "anthropic") ??
            ProviderRegistry.shared.getProvider(id: "openrouter") ??
            ProviderRegistry.shared.getLocalProvider()
        {
            let prompt = """
            Generate Swift code for a new file in the Thea AI assistant app.

            File path: \(path)
            Feature request: \(task.request)
            Category: \(task.analysis?.category.rawValue ?? "core")

            Requirements:
            1. Use Swift 6.0 with strict concurrency
            2. Use @MainActor for UI-related code
            3. Use @Observable macro for observable classes
            4. Follow MVVM architecture
            5. Include proper error handling
            6. Add comprehensive documentation comments
            7. Use dependency injection where appropriate

            Generate production-ready Swift code:
            """

            let message = AIMessage(
                id: UUID(),
                conversationID: UUID(),
                role: .user,
                content: .text(prompt),
                timestamp: Date(),
                model: "evolution"
            )

            do {
                var response = ""
                let stream = try await provider.chat(
                    messages: [message],
                    model: provider.metadata.name.contains("local") ? provider.metadata.name : "anthropic/claude-3-haiku",
                    stream: false
                )

                for try await chunk in stream {
                    if case .delta(let text) = chunk.type {
                        response += text
                    }
                }

                // Extract code from response
                return extractSwiftCode(from: response, fallbackFileName: fileName)
            } catch {
                logger.warning("AI code generation failed: \(error.localizedDescription)")
            }
        }

        // Fallback to template
        return """
        // \(fileName).swift
        // Auto-generated by Thea Self-Evolution Engine
        // Task: \(task.request)

        import Foundation
        import OSLog

        // MARK: - \(fileName)

        /// Generated implementation for: \(task.request)
        @MainActor
        @Observable
        public final class \(fileName) {
            public static let shared = \(fileName)()

            private let logger = Logger(subsystem: "app.thea", category: "\(fileName)")

            private init() {
                logger.info("\(fileName) initialized")
            }

            // TODO: Implement feature logic
        }
        """
    }

    private func extractSwiftCode(from response: String, fallbackFileName: String) -> String {
        // Try to extract code from markdown code blocks
        if let startIndex = response.range(of: "```swift")?.upperBound,
           let endIndex = response.range(of: "```", range: startIndex ..< response.endIndex)?.lowerBound
        {
            return String(response[startIndex ..< endIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Try plain code blocks
        if let startIndex = response.range(of: "```")?.upperBound,
           let endIndex = response.range(of: "```", range: startIndex ..< response.endIndex)?.lowerBound
        {
            return String(response[startIndex ..< endIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // If response looks like Swift code, return it directly
        if response.contains("import ") && response.contains("class ") || response.contains("struct ") {
            return response
        }

        // Return template as fallback
        return """
        // \(fallbackFileName).swift
        // Auto-generated by Thea Self-Evolution Engine

        import Foundation

        // MARK: - \(fallbackFileName)

        @MainActor
        @Observable
        public final class \(fallbackFileName) {
            public static let shared = \(fallbackFileName)()
            private init() {}
        }
        """
    }

    private func generateModifications(original: String, path: String, task: EvolutionTask) async throws -> String {
        // Try to use AI for modifications
        if let provider = ProviderRegistry.shared.getProvider(id: "anthropic") ??
            ProviderRegistry.shared.getProvider(id: "openrouter") ??
            ProviderRegistry.shared.getLocalProvider()
        {
            let prompt = """
            Modify this Swift file to implement a new feature.

            File: \(path)
            Feature request: \(task.request)

            Current file content:
            ```swift
            \(original.prefix(3000))
            ```
            \(original.count > 3000 ? "... (truncated)" : "")

            Requirements:
            1. Preserve existing functionality
            2. Add new code that implements the requested feature
            3. Follow the existing code style
            4. Add proper error handling
            5. Document new code with comments

            Return the complete modified file:
            """

            let message = AIMessage(
                id: UUID(),
                conversationID: UUID(),
                role: .user,
                content: .text(prompt),
                timestamp: Date(),
                model: "evolution"
            )

            do {
                var response = ""
                let stream = try await provider.chat(
                    messages: [message],
                    model: provider.metadata.name.contains("local") ? provider.metadata.name : "anthropic/claude-3-haiku",
                    stream: false
                )

                for try await chunk in stream {
                    if case .delta(let text) = chunk.type {
                        response += text
                    }
                }

                // Extract code from response
                let modifiedCode = extractSwiftCode(from: response, fallbackFileName: "modified")
                if modifiedCode.count > original.count / 2 { // Sanity check
                    return modifiedCode
                }
            } catch {
                logger.warning("AI modification failed: \(error.localizedDescription)")
            }
        }

        // Fallback: return original with comment
        return """
        // Modified by Thea Self-Evolution Engine
        // Task: \(task.request)
        // Note: AI modification unavailable, manual implementation needed

        \(original)
        """
    }

    // MARK: - Building

    private func buildProject(task: EvolutionTask) async throws {
        isBuilding = true
        defer { isBuilding = false }

        buildProgress = BuildProgress(phase: .preparing, progress: 0)

        logger.info("Starting build...")

        // Build phases
        let phases: [(BuildPhase, Double)] = [
            (.preparing, 0.1),
            (.compiling, 0.6),
            (.linking, 0.2),
            (.signing, 0.1)
        ]

        for (phase, _) in phases {
            buildProgress = BuildProgress(phase: phase, progress: 0)

            // Simulate build progress
            for i in 0 ... 10 {
                try await Task.sleep(nanoseconds: 50_000_000)
                buildProgress = BuildProgress(phase: phase, progress: Double(i) / 10.0)
            }
        }

        // Execute actual build
        let result = try await executeBuild()

        lastBuildResult = result
        task.buildResult = result

        if result.success {
            task.status = .testing
            try await runTests()

            if task.testsPassed {
                task.status = .readyToInstall

                // Create pending update
                pendingUpdate = PendingUpdate(
                    task: task,
                    buildPath: result.outputPath!,
                    version: generateVersion(),
                    createdAt: Date()
                )

                // Notify user
                NotificationCenter.default.post(
                    name: .evolutionUpdateReady,
                    object: pendingUpdate
                )
            } else {
                task.status = .testsFailed
            }
        } else {
            task.status = .buildFailed
            task.error = result.errors.joined(separator: "\n")
        }

        saveTaskHistory()
    }

    private func executeBuild() async throws -> BuildResult {
        #if os(macOS)
            let projectPath = projectRoot.appendingPathComponent(xcodeProjectName)
            let outputPath = buildDirectory.appendingPathComponent("Thea.app")

            // Create build directory
            try? fileManager.createDirectory(at: buildDirectory, withIntermediateDirectories: true)

            // Execute xcodebuild
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/xcodebuild")
            process.arguments = [
                "-project", projectPath.path,
                "-scheme", schemeName,
                "-configuration", "Release",
                "-derivedDataPath", buildDirectory.path,
                "build"
            ]

            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            do {
                try process.run()
                process.waitUntilExit()

                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

                let output = String(data: outputData, encoding: .utf8) ?? ""
                let errors = String(data: errorData, encoding: .utf8) ?? ""

                let success = process.terminationStatus == 0

                return BuildResult(
                    success: success,
                    outputPath: success ? outputPath : nil,
                    duration: 0,
                    warnings: extractWarnings(from: output),
                    errors: success ? [] : [errors]
                )
            } catch {
                return BuildResult(
                    success: false,
                    outputPath: nil,
                    duration: 0,
                    warnings: [],
                    errors: [error.localizedDescription]
                )
            }
        #else
            // Building is not supported on iOS
            return BuildResult(
                success: false,
                outputPath: nil,
                duration: 0,
                warnings: [],
                errors: ["Self-evolution build is only available on macOS"]
            )
        #endif
    }

    private func extractWarnings(from output: String) -> [String] {
        output.components(separatedBy: "\n")
            .filter { $0.contains("warning:") }
    }

    // MARK: - Testing

    private func runTests() async throws {
        #if os(macOS)
            isTesting = true
            defer { isTesting = false }

            logger.info("Running tests...")

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/xcodebuild")
            process.arguments = [
                "-project", projectRoot.appendingPathComponent(xcodeProjectName).path,
                "-scheme", schemeName,
                "-destination", "platform=macOS",
                "test"
            ]

            try process.run()
            process.waitUntilExit()

            currentTask?.testsPassed = process.terminationStatus == 0
        #else
            // Testing is not supported on iOS
            logger.warning("Self-evolution testing is only available on macOS")
        #endif
    }

    // MARK: - Installation

    /// Install the pending update to /Applications
    public func installUpdate() async throws {
        guard let update = pendingUpdate else {
            throw EvolutionError.noUpdateAvailable
        }

        logger.info("Installing update...")

        let applicationsPath = URL(fileURLWithPath: "/Applications/Thea.app")
        let backupPath = URL(fileURLWithPath: "/Applications/Thea.app.backup")

        // Backup existing app
        if fileManager.fileExists(atPath: applicationsPath.path) {
            try? fileManager.removeItem(at: backupPath)
            try fileManager.moveItem(at: applicationsPath, to: backupPath)
        }

        // Copy new app
        do {
            try fileManager.copyItem(at: update.buildPath, to: applicationsPath)

            // Remove backup on success
            try? fileManager.removeItem(at: backupPath)

            // Update task status
            update.task.status = .installed
            pendingUpdate = nil

            logger.info("Update installed successfully")

            // Prompt for restart
            NotificationCenter.default.post(name: .evolutionInstallComplete, object: nil)

        } catch {
            // Restore backup on failure
            if fileManager.fileExists(atPath: backupPath.path) {
                try? fileManager.removeItem(at: applicationsPath)
                try? fileManager.moveItem(at: backupPath, to: applicationsPath)
            }

            throw EvolutionError.installFailed(error.localizedDescription)
        }
    }

    // MARK: - Helpers

    private func generateVersion() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd.HHmm"
        return formatter.string(from: Date())
    }

    private func loadTaskHistory() {
        if let data = UserDefaults.standard.data(forKey: "evolution.taskHistory"),
           let history = try? JSONDecoder().decode([EvolutionTask].self, from: data)
        {
            taskHistory = history
        }
    }

    private func saveTaskHistory() {
        if let data = try? JSONEncoder().encode(taskHistory) {
            UserDefaults.standard.set(data, forKey: "evolution.taskHistory")
        }
    }
}

// MARK: - Types

public class EvolutionTask: Identifiable, ObservableObject, Codable {
    public let id: UUID
    public let request: String
    @Published public var status: TaskStatus
    public let createdAt: Date

    public var analysis: FeatureAnalysis?
    public var plan: ImplementationPlan?
    public var estimate: ComplexityEstimate?
    public var currentStep: Int = 0
    public var completedSteps: [Int] = []
    public var buildResult: BuildResult?
    public var testsPassed: Bool = false
    public var error: String?

    enum CodingKeys: String, CodingKey {
        case id, request, status, createdAt, analysis, plan, estimate
        case currentStep, completedSteps, buildResult, testsPassed, error
    }

    init(id: UUID, request: String, status: TaskStatus, createdAt: Date) {
        self.id = id
        self.request = request
        self.status = status
        self.createdAt = createdAt
    }

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        request = try container.decode(String.self, forKey: .request)
        status = try container.decode(TaskStatus.self, forKey: .status)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        analysis = try container.decodeIfPresent(FeatureAnalysis.self, forKey: .analysis)
        plan = try container.decodeIfPresent(ImplementationPlan.self, forKey: .plan)
        estimate = try container.decodeIfPresent(ComplexityEstimate.self, forKey: .estimate)
        currentStep = try container.decodeIfPresent(Int.self, forKey: .currentStep) ?? 0
        completedSteps = try container.decodeIfPresent([Int].self, forKey: .completedSteps) ?? []
        buildResult = try container.decodeIfPresent(BuildResult.self, forKey: .buildResult)
        testsPassed = try container.decodeIfPresent(Bool.self, forKey: .testsPassed) ?? false
        error = try container.decodeIfPresent(String.self, forKey: .error)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(request, forKey: .request)
        try container.encode(status, forKey: .status)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(analysis, forKey: .analysis)
        try container.encodeIfPresent(plan, forKey: .plan)
        try container.encodeIfPresent(estimate, forKey: .estimate)
        try container.encode(currentStep, forKey: .currentStep)
        try container.encode(completedSteps, forKey: .completedSteps)
        try container.encodeIfPresent(buildResult, forKey: .buildResult)
        try container.encode(testsPassed, forKey: .testsPassed)
        try container.encodeIfPresent(error, forKey: .error)
    }
}

public enum TaskStatus: String, Codable {
    case analyzing
    case planned
    case implementing
    case building
    case testing
    case testsFailed
    case buildFailed
    case readyToInstall
    case installed
    case failed
}

public struct FeatureAnalysis: Codable {
    public let category: FeatureCategory
    public let scope: ImplementationScope
    public let affectedFiles: [AffectedFile]
    public let dependencies: [String]
    public let risks: [ImplementationRisk]
    public let summary: String
}

public enum FeatureCategory: String, Codable {
    case ui
    case networking
    case ai
    case data
    case settings
    case security
    case core
}

public enum ImplementationScope: String, Codable {
    case minor
    case moderate
    case major
}

public struct AffectedFile: Codable {
    public let path: String
    public let action: FileAction
    public let description: String

    public enum FileAction: String, Codable {
        case create
        case modify
        case delete
    }
}

public struct ImplementationRisk: Codable {
    public let level: RiskLevel
    public let description: String
    public let mitigation: String

    public enum RiskLevel: String, Codable {
        case low
        case medium
        case high
    }
}

public struct ImplementationPlan: Codable {
    public let steps: [ImplementationStep]
    public let estimatedTotalDuration: Int
    public let requiredCapabilities: [String]
}

public struct ImplementationStep: Codable {
    public let order: Int
    public let title: String
    public let description: String
    public let type: StepType
    public let filePath: String?
    public let estimatedDuration: Int

    public enum StepType: String, Codable {
        case createFile
        case modifyFile
        case deleteFile
        case build
        case test
    }
}

public struct ComplexityEstimate: Codable {
    public let level: ComplexityLevel
    public let estimatedSteps: Int
    public let estimatedDuration: Int
    public let confidence: Double
}

public enum ComplexityLevel: String, Codable {
    case low
    case medium
    case high
}

public struct BuildProgress {
    public let phase: BuildPhase
    public let progress: Double
}

public enum BuildPhase: String {
    case preparing
    case compiling
    case linking
    case signing
}

public struct BuildResult: Codable {
    public let success: Bool
    public let outputPath: URL?
    public let duration: TimeInterval
    public let warnings: [String]
    public let errors: [String]
}

public struct PendingUpdate {
    public let task: EvolutionTask
    public let buildPath: URL
    public let version: String
    public let createdAt: Date
}

public enum EvolutionError: Error, LocalizedError {
    case noPlan
    case fileNotFound(String)
    case buildFailed(String)
    case testsFailed
    case noUpdateAvailable
    case installFailed(String)

    public var errorDescription: String? {
        switch self {
        case .noPlan: "No implementation plan available"
        case let .fileNotFound(path): "File not found: \(path)"
        case let .buildFailed(reason): "Build failed: \(reason)"
        case .testsFailed: "Tests failed"
        case .noUpdateAvailable: "No update available"
        case let .installFailed(reason): "Installation failed: \(reason)"
        }
    }
}

// MARK: - Notifications

public extension Notification.Name {
    static let evolutionUpdateReady = Notification.Name("thea.evolution.updateReady")
    static let evolutionInstallComplete = Notification.Name("thea.evolution.installComplete")
}
