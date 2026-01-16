import Foundation
import OSLog

// MARK: - ErrorKnowledgeBase
// Knowledge base of known error patterns and their fixes

public actor ErrorKnowledgeBase {
    public static let shared = ErrorKnowledgeBase()

    private let logger = Logger(subsystem: "com.thea.metaai", category: "ErrorKnowledgeBase")

    private var knownFixes: [KnownFix]
    private let persistenceURL: URL

    private init() {
        // Set up persistence location
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory

        let theaDir = appSupport.appendingPathComponent("Thea", isDirectory: true)
        self.persistenceURL = theaDir.appendingPathComponent("ErrorKnowledgeBase.json")

        // Try to load existing knowledge base, otherwise use seed data
        if let loaded = Self.loadFromDisk(url: persistenceURL) {
            self.knownFixes = loaded
            logger.info("Loaded \(loaded.count) known fixes from disk")
        } else {
            self.knownFixes = Self.seedData
            logger.info("Initialized with \(Self.seedData.count) seed fixes")
        }
    }

    // MARK: - Public Types

    public struct KnownFix: Sendable, Codable, Identifiable {
        public let id: UUID
        public let errorPattern: String
        public let category: ErrorParser.ErrorCategory
        public let fixStrategy: FixStrategy
        public let fixDescription: String
        public var confidence: Double
        public var successCount: Int
        public var failureCount: Int

        public init(
            errorPattern: String,
            category: ErrorParser.ErrorCategory,
            fixStrategy: FixStrategy,
            fixDescription: String,
            confidence: Double,
            successCount: Int = 0,
            failureCount: Int = 0
        ) {
            self.id = UUID()
            self.errorPattern = errorPattern
            self.category = category
            self.fixStrategy = fixStrategy
            self.fixDescription = fixDescription
            self.confidence = confidence
            self.successCount = successCount
            self.failureCount = failureCount
        }
    }

    public enum FixStrategy: String, Codable, Sendable {
        case addPublicModifier
        case addSendable
        case addMainActor
        case addAsyncAwait
        case fixImport
        case addInitializer
        case addIsolatedAttribute
        case useTaskDetached
        case useAIGeneration
    }

    // MARK: - Find Fixes

    public func findFix(
        forMessage message: String,
        category: ErrorParser.ErrorCategory
    ) async -> KnownFix? {
        // First, try exact category match with pattern matching
        let categoryMatches = knownFixes.filter { $0.category == category }

        for fix in categoryMatches.sorted(by: { $0.confidence > $1.confidence }) {
            if matchesPattern(message: message, pattern: fix.errorPattern) {
                logger.info("Found matching fix: \(fix.fixStrategy.rawValue) (confidence: \(String(format: "%.2f", fix.confidence)))")
                return fix
            }
        }

        // If no exact match, return the highest confidence fix for the category
        let bestCategoryFix = categoryMatches.max(by: { $0.confidence < $1.confidence })
        if let fix = bestCategoryFix {
            logger.info("Using best category fix: \(fix.fixStrategy.rawValue) (confidence: \(String(format: "%.2f", fix.confidence)))")
            return fix
        }

        logger.warning("No fix found for category: \(category.rawValue)")
        return nil
    }

    public func findFix(for error: ErrorParser.ParsedError) async -> KnownFix? {
        return await findFix(forMessage: error.message, category: error.category)
    }

    // MARK: - Pattern Matching

    private func matchesPattern(message: String, pattern: String) -> Bool {
        // Support both regex and simple substring matching
        let lowercasedMessage = message.lowercased()
        let lowercasedPattern = pattern.lowercased()

        // First try simple substring match
        if lowercasedMessage.contains(lowercasedPattern) {
            return true
        }

        // Try regex match
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return false
        }

        let range = NSRange(location: 0, length: message.utf16.count)
        return regex.firstMatch(in: message, range: range) != nil
    }

    // MARK: - Learning

    public func recordResult(fix: KnownFix, success: Bool) async {
        // Find and update the fix in our database
        guard let index = knownFixes.firstIndex(where: { $0.id == fix.id }) else {
            logger.warning("Attempted to record result for unknown fix: \(fix.id)")
            return
        }

        var updatedFix = knownFixes[index]

        if success {
            updatedFix.successCount += 1
        } else {
            updatedFix.failureCount += 1
        }

        // Update confidence based on success rate
        let totalAttempts = updatedFix.successCount + updatedFix.failureCount
        if totalAttempts > 0 {
            let successRate = Double(updatedFix.successCount) / Double(totalAttempts)
            // Blend old confidence with new success rate (weighted average)
            updatedFix.confidence = (updatedFix.confidence * 0.3) + (successRate * 0.7)
        }

        knownFixes[index] = updatedFix

        logger.info("Updated fix \(fix.fixStrategy.rawValue): success=\(updatedFix.successCount), failure=\(updatedFix.failureCount), confidence=\(String(format: "%.2f", updatedFix.confidence))")

        // Persist to disk
        await saveToDisk()
    }

    // MARK: - Add New Fixes

    public func addFix(_ fix: KnownFix) async {
        knownFixes.append(fix)
        logger.info("Added new fix: \(fix.fixStrategy.rawValue)")
        await saveToDisk()
    }

    // MARK: - Statistics

    public func getStatistics() async -> KnowledgeBaseStatistics {
        let totalFixes = knownFixes.count
        let totalSuccesses = knownFixes.reduce(0) { $0 + $1.successCount }
        let totalFailures = knownFixes.reduce(0) { $0 + $1.failureCount }
        let totalAttempts = totalSuccesses + totalFailures

        let avgConfidence = knownFixes.isEmpty ? 0.0 : knownFixes.reduce(0.0) { $0 + $1.confidence } / Double(knownFixes.count)

        var categoryBreakdown: [ErrorParser.ErrorCategory: Int] = [:]
        for fix in knownFixes {
            categoryBreakdown[fix.category, default: 0] += 1
        }

        return KnowledgeBaseStatistics(
            totalFixes: totalFixes,
            totalAttempts: totalAttempts,
            totalSuccesses: totalSuccesses,
            totalFailures: totalFailures,
            averageConfidence: avgConfidence,
            categoryBreakdown: categoryBreakdown
        )
    }

    // MARK: - Persistence

    private func saveToDisk() async {
        do {
            // Create directory if needed
            let directory = persistenceURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

            // Encode and save
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(knownFixes)
            try data.write(to: persistenceURL, options: .atomic)

            logger.info("Saved \(self.knownFixes.count) fixes to disk")
        } catch {
            logger.error("Failed to save knowledge base: \(error.localizedDescription)")
        }
    }

    private nonisolated static func loadFromDisk(url: URL) -> [KnownFix]? {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let fixes = try decoder.decode([KnownFix].self, from: data)
            return fixes
        } catch {
            return nil
        }
    }

    // MARK: - Reset

    public func reset() async {
        knownFixes = Self.seedData
        await saveToDisk()
        logger.info("Reset knowledge base to seed data")
    }
}

