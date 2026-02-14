//
//  DocumentationGrounding.swift
//  Thea
//
//  Documentation Grounding System inspired by Context7
//  Fetches up-to-date library documentation to ground AI responses
//

import Foundation
import OSLog

// MARK: - Documentation Grounding Service

/// Provides up-to-date library documentation for AI responses
/// Inspired by Context7's resolve-library-id and query-docs tools
@MainActor
public final class DocumentationGroundingService: ObservableObject {
    public static let shared = DocumentationGroundingService()

    private let logger = Logger(subsystem: "app.thea", category: "DocumentationGrounding")

    // MARK: - Published State

    @Published public private(set) var isLoading = false
    @Published public private(set) var cachedLibraries: [String: LibraryInfo] = [:]

    // MARK: - Configuration

    private let cacheURL: URL
    private let cacheDuration: TimeInterval = 86400 // 24 hours

    // Context7 API v2 endpoints
    private let context7BaseURL = "https://context7.com"
    private let context7MCPURL = "https://mcp.context7.com/mcp"
    private let searchEndpoint = "/api/v2/libs/search"  // params: query, libraryName
    private let contextEndpoint = "/api/v2/context"      // params: query, libraryId, type (json/txt)

    // MARK: - Initialization

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        cacheURL = appSupport.appendingPathComponent("Thea/docs_cache")

        try? FileManager.default.createDirectory(at: cacheURL, withIntermediateDirectories: true)

