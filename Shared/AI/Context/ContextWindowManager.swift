//
//  ContextWindowManager.swift
//  Thea
//
//  Context window management with smart compression
//  Manages token budgets, priority-based retention, and overflow handling
//  Inspired by Cursor's context management system
//

import Foundation
import os.log

// MARK: - Context Entry

/// A single entry in the context window
public struct WindowContextEntry: Identifiable, Codable, Sendable {
    public let id: UUID
    public let content: String
    public let source: WindowContextSource
    public let priority: ContextPriority
    public let tokenCount: Int
    public let timestamp: Date
    public var isCompressed: Bool
    public var compressedContent: String?

    public init(
        id: UUID = UUID(),
        content: String,
        source: WindowContextSource,
        priority: ContextPriority = .normal,
        tokenCount: Int? = nil,
        timestamp: Date = Date(),
        isCompressed: Bool = false,
        compressedContent: String? = nil
    ) {
        self.id = id
        self.content = content
        self.source = source
        self.priority = priority
        self.tokenCount = tokenCount ?? Self.estimateTokens(content)
        self.timestamp = timestamp
        self.isCompressed = isCompressed
        self.compressedContent = compressedContent
    }

    /// Estimate token count for content (rough approximation)
    public static func estimateTokens(_ content: String) -> Int {
        // Rough estimate: ~4 characters per token for English text
        // Code tends to be denser, ~3 characters per token
        max(1, content.count / 4)
    }

    /// Get the effective content (compressed if available)
    public var effectiveContent: String {
        compressedContent ?? content
    }

    /// Get the effective token count
    public var effectiveTokenCount: Int {
        if let compressed = compressedContent {
            return Self.estimateTokens(compressed)
        }
        return tokenCount
    }
}

/// Sources of context
public enum WindowContextSource: String, Codable, Sendable {
    case userMessage
    case assistantMessage
    case systemPrompt
    case codeFile
    case codeSnippet
    case documentation
    case searchResult
    case webContent
    case memory
    case action
    case tool
    case error
}

/// Priority levels for context retention
public enum ContextPriority: Int, Codable, Sendable, Comparable {
    case critical = 100   // Never remove (system prompts, current query)
    case high = 75        // Recent messages, active code
    case normal = 50      // Standard context
    case low = 25         // Background information
    case minimal = 10     // Can be dropped first

