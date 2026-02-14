// CodebaseSearchEngine.swift
// Thea V2
//
// High-performance semantic search engine for codebase queries
// Optimized for M3 Ultra with SIMD vector operations

import Foundation
import OSLog
import Accelerate

// MARK: - Search Query

/// A search query with options
public struct CodeSearchQuery: Sendable {
    public let text: String
    public var filters: SearchFilters
    public var options: SearchOptions

    public init(
        text: String,
        filters: SearchFilters = SearchFilters(),
        options: SearchOptions = SearchOptions()
    ) {
        self.text = text
        self.filters = filters
        self.options = options
    }
}

/// Filters for search results
public struct SearchFilters: Sendable {
    public var languages: Set<ProgrammingLanguage>?
    public var chunkTypes: Set<ChunkType>?
    public var filePaths: [String]?
    public var excludePaths: [String]?
    public var symbolKinds: Set<SymbolKind>?
    public var visibility: Set<SymbolVisibility>?
    public var minLines: Int?
    public var maxLines: Int?

    public init(
        languages: Set<ProgrammingLanguage>? = nil,
        chunkTypes: Set<ChunkType>? = nil,
        filePaths: [String]? = nil,
        excludePaths: [String]? = nil,
        symbolKinds: Set<SymbolKind>? = nil,
        visibility: Set<SymbolVisibility>? = nil,
        minLines: Int? = nil,
        maxLines: Int? = nil
    ) {
        self.languages = languages
        self.chunkTypes = chunkTypes
        self.filePaths = filePaths
        self.excludePaths = excludePaths
        self.symbolKinds = symbolKinds
        self.visibility = visibility
        self.minLines = minLines
        self.maxLines = maxLines
    }
}

/// Options for search behavior
public struct SearchOptions: Sendable {
    public var limit: Int = 20
    public var offset: Int = 0
    public var includeSnippets: Bool = true
    public var snippetContextLines: Int = 3
    public var boostExactMatch: Float = 2.0
    public var boostSymbolMatch: Float = 1.5
    public var boostRecentFiles: Bool = true
    public var sortBy: SortOrder = .relevance

    public enum SortOrder: String, Sendable {
        case relevance
        case filePath
        case lineNumber
        case recentlyModified
    }

    public init() {}
}

// MARK: - Search Result

/// Detailed search result with context
public struct CodeSearchResult: Identifiable, Sendable {
    public let id: UUID
    public let chunk: CodeChunk
    public let symbol: SymbolNode?
    public let score: Float
    public let matchType: MatchType
    public let highlights: [TextHighlight]
    public let snippet: String?
    public let contextBefore: String?
    public let contextAfter: String?

    public enum MatchType: String, Sendable {
        case semantic           // Vector similarity match
        case exactText          // Exact text match
        case symbolName         // Symbol name match
        case fuzzy              // Fuzzy/partial match
        case regex              // Regex pattern match
    }

    public init(
        id: UUID,
        chunk: CodeChunk,
        symbol: SymbolNode? = nil,
        score: Float,
        matchType: MatchType,
        highlights: [TextHighlight] = [],
        snippet: String? = nil,
        contextBefore: String? = nil,
        contextAfter: String? = nil
    ) {
        self.id = id
        self.chunk = chunk
        self.symbol = symbol
        self.score = score
        self.matchType = matchType
        self.highlights = highlights
        self.snippet = snippet
        self.contextBefore = contextBefore
        self.contextAfter = contextAfter
    }
}

/// Text highlight range
public struct TextHighlight: Sendable {
    public let range: Range<Int>
    public let term: String
}

// MARK: - Codebase Search Engine

/// High-performance search engine for codebase queries
/// Uses SIMD operations for vector similarity when embeddings are available
@MainActor
public final class CodebaseSearchEngine: ObservableObject {

    // MARK: - Singleton

    public static let shared = CodebaseSearchEngine()

    // MARK: - Properties

    private let logger = Logger(subsystem: "com.thea.v2", category: "CodebaseSearchEngine")

    /// Reference to the semantic indexer
    private weak var indexer: SemanticCodeIndexer?

    /// Reference to the symbol graph
    private weak var symbolGraph: SymbolGraph?

    /// Search history for relevance learning
    private var searchHistory: [SearchHistoryEntry] = []

    /// Recent file access for boosting
    private var recentFileAccess: [String: Date] = [:]

    /// Search state
    @Published public private(set) var isSearching: Bool = false
    @Published public private(set) var lastSearchDuration: TimeInterval = 0

    // MARK: - Initialization

    private init() {
        logger.info("CodebaseSearchEngine initialized")
    }