        Task {
            await loadCache()
        }
    }

    // MARK: - Resolve Library ID

    /// Resolve a library name to a canonical ID
    /// Similar to Context7's resolve-library-id tool
    public func resolveLibraryId(name: String) async throws -> LibraryInfo? {
        let normalizedName = name.lowercased()
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: " ", with: "-")

        // Check cache first
        if let cached = cachedLibraries[normalizedName] {
            if Date().timeIntervalSince(cached.cachedAt) < cacheDuration {
                return cached
            }
        }

        // Search known libraries
        if let known = knownLibraries[normalizedName] {
            let info = LibraryInfo(
                id: known.id,
                name: known.name,
                description: known.description,
                documentationURL: known.docsURL,
                repositoryURL: known.repoURL,
                version: known.version,
                trustScore: known.trustScore,
                cachedAt: Date()
            )
            cachedLibraries[normalizedName] = info
            await saveCache()
            return info
        }

        // Try to infer from common patterns
        let info = await inferLibraryInfo(from: normalizedName)
        if let info = info {
            cachedLibraries[normalizedName] = info
            await saveCache()
        }

        return info
    }

    // MARK: - Query Documentation

    /// Fetch documentation for a specific topic
    /// Similar to Context7's query-docs tool
    public func queryDocs(
        libraryId: String,
        topic: String? = nil,
        maxTokens: Int = 5000
    ) async throws -> DocumentationResult {
        logger.info("Querying docs for \(libraryId) topic: \(topic ?? "general")")

        isLoading = true
        defer { isLoading = false }

        // Get library info
        guard let library = try await resolveLibraryId(name: libraryId) else {
            throw DocumentationError.libraryNotFound(libraryId)
        }

        // Fetch documentation content
        var content = ""

        // Try to fetch from documentation URL
        if let docsURL = library.documentationURL {
            if let fetched = await fetchDocumentation(from: docsURL, topic: topic) {
                content = fetched
            }
        }

        // If no content, use fallback description
        if content.isEmpty {
            content = library.description
        }

        // Truncate to max tokens (approximate: 1 token ≈ 4 chars)
        let maxChars = maxTokens * 4
        if content.count > maxChars {
            content = String(content.prefix(maxChars)) + "\n\n[Documentation truncated...]"
        }

        return DocumentationResult(
            libraryId: library.id,
            libraryName: library.name,
            topic: topic,
            content: content,
            sourceURL: library.documentationURL,
            fetchedAt: Date()
        )
    }

    // MARK: - Auto-Trigger Detection (Context7 Feature)

    /// Detect if a query would benefit from documentation lookup
    public func shouldFetchDocumentation(for query: String) -> DocumentationTrigger? {
        let lowercased = query.lowercased()

        // Keywords that suggest documentation lookup
        let docKeywords = [
            "how do i", "how to", "what is the", "syntax for",
            "example of", "documentation", "api for", "method for",
            "function for", "implement", "using", "with"
        ]

        // Check for explicit trigger
        if lowercased.contains("use context7") || lowercased.contains("use docs") {
            return .explicit
        }

        // Check for library-related questions
        for keyword in docKeywords {
            if lowercased.contains(keyword) {
                // Try to extract library name
                if let library = extractLibraryFromQuery(query) {
                    return .detected(library: library)
                }
            }
        }

        // Check for framework mentions
        for (name, _) in knownLibraries {
            if lowercased.contains(name) {
                return .detected(library: name)
            }
        }

        return nil
    }

    // MARK: - Private Methods

    private func extractLibraryFromQuery(_ query: String) -> String? {
        let lowercased = query.lowercased()

        // Check known libraries
        for (name, _) in knownLibraries {
            if lowercased.contains(name) {
                return name
            }
        }

        // Common library name patterns
        let patterns = [
            #"(?:using|with|in|for)\s+(\w+(?:\.\w+)?)"#,
            #"(\w+(?:js|kit|ui|swift))\b"#
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: query, range: NSRange(query.startIndex..., in: query)),
               match.numberOfRanges > 1,
               let range = Range(match.range(at: 1), in: query) {
                return String(query[range]).lowercased()
            }
        }

        return nil
    }

    private func inferLibraryInfo(from name: String) async -> LibraryInfo? {
        // Try to construct URLs from common patterns
        let possibleRepoURLs = [
            "https://github.com/\(name)/\(name)",
            "https://github.com/\(name)js/\(name)",
            "https://github.com/\(name)-team/\(name)"
        ]

        // For now, return basic info
        return LibraryInfo(
            id: "/\(name)/\(name)",
            name: name,
            description: "Library: \(name)",
            documentationURL: nil,
            repositoryURL: URL(string: possibleRepoURLs[0]),
            version: nil,
            trustScore: 5,
            cachedAt: Date()
        )
    }

    private func fetchDocumentation(from url: URL, topic: String?) async -> String? {
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode),
                  let html = String(data: data, encoding: .utf8) else {
                return nil
            }

            // Strip HTML tags for plain text extraction
            var text = html
                .replacingOccurrences(of: "<script[^>]*>[\\s\\S]*?</script>", with: "", options: .regularExpression)
                .replacingOccurrences(of: "<style[^>]*>[\\s\\S]*?</style>", with: "", options: .regularExpression)
                .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            // Filter by topic if specified
            if let topic {
                let paragraphs = text.components(separatedBy: ". ")
                let relevant = paragraphs.filter { $0.localizedCaseInsensitiveContains(topic) }
                if !relevant.isEmpty {
                    text = relevant.joined(separator: ". ")
                }
            }

            // Truncate to reasonable length for context
            return String(text.prefix(4000))
        } catch {
            return nil
        }
    }

    private func loadCache() async {
        let cacheFile = cacheURL.appendingPathComponent("libraries.json")
        guard FileManager.default.fileExists(atPath: cacheFile.path),
              let data = try? Data(contentsOf: cacheFile),
              let cached = try? JSONDecoder().decode([String: LibraryInfo].self, from: data) else {
            return
        }
        cachedLibraries = cached
    }

    private func saveCache() async {
        let cacheFile = cacheURL.appendingPathComponent("libraries.json")
        if let data = try? JSONEncoder().encode(cachedLibraries) {
            try? data.write(to: cacheFile)
        }
    }

    // MARK: - Known Libraries Database

    private var knownLibraries: [String: KnownLibrary] {
        [
            // JavaScript/TypeScript
            "react": KnownLibrary(
                id: "/facebook/react",
                name: "React",
                description: "A JavaScript library for building user interfaces",
                docsURL: URL(string: "https://react.dev/reference"),
                repoURL: URL(string: "https://github.com/facebook/react"),
                version: "18",
                trustScore: 10
            ),
            "next": KnownLibrary(
                id: "/vercel/next.js",
                name: "Next.js",
                description: "The React Framework for the Web",
                docsURL: URL(string: "https://nextjs.org/docs"),
                repoURL: URL(string: "https://github.com/vercel/next.js"),
                version: "15",
                trustScore: 10
            ),
            "nextjs": KnownLibrary(
                id: "/vercel/next.js",
                name: "Next.js",
                description: "The React Framework for the Web",
                docsURL: URL(string: "https://nextjs.org/docs"),
                repoURL: URL(string: "https://github.com/vercel/next.js"),
                version: "15",
                trustScore: 10
            ),
            "vue": KnownLibrary(
                id: "/vuejs/core",
                name: "Vue.js",
                description: "The Progressive JavaScript Framework",
                docsURL: URL(string: "https://vuejs.org/guide"),
                repoURL: URL(string: "https://github.com/vuejs/core"),
                version: "3",
                trustScore: 10
            ),
            "typescript": KnownLibrary(
                id: "/microsoft/typescript",
                name: "TypeScript",
                description: "TypeScript is a superset of JavaScript that compiles to clean JavaScript output",
                docsURL: URL(string: "https://www.typescriptlang.org/docs"),
                repoURL: URL(string: "https://github.com/microsoft/TypeScript"),
                version: "5",
                trustScore: 10
            ),

            // Swift/Apple
            "swiftui": KnownLibrary(
                id: "/apple/swiftui",
                name: "SwiftUI",
                description: "Apple's declarative UI framework",
                docsURL: URL(string: "https://developer.apple.com/documentation/swiftui"),
                repoURL: nil,
                version: nil,
                trustScore: 10
            ),
            "combine": KnownLibrary(
                id: "/apple/combine",
                name: "Combine",
                description: "Apple's framework for processing values over time",
                docsURL: URL(string: "https://developer.apple.com/documentation/combine"),
                repoURL: nil,
                version: nil,
                trustScore: 10
            ),
            "swift": KnownLibrary(
                id: "/apple/swift",
                name: "Swift",
                description: "A powerful and intuitive programming language",
                docsURL: URL(string: "https://docs.swift.org/swift-book"),
                repoURL: URL(string: "https://github.com/apple/swift"),
                version: "6",
                trustScore: 10
            ),

            // Python
            "python": KnownLibrary(
                id: "/python/cpython",
                name: "Python",
                description: "The Python programming language",
                docsURL: URL(string: "https://docs.python.org/3"),
                repoURL: URL(string: "https://github.com/python/cpython"),
                version: "3.12",
                trustScore: 10
            ),
            "fastapi": KnownLibrary(
                id: "/tiangolo/fastapi",
                name: "FastAPI",
                description: "FastAPI framework, high performance, easy to learn, fast to code, ready for production",
                docsURL: URL(string: "https://fastapi.tiangolo.com"),
                repoURL: URL(string: "https://github.com/tiangolo/fastapi"),
                version: nil,
                trustScore: 9
            ),
            "django": KnownLibrary(
                id: "/django/django",
                name: "Django",
                description: "The Web framework for perfectionists with deadlines",
                docsURL: URL(string: "https://docs.djangoproject.com"),
                repoURL: URL(string: "https://github.com/django/django"),
                version: "5",
                trustScore: 10
            ),

            // Databases
            "prisma": KnownLibrary(
                id: "/prisma/prisma",
                name: "Prisma",
                description: "Next-generation ORM for Node.js and TypeScript",
                docsURL: URL(string: "https://www.prisma.io/docs"),
                repoURL: URL(string: "https://github.com/prisma/prisma"),
                version: nil,
                trustScore: 9
            ),
            "supabase": KnownLibrary(
                id: "/supabase/supabase",
                name: "Supabase",
                description: "The open source Firebase alternative",
                docsURL: URL(string: "https://supabase.com/docs"),
                repoURL: URL(string: "https://github.com/supabase/supabase"),
                version: nil,
                trustScore: 9
            ),

            // AI/ML
            "langchain": KnownLibrary(
                id: "/langchain-ai/langchain",
                name: "LangChain",
                description: "Building applications with LLMs through composability",
                docsURL: URL(string: "https://python.langchain.com/docs"),
                repoURL: URL(string: "https://github.com/langchain-ai/langchain"),
                version: nil,
                trustScore: 9
            ),
            "openai": KnownLibrary(
                id: "/openai/openai-python",
                name: "OpenAI Python",
                description: "The official Python library for the OpenAI API",
                docsURL: URL(string: "https://platform.openai.com/docs"),
                repoURL: URL(string: "https://github.com/openai/openai-python"),
                version: nil,
                trustScore: 10
            ),
            "anthropic": KnownLibrary(
                id: "/anthropics/anthropic-sdk-python",
                name: "Anthropic SDK",
                description: "Python SDK for the Anthropic API",
                docsURL: URL(string: "https://docs.anthropic.com"),
                repoURL: URL(string: "https://github.com/anthropics/anthropic-sdk-python"),
                version: nil,
                trustScore: 10
            )
        ]
    }
}

