//
//  Context7Client.swift
//  Thea
//
//  Client for Context7 API - provides up-to-date, version-specific
//  documentation for any library. Eliminates hallucinated APIs.
//
//  Copyright 2026. All rights reserved.
//

import Foundation
import os.log

// MARK: - Context7 Types

/// A library found in Context7
public struct Context7Library: Identifiable, Codable, Sendable {
    public let id: String
    public let name: String
    public let description: String?
    public let totalSnippets: Int
    public let trustScore: Double?
    public let benchmarkScore: Double?
    public let versions: [String]?

    public init(
        id: String,
        name: String,
        description: String? = nil,
        totalSnippets: Int = 0,
        trustScore: Double? = nil,
        benchmarkScore: Double? = nil,
        versions: [String]? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.totalSnippets = totalSnippets
        self.trustScore = trustScore
        self.benchmarkScore = benchmarkScore
        self.versions = versions
    }
}

/// A documentation snippet from Context7
public struct Context7Snippet: Identifiable, Codable, Sendable {
    public let id: UUID
    public let title: String
    public let content: String
    public let source: String?
    public let codeLanguage: String?
    public let relevanceScore: Double?

    public init(
        id: UUID = UUID(),
        title: String,
        content: String,
        source: String? = nil,
        codeLanguage: String? = nil,
        relevanceScore: Double? = nil
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.source = source
        self.codeLanguage = codeLanguage
        self.relevanceScore = relevanceScore
    }

    enum CodingKeys: String, CodingKey {
        case title, content, source, codeLanguage, relevanceScore
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        self.title = try container.decode(String.self, forKey: .title)
        self.content = try container.decode(String.self, forKey: .content)
        self.source = try container.decodeIfPresent(String.self, forKey: .source)
        self.codeLanguage = try container.decodeIfPresent(String.self, forKey: .codeLanguage)
        self.relevanceScore = try container.decodeIfPresent(Double.self, forKey: .relevanceScore)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(title, forKey: .title)
        try container.encode(content, forKey: .content)
        try container.encodeIfPresent(source, forKey: .source)
        try container.encodeIfPresent(codeLanguage, forKey: .codeLanguage)
        try container.encodeIfPresent(relevanceScore, forKey: .relevanceScore)
    }
}

/// Documentation context result from Context7
public struct Context7Result: Sendable {
    public let libraryId: String
    public let query: String
    public let snippets: [Context7Snippet]
    public let totalTokens: Int?
    public let fetchedAt: Date

    public init(
        libraryId: String,
        query: String,
        snippets: [Context7Snippet],
        totalTokens: Int? = nil,
        fetchedAt: Date = Date()
    ) {
        self.libraryId = libraryId
        self.query = query
        self.snippets = snippets
        self.totalTokens = totalTokens
        self.fetchedAt = fetchedAt
    }

    /// Formatted documentation as a single string
    public var formattedDocumentation: String {
        snippets.map { snippet in
            """
            ## \(snippet.title)

            \(snippet.content)

            \(snippet.source.map { "Source: \($0)" } ?? "")
            """
        }.joined(separator: "\n\n---\n\n")
    }
}

// MARK: - Context7 Error

public enum Context7Error: Error, LocalizedError {
    case noAPIKey
    case invalidLibraryId
    case libraryNotFound(String)
    case networkError(Error)
    case decodingError(Error)
    case rateLimited(retryAfter: TimeInterval?)
    case serverError(statusCode: Int, message: String?)

    public var errorDescription: String? {
        switch self {
        case .noAPIKey:
            "Context7 API key not configured"
        case .invalidLibraryId:
            "Invalid library ID format"
        case .libraryNotFound(let name):
            "Library '\(name)' not found"
        case .networkError(let error):
            "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            "Failed to decode response: \(error.localizedDescription)"
        case .rateLimited(let retryAfter):
            "Rate limited\(retryAfter.map { ". Retry after \(Int($0))s" } ?? "")"
        case .serverError(let code, let message):
            "Server error \(code)\(message.map { ": \($0)" } ?? "")"
        }
    }
}

// MARK: - Context7 Client

