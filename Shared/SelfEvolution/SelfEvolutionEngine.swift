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

    /// Process a feature request via artifact-based approach (R3).
    ///
    /// Thea drafts code change proposals as reviewable Artifacts rather than applying live
    /// modifications. The user inspects the artifact and applies changes manually. This is safe
    /// and architecturally sound for a sandboxed app that cannot rewrite its own binary.
    public func processFeatureRequest(_ request: String) async throws -> EvolutionTask {
        isAnalyzing = true

        logger.info("Processing feature request (artifact mode): \(request)")

        let task = EvolutionTask(
            id: UUID(),
            request: request,
            status: .analyzing,
            createdAt: Date()
        )
        currentTask = task

        // Phase 1: Structural analysis
        let analysis = try await analyzeRequest(request)
        task.analysis = analysis
        isAnalyzing = false

        // Phase 2: Generate implementation via AI, produce as artifact
        isImplementing = true
        defer { isImplementing = false }

        let featureName = deriveFeatureName(from: request)
        let relevantCode = readRelevantSourceFiles(for: analysis)
        let implementationCode = try await generateImplementationArtifact(
            request: request,
            featureName: featureName,
            relevantCode: relevantCode
        )

        // Phase 3: Store as reviewable artifact (NOT applied to disk)
        let artifact = try await ArtifactManager.shared.createCodeArtifact(
            title: "SelfEvolution: \(featureName)",
            language: .swift,
            code: implementationCode,
            description: "Auto-generated proposal for: \(request). Review and apply manually.",
            conversationId: nil
        )

        task.artifactID = artifact.id
        task.reviewSummary = "Implementation ready in Artifacts: '\(artifact.title)'. Apply changes manually after review."
        task.status = .awaitingReview

        taskHistory.insert(task, at: 0)
        saveTaskHistory()

        logger.info("Feature request → artifact created: \(artifact.id)")
        return task
    }

    // MARK: - R3 Artifact Helpers

    private func deriveFeatureName(from request: String) -> String {
        let stopWords: Set<String> = ["a", "an", "the", "in", "on", "for", "to", "of", "and", "with"]
        let words = request.components(separatedBy: .whitespacesAndNewlines)
            .map { $0.capitalized }
            .filter { !$0.isEmpty && !stopWords.contains($0.lowercased()) }
        return words.prefix(3).joined()
    }

    private func readRelevantSourceFiles(for analysis: FeatureAnalysis) -> String {
        var snippets: [String] = []
        var budget = 8_192
        let divisor = max(1, analysis.affectedFiles.filter { $0.action == .modify }.count)
        for affected in analysis.affectedFiles.prefix(6) where affected.action == .modify {
            let url = sourceDirectory.appendingPathComponent(affected.path)
            guard let content = try? String(contentsOf: url, encoding: .utf8) else { continue }
            let snippet = String(content.prefix(budget / divisor))
            snippets.append("// FILE: \(affected.path)\n\(snippet)")
            budget -= snippet.count
            if budget <= 0 { break }
        }
        return snippets.joined(separator: "\n\n")
    }

    private func generateImplementationArtifact(
        request: String,
        featureName: String,
        relevantCode: String
    ) async throws -> String {
        let contextSection = relevantCode.isEmpty ? "" : "\n\nRelevant existing code:\n\(relevantCode)"
        let prompt = """
        You are implementing a feature for the Thea AI assistant app (Swift 6.0, strict concurrency, MVVM + SwiftUI + SwiftData, macOS/iOS/watchOS/tvOS).

        Feature request: \(request)
        Suggested class/file name: \(featureName)\(contextSection)

        Output ONLY Swift source file contents — no markdown, no explanation.
        Requirements: Swift 6.0 strict concurrency, @Observable, @MainActor, async/await, MVVM.
        """

        guard let provider = ProviderRegistry.shared.getProvider(id: "anthropic") ??
            ProviderRegistry.shared.getProvider(id: "openrouter") ??
            ProviderRegistry.shared.getLocalProvider() else {
            return buildFallbackTemplate(featureName: featureName, request: request)
        }

        let message = AIMessage(
            id: UUID(),
            conversationID: UUID(),
            role: .user,
            content: .text(prompt),
            timestamp: Date(),
            model: "evolution"
        )

        var response = ""
        let stream = try await provider.chat(messages: [message], model: "claude-sonnet-4-6", stream: false)
        for try await chunk in stream {
            if case .delta(let text) = chunk.type { response += text }
        }

        let code = extractSwiftCode(from: response, fallbackFileName: featureName)
        return code.isEmpty ? buildFallbackTemplate(featureName: featureName, request: request) : code
    }

    private func buildFallbackTemplate(featureName: String, request: String) -> String {
        """
        // \(featureName).swift
        // Auto-generated by Thea Self-Evolution Engine (no provider available — review and implement)
        // Feature request: \(request)

        import Foundation
        import OSLog
        import SwiftUI

        @Observable
        @MainActor
        public final class \(featureName) {
            public static let shared = \(featureName)()
            private let logger = Logger(subsystem: "app.thea", category: "\(featureName)")
            private init() {}

            public func execute() async throws {
                logger.info("\(featureName): implement feature logic here")
            }
        }
        """
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

    // periphery:ignore - Reserved: AD3 audit — wired in future integration
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

    // periphery:ignore - Reserved: AD3 audit — wired in future integration
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
            do {
                try fileManager.createDirectory(at: buildDirectory, withIntermediateDirectories: true)
            } catch {
                logger.error("Failed to create build directory: \(error.localizedDescription)")
            }

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
            do {
                try fileManager.removeItem(at: backupPath)
            } catch {
                logger.error("Failed to remove old backup: \(error.localizedDescription)")
            }
            try fileManager.moveItem(at: applicationsPath, to: backupPath)
        }

        // Copy new app
        do {
            try fileManager.copyItem(at: update.buildPath, to: applicationsPath)

            // Remove backup on success
            do {
                try fileManager.removeItem(at: backupPath)
            } catch {
                logger.error("Failed to remove backup after install: \(error.localizedDescription)")
            }

            // Update task status
            update.task.status = .installed
            pendingUpdate = nil

            logger.info("Update installed successfully")

            // Prompt for restart
            NotificationCenter.default.post(name: .evolutionInstallComplete, object: nil)

        } catch {
            // Restore backup on failure
            if fileManager.fileExists(atPath: backupPath.path) {
                do {
                    try fileManager.removeItem(at: applicationsPath)
                } catch {
                    logger.error("Failed to remove broken install during rollback: \(error.localizedDescription)")
                }
                do {
                    try fileManager.moveItem(at: backupPath, to: applicationsPath)
                } catch {
                    logger.error("Failed to restore backup during rollback: \(error.localizedDescription)")
                }
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
        if let data = UserDefaults.standard.data(forKey: "evolution.taskHistory") {
            do {
                taskHistory = try JSONDecoder().decode([EvolutionTask].self, from: data)
            } catch {
                logger.error("Failed to decode task history: \(error.localizedDescription)")
            }
        }
    }

    private func saveTaskHistory() {
        do {
            let data = try JSONEncoder().encode(taskHistory)
            UserDefaults.standard.set(data, forKey: "evolution.taskHistory")
        } catch {
            logger.error("Failed to encode task history: \(error.localizedDescription)")
        }
    }
}