// MARK: - Models

public struct LibraryInfo: Codable, Sendable {
    public let id: String
    public let name: String
    public let description: String
    public let documentationURL: URL?
    public let repositoryURL: URL?
    public let version: String?
    public let trustScore: Int
    public let cachedAt: Date

    // Context7 API v2 additions
    public let totalSnippets: Int?
    public let benchmarkScore: Int?
    public let availableVersions: [String]?

    public init(
        id: String,
        name: String,
        description: String,
        documentationURL: URL? = nil,
        repositoryURL: URL? = nil,
        version: String? = nil,
        trustScore: Int,
        cachedAt: Date,
        totalSnippets: Int? = nil,
        benchmarkScore: Int? = nil,
        availableVersions: [String]? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.documentationURL = documentationURL
        self.repositoryURL = repositoryURL
        self.version = version
        self.trustScore = trustScore
        self.cachedAt = cachedAt
        self.totalSnippets = totalSnippets
        self.benchmarkScore = benchmarkScore
        self.availableVersions = availableVersions
    }
}

private struct KnownLibrary {
    let id: String
    let name: String
    let description: String
    let docsURL: URL?
    let repoURL: URL?
    let version: String?
    let trustScore: Int
}

public struct DocumentationResult: Sendable {
    public let libraryId: String
    public let libraryName: String
    public let topic: String?
    public let content: String
    public let sourceURL: URL?
    public let fetchedAt: Date
}