    /// Configure the search engine with required dependencies
    public func configure(indexer: SemanticCodeIndexer, symbolGraph: SymbolGraph) {
        self.indexer = indexer
        self.symbolGraph = symbolGraph
        logger.info("CodebaseSearchEngine configured with indexer and symbol graph")
    }

    // MARK: - Search API

    /// Perform a semantic search across the codebase
    public func search(_ query: CodeSearchQuery) async -> [CodeSearchResult] {
        isSearching = true
        let startTime = Date()

        defer {
            isSearching = false
            lastSearchDuration = Date().timeIntervalSince(startTime)
        }

        guard let indexer = indexer else {
            logger.warning("Search attempted without configured indexer")
            return []
        }

        // Parse query for special operators
        let parsedQuery = parseQuery(query.text)

        // Perform multi-strategy search
        var results: [CodeSearchResult] = []

        // 1. Symbol search (fastest, most precise)
        if let symbolGraph = symbolGraph {
            let symbolResults = searchSymbols(
                query: parsedQuery,
                graph: symbolGraph,
                filters: query.filters
            )
            results.append(contentsOf: symbolResults)
        }

        // 2. Text search with filters
        let textResults = await searchText(
            query: parsedQuery,
            indexer: indexer,
            filters: query.filters,
            options: query.options
        )
        results.append(contentsOf: textResults)

        // 3. Semantic search (if embeddings available)
        // TODO: Implement when embedding model is integrated
        // let semanticResults = await searchSemantic(query: parsedQuery, indexer: indexer)
        // results.append(contentsOf: semanticResults)

        // Deduplicate and merge scores
        results = deduplicateResults(results)

        // Apply filters
        results = applyFilters(results, filters: query.filters)

        // Apply boosting
        results = applyBoosting(results, options: query.options)

        // Sort
        results = sortResults(results, by: query.options.sortBy)

        // Apply pagination
        let start = query.options.offset
        let end = min(start + query.options.limit, results.count)
        if start < results.count {
            results = Array(results[start..<end])
        } else {
            results = []
        }

        // Record search for learning
        recordSearch(query: query.text, resultCount: results.count)

        logger.debug("Search completed: \(results.count) results in \(self.lastSearchDuration)s")
        return results
    }

    /// Quick symbol lookup
    public func lookupSymbol(name: String) -> [SymbolNode] {
        guard let symbolGraph = symbolGraph else { return [] }
        return symbolGraph.searchNodes(pattern: name, limit: 20)
    }

    /// Find definition of a symbol
    public func findDefinition(symbolName: String) -> SymbolNode? {
        guard let symbolGraph = symbolGraph else { return nil }
        return symbolGraph.findNodes(named: symbolName).first
    }

    /// Find all references to a symbol
    public func findReferences(symbolName: String) -> [(SymbolNode, SymbolEdge)] {
        guard let symbolGraph = symbolGraph else { return [] }

        let nodes = symbolGraph.findNodes(named: symbolName)
        guard let node = nodes.first else { return [] }

        return symbolGraph.findAllReferences(to: node.id)
    }

    /// Get file outline (symbols in a file)
    public func getFileOutline(filePath: String) -> [SymbolNode] {
        guard let symbolGraph = symbolGraph else { return [] }
        return symbolGraph.getNodes(inFile: filePath)
    }

    /// Record file access for relevance boosting
    public func recordFileAccess(_ filePath: String) {
        recentFileAccess[filePath] = Date()

        // Keep only recent entries
        let cutoff = Date().addingTimeInterval(-3600 * 24) // 24 hours
        recentFileAccess = recentFileAccess.filter { $0.value > cutoff }
    }

    // MARK: - Private Methods

    private func parseQuery(_ text: String) -> ParsedQuery {
        var terms: [String] = []
        var exactPhrases: [String] = []
        var excludeTerms: [String] = []
        var filePatterns: [String] = []
        var symbolPatterns: [String] = []

        // Extract quoted phrases
        let quoteRegex = try? NSRegularExpression(pattern: "\"([^\"]+)\"", options: [])
        let range = NSRange(text.startIndex..., in: text)
        var remainingText = text

        if let regex = quoteRegex {
            let matches = regex.matches(in: text, options: [], range: range)
            for match in matches.reversed() {
                if let phraseRange = Range(match.range(at: 1), in: text) {
                    exactPhrases.append(String(text[phraseRange]))
                }
                if let fullRange = Range(match.range, in: text) {
                    remainingText = remainingText.replacingCharacters(in: fullRange, with: "")
                }
            }
        }

        // Parse remaining terms
        let words = remainingText.components(separatedBy: .whitespaces).filter { !$0.isEmpty }

        for word in words {
            if word.hasPrefix("-") {
                excludeTerms.append(String(word.dropFirst()))
            } else if word.hasPrefix("file:") {
                filePatterns.append(String(word.dropFirst(5)))
            } else if word.hasPrefix("symbol:") || word.hasPrefix("@") {
                let pattern = word.hasPrefix("@") ? String(word.dropFirst()) : String(word.dropFirst(7))
                symbolPatterns.append(pattern)
            } else {
                terms.append(word)
            }
        }

        return ParsedQuery(
            terms: terms,
            exactPhrases: exactPhrases,
            excludeTerms: excludeTerms,
            filePatterns: filePatterns,
            symbolPatterns: symbolPatterns
        )
    }

