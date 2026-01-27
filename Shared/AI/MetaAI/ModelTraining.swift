import Foundation

// MARK: - Custom Model Training

// Fine-tuning, few-shot learning, and continual learning capabilities

@MainActor
@Observable
final class ModelTraining {
    static let shared = ModelTraining()

    private(set) var trainingJobs: [TrainingJob] = []
    private(set) var fineTunedModels: [FineTunedModel] = []
    private(set) var fewShotExamples: [TrainingFewShotExample] = []
    private(set) var promptTemplates: [TrainingPromptTemplate] = []

    private init() {
        initializePromptTemplates()
    }

    // MARK: - Fine-Tuning

    func createFineTuningJob(
        provider: String,
        baseModel: String,
        trainingData: [TrainingExample],
        validationData _: [TrainingExample] = [],
        config: FineTuningConfig = FineTuningConfig()
    ) async throws -> TrainingJob {
        // Validate training data
        guard !trainingData.isEmpty else {
            throw TrainingError.insufficientData
        }

        // Prepare training file
        let trainingFile = try await prepareTrainingFile(trainingData)

        let job = TrainingJob(
            id: UUID(),
            provider: provider,
            baseModel: baseModel,
            status: .pending,
            trainingFile: trainingFile,
            config: config,
            createdAt: Date(),
            startedAt: nil,
            completedAt: nil,
            fineTunedModel: nil,
            metrics: TrainingMetrics()
        )

        trainingJobs.append(job)

        // Start training
        Task {
            await executeTraining(job)
        }

        return job
    }

    nonisolated private func executeTraining(_ job: TrainingJob) async {
        await MainActor.run {
            job.status = .training
            job.startedAt = Date()
        }

        do {
            // Submit to provider's fine-tuning API
            let modelId = try await submitFineTuningJob(job)

            // Poll for completion
            try await waitForCompletion(job, modelId: modelId)

            let model = FineTunedModel(
                id: UUID(),
                name: "Fine-tuned \(job.baseModel)",
                baseModel: job.baseModel,
                provider: job.provider,
                modelId: modelId,
                trainingJobId: job.id,
                createdAt: Date(),
                metrics: job.metrics
            )

            await MainActor.run {
                job.status = .completed
                job.completedAt = Date()
                job.fineTunedModel = modelId
                fineTunedModels.append(model)
            }
        } catch {
            await MainActor.run {
                job.status = .failed
                job.completedAt = Date()
                job.metrics.error = error.localizedDescription
            }
        }
    }

    nonisolated private func submitFineTuningJob(_: TrainingJob) async throws -> String {
        // In production, submit to actual fine-tuning API
        // For OpenAI: POST https://api.openai.com/v1/fine_tuning/jobs
        // For Anthropic: When available

        // Simulate API call
        try await Task.sleep(nanoseconds: 2_000_000_000)

        return "ft-\(UUID().uuidString.prefix(8))"
    }

    nonisolated private func waitForCompletion(_ job: TrainingJob, modelId _: String) async throws {
        // Poll for completion (in production, query actual API)
        var completed = false
        var iterations = 0

        while !completed, iterations < 100 {
            try await Task.sleep(nanoseconds: 1_000_000_000)

            // Simulate progress
            iterations += 1
            let progress = Float(iterations) / 100.0

            await MainActor.run {
                job.metrics.progress = Float(progress)
                job.metrics.trainingLoss = 2.5 * (1.0 - Double(progress)) + 0.5
                job.metrics.validationLoss = 2.7 * (1.0 - Double(progress)) + 0.6
            }

            if iterations >= 50 { // Simulate completion
                completed = true
            }
        }
    }

    nonisolated private func prepareTrainingFile(_ examples: [TrainingExample]) async throws -> String {
        // Convert to JSONL format
        var lines: [String] = []

        for example in examples {
            let json: [String: Any] = [
                "messages": [
                    ["role": "user", "content": example.input],
                    ["role": "assistant", "content": example.output]
                ]
            ]

            if let data = try? JSONSerialization.data(withJSONObject: json),
               let jsonString = String(data: data, encoding: .utf8)
            {
                lines.append(jsonString)
            }
        }

        let content = lines.joined(separator: "\n")

        // Write to temporary file
        let tempDir = FileManager.default.temporaryDirectory
        let filename = "training_\(UUID().uuidString).jsonl"
        let fileURL = tempDir.appendingPathComponent(filename)

        try content.write(to: fileURL, atomically: true, encoding: .utf8)

        return fileURL.path
    }