public enum DocumentationTrigger: Sendable {
    case explicit
    case detected(library: String)
}

public enum DocumentationError: Error, LocalizedError {
    case libraryNotFound(String)
    case fetchFailed(String)
    case rateLimited

    public var errorDescription: String? {
        switch self {
        case .libraryNotFound(let name):
            return "Library not found: \(name)"
        case .fetchFailed(let reason):
            return "Failed to fetch documentation: \(reason)"
        case .rateLimited:
            return "Rate limited - please try again later"
        }
    }
}

// MARK: - Documentation Grounding Agent

/// A specialized agent for documentation lookups
/// Inspired by Context7's docs-researcher agent
public actor DocsResearcherAgent {
    private var groundingService: DocumentationGroundingService?
    private let logger = Logger(subsystem: "app.thea", category: "DocsResearcher")

    public init() {
        self.groundingService = nil
    }

    @MainActor
    public init(groundingService: DocumentationGroundingService) {
        self.groundingService = groundingService
    }

    private func getGroundingService() async -> DocumentationGroundingService {
        if let service = groundingService {
            return service
        }
        let service = await DocumentationGroundingService.shared
        groundingService = service
        return service
    }

    /// Research documentation for a query
    public func research(query: String) async throws -> DocsResearchResult {
        logger.info("Researching: \(query)")

        let service = await getGroundingService()

        // Extract library from query
        let trigger = await service.shouldFetchDocumentation(for: query)

        guard let trigger = trigger else {
            return DocsResearchResult(
                query: query,
                libraryFound: false,
                documentation: nil,
                suggestions: []
            )
        }

        let libraryName: String
        switch trigger {
        case .explicit:
            // Try to extract library name
            libraryName = extractLibraryName(from: query) ?? ""
        case .detected(let library):
            libraryName = library
        }

        guard !libraryName.isEmpty else {
            return DocsResearchResult(
                query: query,
                libraryFound: false,
                documentation: nil,
                suggestions: ["Please specify which library you need documentation for."]
            )
        }

        // Resolve and fetch documentation
        do {
            let docs = try await service.queryDocs(
                libraryId: libraryName,
                topic: extractTopic(from: query)
            )

            return DocsResearchResult(
                query: query,
                libraryFound: true,
                documentation: docs,
                suggestions: []
            )
        } catch {
            logger.error("Failed to research \(libraryName): \(error.localizedDescription)")
            return DocsResearchResult(
                query: query,
                libraryFound: false,
                documentation: nil,
                suggestions: ["Could not find documentation for '\(libraryName)'. Try being more specific."]
            )
        }
    }

    private func extractLibraryName(from query: String) -> String? {
        // Simple extraction - look for common patterns
        let patterns = [
            #"(?:for|about|using|with)\s+(\w+(?:\.\w+)?)"#,
            #"(\w+)\s+(?:docs|documentation|api)"#
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: query, range: NSRange(query.startIndex..., in: query)),
               match.numberOfRanges > 1,
               let range = Range(match.range(at: 1), in: query) {
                return String(query[range]).lowercased()
            }
        }

        return nil
    }

    private func extractTopic(from query: String) -> String? {
        // Extract specific topic from query
        let keywords = ["how to", "how do i", "example of", "syntax for"]

        for keyword in keywords {
            if let range = query.lowercased().range(of: keyword) {
                let afterKeyword = String(query[range.upperBound...])
                let topic = afterKeyword.trimmingCharacters(in: .whitespaces)
                if !topic.isEmpty {
                    return topic
                }
            }
        }

        return nil
    }
}

public struct DocsResearchResult: Sendable {
    public let query: String
    public let libraryFound: Bool
    public let documentation: DocumentationResult?
    public let suggestions: [String]
}