/// Client for interacting with Context7 API
public actor Context7Client {
    public static let shared = Context7Client()

    private let logger = Logger(subsystem: "ai.thea.app", category: "Context7")

    // MARK: - Configuration

    private var apiKey: String?
    private let baseURL = URL(string: "https://context7.com/api/v2")!
    private let urlSession: URLSession
    private var cache: [String: CachedResult] = [:]
    private let cacheExpiration: TimeInterval = 3600 // 1 hour

    // MARK: - Initialization

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.waitsForConnectivity = true
        urlSession = URLSession(configuration: config)
    }

    // MARK: - Configuration

    /// Configure the API key
    public func configure(apiKey: String) {
        self.apiKey = apiKey
        logger.info("Context7 client configured")
    }

    /// Check if client is configured
    public var isConfigured: Bool {
        apiKey != nil
    }

    // MARK: - Library Search

    /// Search for libraries by name or query
    public func searchLibraries(query: String) async throws -> [Context7Library] {
        guard let apiKey = apiKey else {
            throw Context7Error.noAPIKey
        }

        var components = URLComponents(url: baseURL.appendingPathComponent("libs/search"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "query", value: query)
        ]

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await urlSession.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw Context7Error.networkError(URLError(.badServerResponse))
            }

            switch httpResponse.statusCode {
            case 200:
                let decoder = JSONDecoder()
                let libraries = try decoder.decode([Context7Library].self, from: data)
                logger.debug("Found \(libraries.count) libraries for query: \(query)")
                return libraries

            case 429:
                let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After").flatMap { TimeInterval($0) }
                throw Context7Error.rateLimited(retryAfter: retryAfter)

            default:
                let message = String(data: data, encoding: .utf8)
                throw Context7Error.serverError(statusCode: httpResponse.statusCode, message: message)
            }

        } catch let error as Context7Error {
            throw error
        } catch let error as DecodingError {
            throw Context7Error.decodingError(error)
        } catch {
            throw Context7Error.networkError(error)
        }
    }

    /// Resolve a library name to a Context7-compatible library ID
    public func resolveLibraryId(libraryName: String) async throws -> Context7Library {
        let libraries = try await searchLibraries(query: libraryName)

        // Find exact match first
        if let exact = libraries.first(where: { $0.name.lowercased() == libraryName.lowercased() }) {
            return exact
        }

        // Fall back to first result
        guard let first = libraries.first else {
            throw Context7Error.libraryNotFound(libraryName)
        }

        return first
    }

    // MARK: - Documentation Fetching

    /// Get documentation for a library
    public func getDocumentation(
        libraryId: String,
        topic: String? = nil,
        tokens: Int = 5000
    ) async throws -> Context7Result {
        guard let apiKey = apiKey else {
            throw Context7Error.noAPIKey
        }

        // Check cache
        let cacheKey = "\(libraryId):\(topic ?? ""):\(tokens)"
        if let cached = cache[cacheKey], !cached.isExpired(expiration: cacheExpiration) {
            logger.debug("Cache hit for \(cacheKey)")
            return cached.result
        }

        // Validate library ID format (/org/project or /org/project/version)
        guard libraryId.hasPrefix("/") && libraryId.split(separator: "/").count >= 2 else {
            throw Context7Error.invalidLibraryId
        }

        var components = URLComponents(url: baseURL.appendingPathComponent("context"), resolvingAgainstBaseURL: false)!
        var queryItems = [
            URLQueryItem(name: "libraryId", value: libraryId),
            URLQueryItem(name: "type", value: "json")
        ]

        if let topic = topic {
            queryItems.append(URLQueryItem(name: "query", value: topic))
        }

        components.queryItems = queryItems

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await urlSession.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw Context7Error.networkError(URLError(.badServerResponse))
            }

            switch httpResponse.statusCode {
            case 200:
                let decoder = JSONDecoder()
                let snippets = try decoder.decode([Context7Snippet].self, from: data)

                let result = Context7Result(
                    libraryId: libraryId,
                    query: topic ?? "",
                    snippets: snippets,
                    totalTokens: tokens
                )

                // Cache result
                cache[cacheKey] = CachedResult(result: result)

                logger.debug("Fetched \(snippets.count) snippets for \(libraryId)")
                return result

            case 429:
                let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After").flatMap { TimeInterval($0) }
                throw Context7Error.rateLimited(retryAfter: retryAfter)

            case 404:
                throw Context7Error.libraryNotFound(libraryId)

            default:
                let message = String(data: data, encoding: .utf8)
                throw Context7Error.serverError(statusCode: httpResponse.statusCode, message: message)
            }

        } catch let error as Context7Error {
            throw error
        } catch let error as DecodingError {
            throw Context7Error.decodingError(error)
        } catch {
            throw Context7Error.networkError(error)
        }
    }

    /// Convenience method: search by name and get documentation
    public func getDocumentationByName(
        libraryName: String,
        topic: String? = nil,
        tokens: Int = 5000
    ) async throws -> Context7Result {
        let library = try await resolveLibraryId(libraryName: libraryName)
        return try await getDocumentation(libraryId: library.id, topic: topic, tokens: tokens)
    }

    // MARK: - Cache Management

    /// Clear the documentation cache
    public func clearCache() {
        cache.removeAll()
        logger.info("Cache cleared")
    }

    /// Get cache statistics
    public var cacheStats: (count: Int, oldestAge: TimeInterval?) {
        let oldest = cache.values.min { $0.timestamp < $1.timestamp }
        let age = oldest.map { Date().timeIntervalSince($0.timestamp) }
        return (cache.count, age)
    }
}