    public static func < (lhs: ContextPriority, rhs: ContextPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Context Window Configuration

/// Configuration for context window management
public struct ContextWindowConfig: Codable, Sendable {
    public var maxTokens: Int
    public var reservedForResponse: Int
    public var compressionThreshold: Double  // Start compressing at this % of max
    public var minEntriesToKeep: Int
    public var preferLocalCompression: Bool

    public init(
        maxTokens: Int = 128_000,
        reservedForResponse: Int = 4_096,
        compressionThreshold: Double = 0.7,
        minEntriesToKeep: Int = 5,
        preferLocalCompression: Bool = true
    ) {
        self.maxTokens = maxTokens
        self.reservedForResponse = reservedForResponse
        self.compressionThreshold = compressionThreshold
        self.minEntriesToKeep = minEntriesToKeep
        self.preferLocalCompression = preferLocalCompression
    }

    /// Effective tokens available for context
    public var availableTokens: Int {
        maxTokens - reservedForResponse
    }

    /// Token count to start compression
    public var compressionStartTokens: Int {
        Int(Double(availableTokens) * compressionThreshold)
    }

    // Common configurations
    public static let gpt4 = ContextWindowConfig(maxTokens: 128_000, reservedForResponse: 4_096)
    public static let gpt4Mini = ContextWindowConfig(maxTokens: 128_000, reservedForResponse: 4_096)
    public static let claude3 = ContextWindowConfig(maxTokens: 200_000, reservedForResponse: 8_192)
    public static let claudeSonnet = ContextWindowConfig(maxTokens: 200_000, reservedForResponse: 8_192)
    public static let local = ContextWindowConfig(maxTokens: 32_000, reservedForResponse: 2_048)
}

// MARK: - Context Window Manager

/// Manages context window with smart compression and priority-based retention
public actor ContextWindowManager {
    public static let shared = ContextWindowManager()

    private let logger = Logger(subsystem: "ai.thea.app", category: "ContextWindowManager")

    // MARK: - State

    private var entries: [WindowContextEntry] = []
    private var config: ContextWindowConfig = .claude3
    private var compressionProvider: ContextCompressor?

    // Statistics
    private var totalTokensUsed: Int = 0
    private var compressionsSaved: Int = 0
    private var entriesDropped: Int = 0

    private init() {}

    // MARK: - Configuration

    /// Update the context window configuration
    public func setConfig(_ config: ContextWindowConfig) {
        self.config = config
        logger.info("Updated config: max=\(config.maxTokens), reserved=\(config.reservedForResponse)")
    }

    /// Set a compression provider for AI-powered summarization
    public func setCompressor(_ compressor: ContextCompressor) {
        self.compressionProvider = compressor
        logger.info("Compression provider set")
    }

    // MARK: - Entry Management

    /// Add a context entry
    public func addEntry(_ entry: WindowContextEntry) async {
        entries.append(entry)
        totalTokensUsed += entry.tokenCount

        // Check if we need to compress or drop entries
        await manageCapacity()

        logger.debug("Added entry: \(entry.source.rawValue), tokens=\(entry.tokenCount)")
    }

    /// Add content as a context entry
    public func addContent(
        _ content: String,
        source: WindowContextSource,
        priority: ContextPriority = .normal
    ) async {
        let entry = WindowContextEntry(content: content, source: source, priority: priority)
        await addEntry(entry)
    }

    /// Remove a specific entry
    public func removeEntry(id: UUID) {
        if let index = entries.firstIndex(where: { $0.id == id }) {
            totalTokensUsed -= entries[index].effectiveTokenCount
            entries.remove(at: index)
        }
    }

    /// Clear all entries except critical ones
    public func clearNonCritical() {
        let critical = entries.filter { $0.priority == .critical }
        entries = critical
        totalTokensUsed = critical.reduce(0) { $0 + $1.effectiveTokenCount }
        logger.info("Cleared non-critical entries, keeping \(critical.count)")
    }

    /// Clear all entries
    public func clearAll() {
        entries.removeAll()
        totalTokensUsed = 0
        logger.info("Cleared all context entries")
    }

    // MARK: - Capacity Management

    /// Manage context window capacity
    private func manageCapacity() async {
        let available = config.availableTokens

        // Check if we need to take action
        guard totalTokensUsed > config.compressionStartTokens else {
            return
        }

        logger.debug("Managing capacity: \(self.totalTokensUsed)/\(available) tokens")

        // First, try compression
        if totalTokensUsed > config.compressionStartTokens {
            await compressOldEntries()
        }

        // If still over, drop low-priority entries
        while totalTokensUsed > available && entries.count > config.minEntriesToKeep {
            await dropLowestPriorityEntry()
        }
    }

    /// Compress older entries to save space
    private func compressOldEntries() async {
        // Find entries that can be compressed (not already compressed, not critical)
        let compressibleIndices = entries.enumerated()
            .filter { !$0.element.isCompressed && $0.element.priority != .critical }
            .sorted { $0.element.timestamp < $1.element.timestamp }  // Oldest first
            .prefix(5)  // Compress up to 5 at a time
            .map(\.offset)

        for index in compressibleIndices {
            guard index < entries.count else { continue }

            let originalTokens = entries[index].tokenCount

            // Use AI compression if available, otherwise simple truncation
            if let compressor = compressionProvider {
                if let compressed = await compressor.compress(entries[index].content) {
                    entries[index].compressedContent = compressed
                    entries[index].isCompressed = true

                    let savedTokens = originalTokens - entries[index].effectiveTokenCount
                    totalTokensUsed -= savedTokens
                    compressionsSaved += savedTokens

                    logger.debug("Compressed entry, saved \(savedTokens) tokens")
                }
            } else {
                // Simple truncation as fallback
                let truncated = simpleCompress(entries[index].content)
                entries[index].compressedContent = truncated
                entries[index].isCompressed = true

                let savedTokens = originalTokens - entries[index].effectiveTokenCount
                totalTokensUsed -= savedTokens
                compressionsSaved += savedTokens
            }
        }
    }

    /// Simple compression by keeping first and last parts
    private func simpleCompress(_ content: String, maxLength: Int = 500) -> String {
        guard content.count > maxLength else { return content }

        let halfLength = maxLength / 2
        let prefix = String(content.prefix(halfLength))
        let suffix = String(content.suffix(halfLength))

        return "\(prefix)\n\n[... content truncated ...]\n\n\(suffix)"
    }

    /// Drop the lowest priority entry
    private func dropLowestPriorityEntry() async {
        // Find non-critical entry with lowest priority and oldest timestamp
        let droppable = entries.enumerated()
            .filter { $0.element.priority != .critical }

        let sorted = droppable.sorted { a, b in
            if a.element.priority != b.element.priority {
                return a.element.priority < b.element.priority
            }
            return a.element.timestamp < b.element.timestamp
        }

        guard let toDrop = sorted.first else {
            return
        }

        let dropped = entries.remove(at: toDrop.offset)
        totalTokensUsed -= dropped.effectiveTokenCount
        entriesDropped += 1

        logger.debug("Dropped entry: \(dropped.source.rawValue), priority=\(dropped.priority.rawValue)")
    }

    // MARK: - Build Context

    /// Build the context string for a prompt
    public func buildContext(
        maxTokens: Int? = nil,
        includeSources: Set<WindowContextSource>? = nil
    ) -> String {
        var filteredEntries = entries

        // Filter by source if specified
        if let sources = includeSources {
            filteredEntries = filteredEntries.filter { sources.contains($0.source) }
        }

        // Sort by priority (highest first) then by timestamp (newest first for same priority)
        filteredEntries.sort { a, b in
            if a.priority != b.priority {
                return a.priority > b.priority
            }
            return a.timestamp > b.timestamp
        }

        // Build context up to token limit
        let limit = maxTokens ?? config.availableTokens
        var result: [String] = []
        var currentTokens = 0

        for entry in filteredEntries {
            let content = entry.effectiveContent
            let tokens = entry.effectiveTokenCount

            if currentTokens + tokens <= limit {
                result.append(content)
                currentTokens += tokens
            } else {
                break
            }
        }

        return result.joined(separator: "\n\n")
    }

    /// Build structured context with metadata
    public func buildStructuredContext() -> StructuredContext {
        StructuredContext(
            entries: entries,
            totalTokens: totalTokensUsed,
            maxTokens: config.availableTokens,
            compressionsSaved: compressionsSaved,
            entriesDropped: entriesDropped
        )
    }

    // MARK: - Query Methods

    /// Get current token usage
    public func getTokenUsage() -> (used: Int, available: Int, percent: Double) {
        let available = config.availableTokens
        let percent = Double(totalTokensUsed) / Double(available) * 100
        return (totalTokensUsed, available, percent)
    }

    /// Get entry count
    public func getEntryCount() -> Int {
        entries.count
    }

    /// Get entries by source
    public func getEntries(source: WindowContextSource) -> [WindowContextEntry] {
        entries.filter { $0.source == source }
    }

    /// Get all entries
    public func getAllEntries() -> [WindowContextEntry] {
        entries
    }

    /// Get statistics
    public func getStatistics() -> ContextStatistics {
        ContextStatistics(
            totalEntries: entries.count,
            tokensUsed: totalTokensUsed,
            maxTokens: config.availableTokens,
            compressionsSaved: compressionsSaved,
            entriesDropped: entriesDropped,
            compressedEntries: entries.filter(\.isCompressed).count
        )
    }
}

// MARK: - Supporting Types

/// Structured context with metadata
public struct StructuredContext: Sendable {
    public let entries: [WindowContextEntry]
    public let totalTokens: Int
    public let maxTokens: Int
    public let compressionsSaved: Int
    public let entriesDropped: Int

    public var utilizationPercent: Double {
        Double(totalTokens) / Double(maxTokens) * 100
    }
}

/// Context statistics
public struct ContextStatistics: Sendable {
    public let totalEntries: Int
    public let tokensUsed: Int
    public let maxTokens: Int
    public let compressionsSaved: Int
    public let entriesDropped: Int
    public let compressedEntries: Int

    public var utilizationPercent: Double {
        Double(tokensUsed) / Double(maxTokens) * 100
    }
}

// MARK: - Context Compressor Protocol

/// Protocol for context compression providers
public protocol ContextCompressor: Sendable {
    /// Compress content to a shorter summary
    func compress(_ content: String) async -> String?

    /// Compress multiple pieces of content into one summary
    func compressMultiple(_ contents: [String]) async -> String?
}

// MARK: - Simple Text Compressor

/// Simple text-based compressor (no AI)
public struct SimpleTextCompressor: ContextCompressor {
    public init() {}

    public func compress(_ content: String) async -> String? {
        // Extract key sentences (first, last, and those with keywords)
        let sentences = content.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard sentences.count > 3 else { return content }

        var result: [String] = []

        // Keep first sentence
        result.append(sentences[0])

        // Keep middle sentences that contain important keywords
        let keywords = ["important", "note", "error", "warning", "must", "should", "key", "main"]
        for sentence in sentences[1..<(sentences.count - 1)] {
            let lower = sentence.lowercased()
            if keywords.contains(where: { lower.contains($0) }) {
                result.append(sentence)
            }
        }

        // Keep last sentence
        if sentences.count > 1 {
            result.append(sentences[sentences.count - 1])
        }

        // Limit to reasonable length
        if result.joined().count > content.count / 2 {
            return "\(sentences[0])... [summarized] ...\(sentences[sentences.count - 1])"
        }

        return result.joined(separator: ". ") + "."
    }

    public func compressMultiple(_ contents: [String]) async -> String? {
        var compressed: [String] = []
        for content in contents {
            if let c = await compress(content) {
                compressed.append(c)
            }
        }
        return compressed.joined(separator: "\n\n")
    }
}