    // MARK: - Few-Shot Learning

    func addTrainingFewShotExample(
        category: String,
        input: String,
        output: String,
        explanation: String = ""
    ) -> TrainingFewShotExample {
        let example = TrainingFewShotExample(
            id: UUID(),
            category: category,
            input: input,
            output: output,
            explanation: explanation,
            createdAt: Date(),
            useCount: 0
        )

        fewShotExamples.append(example)

        return example
    }

    func getCodeFewShotExamples(
        for category: String,
        limit: Int = 5
    ) -> [TrainingFewShotExample] {
        let filtered = fewShotExamples.filter { $0.category == category }

        // Sort by relevance and use count
        let sorted = filtered.sorted { lhs, rhs in
            // Prefer examples with lower use count (ensure diversity)
            if lhs.useCount != rhs.useCount {
                return lhs.useCount < rhs.useCount
            }
            // Then by recency
            return lhs.createdAt > rhs.createdAt
        }

        return Array(sorted.prefix(limit))
    }

    func buildFewShotPrompt(
        for task: String,
        category: String,
        examples: [TrainingFewShotExample]? = nil
    ) -> String {
        let selectedExamples = examples ?? getCodeFewShotExamples(for: category)

        var prompt = "Here are some examples:\n\n"

        for (index, example) in selectedExamples.enumerated() {
            prompt += "Example \(index + 1):\n"
            prompt += "Input: \(example.input)\n"
            prompt += "Output: \(example.output)\n"

            if !example.explanation.isEmpty {
                prompt += "Explanation: \(example.explanation)\n"
            }

            prompt += "\n"

            // Increment use count
            example.useCount += 1
        }

        prompt += "Now, for the following:\n"
        prompt += "Input: \(task)\n"
        prompt += "Output:"

        return prompt
    }

    // MARK: - Prompt Optimization

    func optimizePrompt(
        _ prompt: String,
        testCases: [PromptTestCase],
        iterations: Int = 10
    ) async throws -> PromptOptimizationResult {
        var bestPrompt = prompt
        var bestScore = 0.0
        var variations: [String] = []

        for iteration in 0 ..< iterations {
            // Generate variations
            let variation = try await generatePromptVariation(bestPrompt, iteration: iteration)
            variations.append(variation)

            // Evaluate variation
            let score = try await evaluatePrompt(variation, testCases: testCases)

            if score > bestScore {
                bestScore = score
                bestPrompt = variation
            }
        }

        return PromptOptimizationResult(
            originalPrompt: prompt,
            optimizedPrompt: bestPrompt,
            score: bestScore,
            variations: variations,
            improvementPercentage: ((bestScore - 0.5) / 0.5) * 100
        )
    }