    private func searchSymbols(
        query: ParsedQuery,
        graph: SymbolGraph,
        filters: SearchFilters
    ) -> [CodeSearchResult] {
        var results: [CodeSearchResult] = []

        // Search by symbol patterns first
        for pattern in query.symbolPatterns {
            let nodes = graph.searchNodes(pattern: pattern, kinds: filters.symbolKinds.map { Array($0) }, limit: 50)
            for node in nodes {
                let result = CodeSearchResult(
                    id: UUID(),
                    chunk: createChunkFromSymbol(node),
                    symbol: node,
                    score: 10.0, // High score for direct symbol match
                    matchType: .symbolName,
                    highlights: [],
                    snippet: node.signature,
                    contextBefore: nil,
                    contextAfter: nil
                )
                results.append(result)
            }
        }

        // Also search regular terms as potential symbols
        for term in query.terms {
            let nodes = graph.searchNodes(pattern: term, kinds: filters.symbolKinds.map { Array($0) }, limit: 20)
            for node in nodes {
                // Check if already added
                if results.contains(where: { $0.symbol?.id == node.id }) {
                    continue
                }

                let score: Float = node.name.lowercased() == term.lowercased() ? 8.0 : 5.0
                let result = CodeSearchResult(
                    id: UUID(),
                    chunk: createChunkFromSymbol(node),
                    symbol: node,
                    score: score,
                    matchType: .symbolName,
                    highlights: [],
                    snippet: node.signature,
                    contextBefore: nil,
                    contextAfter: nil
                )
                results.append(result)
            }
        }

        return results
    }

    private func searchText(
        query: ParsedQuery,
        indexer: SemanticCodeIndexer,
        filters: SearchFilters,
        options: SearchOptions
    ) async -> [CodeSearchResult] {
        // Use the indexer's text search
        let searchTerms = (query.terms + query.exactPhrases).joined(separator: " ")
        guard !searchTerms.isEmpty else { return [] }

        let indexerResults = await indexer.search(query: searchTerms, limit: options.limit * 2)

        return indexerResults.map { result in
            let highlights = findHighlights(in: result.chunk.content, terms: query.terms + query.exactPhrases)

            return CodeSearchResult(
                id: result.id,
                chunk: result.chunk,
                symbol: nil,
                score: result.score,
                matchType: .exactText,
                highlights: highlights,
                snippet: generateSnippet(
                    content: result.chunk.content,
                    highlights: highlights,
                    contextLines: options.snippetContextLines
                ),
                contextBefore: nil,
                contextAfter: nil
            )
        }
    }

    private func findHighlights(in content: String, terms: [String]) -> [TextHighlight] {
        var highlights: [TextHighlight] = []
        let contentLower = content.lowercased()

        for term in terms {
            let termLower = term.lowercased()
            var searchStart = contentLower.startIndex

            while let range = contentLower.range(of: termLower, range: searchStart..<contentLower.endIndex) {
                let startOffset = contentLower.distance(from: contentLower.startIndex, to: range.lowerBound)
                let endOffset = contentLower.distance(from: contentLower.startIndex, to: range.upperBound)

                highlights.append(TextHighlight(
                    range: startOffset..<endOffset,
                    term: term
                ))

                searchStart = range.upperBound
            }
        }

        return highlights.sorted { $0.range.lowerBound < $1.range.lowerBound }
    }

    private func generateSnippet(content: String, highlights: [TextHighlight], contextLines: Int) -> String {
        guard let firstHighlight = highlights.first else {
            // Return first few lines if no highlights
            let lines = content.components(separatedBy: .newlines)
            return lines.prefix(contextLines * 2).joined(separator: "\n")
        }

        let lines = content.components(separatedBy: .newlines)
        var currentPos = 0
        var highlightLine = 0

        // Find which line contains the first highlight
        for (index, line) in lines.enumerated() {
            let lineEnd = currentPos + line.count + 1
            if firstHighlight.range.lowerBound < lineEnd {
                highlightLine = index
                break
            }
            currentPos = lineEnd
        }

        // Extract context around the highlight
        let startLine = max(0, highlightLine - contextLines)
        let endLine = min(lines.count, highlightLine + contextLines + 1)

        return lines[startLine..<endLine].joined(separator: "\n")
    }