// MARK: - Cache Entry

private struct CachedResult {
    let result: Context7Result
    let timestamp: Date

    init(result: Context7Result) {
        self.result = result
        self.timestamp = Date()
    }

    func isExpired(expiration: TimeInterval) -> Bool {
        Date().timeIntervalSince(timestamp) > expiration
    }
}

// MARK: - SwiftUI Integration

import SwiftUI

/// View for searching and displaying library documentation
public struct Context7SearchView: View {
    @State private var searchQuery = ""
    @State private var libraries: [Context7Library] = []
    @State private var selectedLibrary: Context7Library?
    @State private var documentation: Context7Result?
    @State private var isSearching = false
    @State private var isLoading = false
    @State private var error: String?

    public init() {}

    public var body: some View {
        NavigationStack {
            VStack {
                // Search bar
                HStack {
                    TextField("Search libraries...", text: $searchQuery)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { search() }

                    Button(action: search) {
                        Image(systemName: "magnifyingglass")
                    }
                    .disabled(searchQuery.isEmpty || isSearching)
                }
                .padding()

                if let error = error {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                }

                if isSearching {
                    ProgressView("Searching...")
                } else if let doc = documentation {
                    // Show documentation
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Documentation for \(doc.libraryId)")
                                .font(.headline)

                            ForEach(doc.snippets) { snippet in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(snippet.title)
                                        .font(.subheadline)
                                        .fontWeight(.medium)

                                    Text(snippet.content)
                                        .font(.body)

                                    if let source = snippet.source {
                                        Text(source)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding()
                                #if os(iOS)
                                .background(Color(.secondarySystemBackground))
                                #else
                                .background(Color(.controlBackgroundColor))
                                #endif
                                .cornerRadius(8)
                            }
                        }
                        .padding()
                    }
                } else if !libraries.isEmpty {
                    // Show search results
                    List(libraries) { library in
                        Button(action: { loadDocumentation(for: library) }) {
                            VStack(alignment: .leading) {
                                Text(library.name)
                                    .font(.headline)
                                if let desc = library.description {
                                    Text(desc)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                }
                                HStack {
                                    Text("\(library.totalSnippets) snippets")
                                    if let trust = library.trustScore {
                                        Text("Trust: \(Int(trust * 100))%")
                                    }
                                }
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            }
                        }
                    }
                } else {
                    Spacer()
                    Text("Search for a library to view its documentation")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
            .navigationTitle("Context7")
        }
    }

    private func search() {
        guard !searchQuery.isEmpty else { return }

        isSearching = true
        error = nil
        documentation = nil

        Task {
            do {
                libraries = try await Context7Client.shared.searchLibraries(query: searchQuery)
            } catch {
                self.error = error.localizedDescription
            }
            isSearching = false
        }
    }

    private func loadDocumentation(for library: Context7Library) {
        isLoading = true
        error = nil

        Task {
            do {
                documentation = try await Context7Client.shared.getDocumentation(libraryId: library.id)
            } catch {
                self.error = error.localizedDescription
            }
            isLoading = false
        }
    }
}