// MARK: - Supporting Types

public struct KnowledgeBaseStatistics: Sendable {
    public let totalFixes: Int
    public let totalAttempts: Int
    public let totalSuccesses: Int
    public let totalFailures: Int
    public let averageConfidence: Double
    public let categoryBreakdown: [ErrorParser.ErrorCategory: Int]

    public var successRate: Double {
        guard totalAttempts > 0 else { return 0.0 }
        return Double(totalSuccesses) / Double(totalAttempts)
    }
}

// MARK: - Seed Data

extension ErrorKnowledgeBase {
    /// Known Swift error fixes (seed data)
    nonisolated static let seedData: [ErrorKnowledgeBase.KnownFix] = [
    // Sendable conformance errors
    ErrorKnowledgeBase.KnownFix(
        errorPattern: "non-sendable",
        category: .sendable,
        fixStrategy: .addSendable,
        fixDescription: "Add 'Sendable' conformance to the type",
        confidence: 0.85
    ),
    ErrorKnowledgeBase.KnownFix(
        errorPattern: "cannot be formed from a function type that takes non-sendable",
        category: .sendable,
        fixStrategy: .addSendable,
        fixDescription: "Ensure all closure parameters conform to Sendable",
        confidence: 0.80
    ),
    
    // MainActor errors
    ErrorKnowledgeBase.KnownFix(
        errorPattern: "main actor-isolated",
        category: .mainActor,
        fixStrategy: .addMainActor,
        fixDescription: "Add '@MainActor' attribute to the type or function",
        confidence: 0.90
    ),
    ErrorKnowledgeBase.KnownFix(
        errorPattern: "call to main actor-isolated",
        category: .mainActor,
        fixStrategy: .addAsyncAwait,
        fixDescription: "Use 'await' when calling MainActor-isolated functions",
        confidence: 0.88
    ),
    
    // Visibility errors
    ErrorKnowledgeBase.KnownFix(
        errorPattern: "initializer is inaccessible",
        category: .visibility,
        fixStrategy: .addPublicModifier,
        fixDescription: "Make the initializer public",
        confidence: 0.92
    ),
    ErrorKnowledgeBase.KnownFix(
        errorPattern: "cannot find.*in scope",
        category: .typeNotFound,
        fixStrategy: .fixImport,
        fixDescription: "Add the required import or check type name",
        confidence: 0.75
    ),
    
    // Async/await errors
    ErrorKnowledgeBase.KnownFix(
        errorPattern: "expression is 'async' but is not marked with 'await'",
        category: .asyncAwait,
        fixStrategy: .addAsyncAwait,
        fixDescription: "Add 'await' before the async function call",
        confidence: 0.95
    ),
    
    // Data race / isolation errors
    ErrorKnowledgeBase.KnownFix(
        errorPattern: "actor-isolated property.*cannot be mutated from.*context",
        category: .dataConcurrency,
        fixStrategy: .addIsolatedAttribute,
        fixDescription: "Use 'isolated' parameter or Task to access actor-isolated properties",
        confidence: 0.82
    ),
    ErrorKnowledgeBase.KnownFix(
        errorPattern: "task-isolated value of type.*cannot be passed to.*",
        category: .dataConcurrency,
        fixStrategy: .useTaskDetached,
        fixDescription: "Use Task.detached for unstructured concurrency or ensure proper isolation",
        confidence: 0.78
    )
]
}