    private func createChunkFromSymbol(_ symbol: SymbolNode) -> CodeChunk {
        CodeChunk(
            id: UUID(),
            filePath: symbol.filePath,
            relativePath: symbol.filePath,
            content: symbol.signature ?? symbol.name,
            startLine: symbol.line,
            endLine: symbol.line,
            chunkType: mapSymbolKindToChunkType(symbol.kind),
            language: symbol.language,
            metadata: ChunkMetadata(
                symbolName: symbol.name,
                visibility: symbol.visibility.displayName,
                documentation: symbol.documentation
            )
        )
    }

    private func mapSymbolKindToChunkType(_ kind: SymbolKind) -> ChunkType {
        switch kind {
        case .function, .method: return .function
        case .class_: return .classDefinition
        case .struct_: return .structDefinition
        case .enum_: return .enumDefinition
        case .protocol_, .interface, .trait: return .protocolDefinition
        case .extension_: return .extensionDefinition
        case .property, .variable, .constant: return .property
        case .import_: return .import_
        default: return .unknown
        }
    }

    private func deduplicateResults(_ results: [CodeSearchResult]) -> [CodeSearchResult] {
        var seen: Set<String> = []
        var unique: [CodeSearchResult] = []

        for result in results {
            let key = "\(result.chunk.filePath):\(result.chunk.startLine)"
            if !seen.contains(key) {
                seen.insert(key)
                unique.append(result)
            }
        }

        return unique
    }

    private func applyFilters(_ results: [CodeSearchResult], filters: SearchFilters) -> [CodeSearchResult] {
        results.filter { result in
            // Language filter
            if let languages = filters.languages, !languages.contains(result.chunk.language) {
                return false
            }

            // Chunk type filter
            if let types = filters.chunkTypes, !types.contains(result.chunk.chunkType) {
                return false
            }

            // File path include filter
            if let paths = filters.filePaths {
                let matchesAny = paths.contains { result.chunk.filePath.contains($0) }
                if !matchesAny { return false }
            }

            // File path exclude filter
            if let excludes = filters.excludePaths {
                let matchesAny = excludes.contains { result.chunk.filePath.contains($0) }
                if matchesAny { return false }
            }

            // Line count filters
            let lineCount = result.chunk.endLine - result.chunk.startLine + 1
            if let minLines = filters.minLines, lineCount < minLines { return false }
            if let maxLines = filters.maxLines, lineCount > maxLines { return false }

            return true
        }
    }

    private func applyBoosting(_ results: [CodeSearchResult], options: SearchOptions) -> [CodeSearchResult] {
        results.map { result in
            var boostedScore = result.score

            // Boost exact matches
            if result.matchType == .exactText || result.matchType == .symbolName {
                boostedScore *= options.boostExactMatch
            }

            // Boost symbol matches
            if result.symbol != nil {
                boostedScore *= options.boostSymbolMatch
            }

            // Boost recently accessed files
            if options.boostRecentFiles, let lastAccess = recentFileAccess[result.chunk.filePath] {
                let hoursSinceAccess = Date().timeIntervalSince(lastAccess) / 3600
                if hoursSinceAccess < 1 {
                    boostedScore *= 1.5
                } else if hoursSinceAccess < 24 {
                    boostedScore *= 1.2
                }
            }

            return CodeSearchResult(
                id: result.id,
                chunk: result.chunk,
                symbol: result.symbol,
                score: boostedScore,
                matchType: result.matchType,
                highlights: result.highlights,
                snippet: result.snippet,
                contextBefore: result.contextBefore,
                contextAfter: result.contextAfter
            )
        }
    }

    private func sortResults(_ results: [CodeSearchResult], by order: SearchOptions.SortOrder) -> [CodeSearchResult] {
        switch order {
        case .relevance:
            return results.sorted { $0.score > $1.score }
        case .filePath:
            return results.sorted { $0.chunk.filePath < $1.chunk.filePath }
        case .lineNumber:
            return results.sorted {
                if $0.chunk.filePath == $1.chunk.filePath {
                    return $0.chunk.startLine < $1.chunk.startLine
                }
                return $0.chunk.filePath < $1.chunk.filePath
            }
        case .recentlyModified:
            return results.sorted { $0.chunk.updatedAt > $1.chunk.updatedAt }
        }
    }

    private func recordSearch(query: String, resultCount: Int) {
        let entry = SearchHistoryEntry(
            query: query,
            timestamp: Date(),
            resultCount: resultCount
        )
        searchHistory.append(entry)

        // Keep only recent history
        if searchHistory.count > 1000 {
            searchHistory = Array(searchHistory.suffix(500))
        }
    }
}