    nonisolated private func generatePromptVariation(
        _ prompt: String,
        iteration _: Int
    ) async throws -> String {
        let provider = await ProviderRegistry.shared.getProvider(id: SettingsManager.shared.defaultProvider)!

        let optimizationPrompt = """
        Improve this prompt to be more effective. Make it more clear, specific, and actionable.
        Keep the core intent but enhance the phrasing.

        Original prompt:
        \(prompt)

        Return only the improved prompt, no explanation.
        """

        let message = AIMessage(
            id: UUID(),
            conversationID: UUID(),
            role: .user,
            content: .text(optimizationPrompt),
            timestamp: Date(),
            model: "gpt-4o-mini"
        )

        var result = ""
        let stream = try await provider.chat(messages: [message], model: "gpt-4o-mini", stream: true)

        for try await chunk in stream {
            switch chunk.type {
            case let .delta(text):
                result += text
            case .complete:
                break
            case let .error(error):
                throw error
            }
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated private func evaluatePrompt(
        _ prompt: String,
        testCases: [PromptTestCase]
    ) async throws -> Double {
        var totalScore = 0.0

        for testCase in testCases {
            let fullPrompt = prompt.replacingOccurrences(of: "{input}", with: testCase.input)

            let provider = await ProviderRegistry.shared.getProvider(id: SettingsManager.shared.defaultProvider)!
            let message = AIMessage(
                id: UUID(),
                conversationID: UUID(),
                role: .user,
                content: .text(fullPrompt),
                timestamp: Date(),
                model: "gpt-4o-mini"
            )

            var response = ""
            let stream = try await provider.chat(messages: [message], model: "gpt-4o-mini", stream: true)

            for try await chunk in stream {
                switch chunk.type {
                case let .delta(text):
                    response += text
                case .complete:
                    break
                case .error:
                    continue
                }
            }

            // Score based on similarity to expected output
            let score = calculateSimilarity(response, testCase.expectedOutput)
            totalScore += score
        }

        return testCases.isEmpty ? 0 : totalScore / Double(testCases.count)
    }

    nonisolated private func calculateSimilarity(_ text1: String, _ text2: String) -> Double {
        let words1 = Set(text1.lowercased().components(separatedBy: .whitespacesAndNewlines))
        let words2 = Set(text2.lowercased().components(separatedBy: .whitespacesAndNewlines))

        let intersection = words1.intersection(words2).count
        let union = words1.union(words2).count

        return union > 0 ? Double(intersection) / Double(union) : 0
    }

    // MARK: - Continual Learning

    func learnFromConversation(_ messages: [AIMessage]) async {
        // Extract valuable patterns from conversation
        var examples: [TrainingExample] = []

        for i in 0 ..< messages.count - 1 {
            if messages[i].role == .user, messages[i + 1].role == .assistant {
                let input = messages[i].content.textValue
                let output = messages[i + 1].content.textValue

                if !input.isEmpty, !output.isEmpty {
                    examples.append(TrainingExample(
                        input: input,
                        output: output,
                        metadata: ["conversation_id": messages[i].conversationID.uuidString]
                    ))
                }
            }
        }

        // Store for future fine-tuning
        // In production, batch these and periodically trigger fine-tuning
        for example in examples {
            // Add to training data pool
            // This would integrate with a data collection system
            _ = example
        }
    }

    func analyzePerformance(
        modelId: String,
        conversations: [UUID]
    ) async throws -> PerformanceAnalysis {
        // Analyze model performance across conversations
        // In production, gather metrics from actual usage

        PerformanceAnalysis(
            modelId: modelId,
            totalConversations: conversations.count,
            averageResponseQuality: 0.85,
            commonPatterns: ["helpful", "detailed", "accurate"],
            improvementAreas: ["conciseness", "code examples"],
            suggestedTrainingData: []
        )
    }

    // MARK: - Prompt Templates

    func createPromptTemplate(
        name: String,
        category: String,
        template: String,
        variables: [String]
    ) -> TrainingPromptTemplate {
        let promptTemplate = TrainingPromptTemplate(
            id: UUID(),
            name: name,
            category: category,
            template: template,
            variables: variables,
            createdAt: Date(),
            useCount: 0
        )

        promptTemplates.append(promptTemplate)

        return promptTemplate
    }

    func renderTemplate(
        _ templateId: UUID,
        values: [String: String]
    ) throws -> String {
        guard let template = promptTemplates.first(where: { $0.id == templateId }) else {
            throw TrainingError.templateNotFound
        }

        var rendered = template.template

        for variable in template.variables {
            guard let value = values[variable] else {
                throw TrainingError.missingVariable(variable)
            }

            rendered = rendered.replacingOccurrences(of: "{\(variable)}", with: value)
        }

        template.useCount += 1

        return rendered
    }

    private func initializePromptTemplates() {
        // System message templates
        _ = createPromptTemplate(
            name: "Code Assistant",
            category: "system",
            template: """
            You are a helpful coding assistant. You provide clear, concise code examples in {language}.
            Focus on best practices and {style} code style.
            """,
            variables: ["language", "style"]
        )

        _ = createPromptTemplate(
            name: "Creative Writer",
            category: "system",
            template: """
            You are a creative writing assistant. Your writing style is {tone} and {genre}.
            Generate engaging content that {purpose}.
            """,
            variables: ["tone", "genre", "purpose"]
        )

        _ = createPromptTemplate(
            name: "Data Analyst",
            category: "system",
            template: """
            You are a data analysis expert. Analyze {data_type} data and provide insights about {focus}.
            Use {visualization_type} visualizations when helpful.
            """,
            variables: ["data_type", "focus", "visualization_type"]
        )

        // Task templates
        _ = createPromptTemplate(
            name: "Summarization",
            category: "task",
            template: """
            Summarize the following text in {length}. Focus on {aspects}.

            Text: {text}
            """,
            variables: ["length", "aspects", "text"]
        )

        _ = createPromptTemplate(
            name: "Code Review",
            category: "task",
            template: """
            Review this {language} code for {focus}. Provide specific suggestions.

            Code:
            {code}
            """,
            variables: ["language", "focus", "code"]
        )
    }
}

// MARK: - Models

class TrainingJob: Identifiable, @unchecked Sendable {
    let id: UUID
    let provider: String
    let baseModel: String
    var status: JobStatus
    let trainingFile: String
    let config: FineTuningConfig
    let createdAt: Date
    var startedAt: Date?
    var completedAt: Date?
    var fineTunedModel: String?
    var metrics: TrainingMetrics

    enum JobStatus {
        case pending, training, completed, failed, cancelled
    }

    init(id: UUID, provider: String, baseModel: String, status: JobStatus, trainingFile: String, config: FineTuningConfig, createdAt: Date, startedAt: Date?, completedAt: Date?, fineTunedModel: String?, metrics: TrainingMetrics) {
        self.id = id
        self.provider = provider
        self.baseModel = baseModel
        self.status = status
        self.trainingFile = trainingFile
        self.config = config
        self.createdAt = createdAt
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.fineTunedModel = fineTunedModel
        self.metrics = metrics
    }
}

struct FineTuningConfig {
    var epochs: Int = 3
    var learningRate: Double = 0.0001
    var batchSize: Int = 4
    var validationSplit: Double = 0.1
}

class TrainingMetrics {
    var progress: Float = 0
    var trainingLoss: Double = 0
    var validationLoss: Double = 0
    var error: String?
}

struct TrainingExample {
    let input: String
    let output: String
    let metadata: [String: String]
}

struct FineTunedModel: Identifiable {
    let id: UUID
    let name: String
    let baseModel: String
    let provider: String
    let modelId: String
    let trainingJobId: UUID
    let createdAt: Date
    let metrics: TrainingMetrics
}

class TrainingFewShotExample: Identifiable {
    let id: UUID
    let category: String
    let input: String
    let output: String
    let explanation: String
    let createdAt: Date
    var useCount: Int

    init(id: UUID, category: String, input: String, output: String, explanation: String, createdAt: Date, useCount: Int) {
        self.id = id
        self.category = category
        self.input = input
        self.output = output
        self.explanation = explanation
        self.createdAt = createdAt
        self.useCount = useCount
    }
}

class TrainingPromptTemplate: Identifiable {
    let id: UUID
    let name: String
    let category: String
    let template: String
    let variables: [String]
    let createdAt: Date
    var useCount: Int

    init(id: UUID, name: String, category: String, template: String, variables: [String], createdAt: Date, useCount: Int) {
        self.id = id
        self.name = name
        self.category = category
        self.template = template
        self.variables = variables
        self.createdAt = createdAt
        self.useCount = useCount
    }
}

struct PromptTestCase {
    let input: String
    let expectedOutput: String
}

struct PromptOptimizationResult {
    let originalPrompt: String
    let optimizedPrompt: String
    let score: Double
    let variations: [String]
    let improvementPercentage: Double
}

struct PerformanceAnalysis {
    let modelId: String
    let totalConversations: Int
    let averageResponseQuality: Double
    let commonPatterns: [String]
    let improvementAreas: [String]
    let suggestedTrainingData: [TrainingExample]
}

enum TrainingError: LocalizedError {
    case insufficientData
    case templateNotFound
    case missingVariable(String)
    case trainingFailed

    var errorDescription: String? {
        switch self {
        case .insufficientData:
            "Insufficient training data"
        case .templateNotFound:
            "Prompt template not found"
        case let .missingVariable(variable):
            "Missing template variable: \(variable)"
        case .trainingFailed:
            "Training job failed"
        }
    }
}
