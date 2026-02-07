// AnthropicFilesAPI.swift
// Thea V2
//
// Files API for Anthropic Claude
// Beta header: files-api-2025-04-14
// Endpoint: POST /v1/files
//
// Upload files once, reference many times using file_id
// Max 500MB per file, 29-day retention
// Pricing: FREE (file operations have no additional charges)

import Foundation
import OSLog

// MARK: - Anthropic Files API

/// Files API for uploading and managing files
/// Beta header: files-api-2025-04-14
/// Max: 500MB per file, 29-day retention
/// Pricing: FREE
public final class AnthropicFilesAPI: Sendable {
    private let apiKey: String
    private let baseURL = "https://api.anthropic.com/v1/files"
    private let apiVersion = "2023-06-01"
    private let betaHeader = "files-api-2025-04-14"
    private let logger = Logger(subsystem: "com.thea.v2", category: "AnthropicFilesAPI")

    public init(apiKey: String) {
        self.apiKey = apiKey
    }

    // MARK: - Upload

    /// Upload a file to Anthropic's storage
    /// - Parameters:
    ///   - file: The file data
    ///   - filename: Original filename
    ///   - mimeType: MIME type of the file
    /// - Returns: File upload response with file_id
    public func upload(
        file: Data,
        filename: String,
        mimeType: String
    ) async throws -> FileUploadResponse {
        guard let url = URL(string: baseURL) else {
            throw ProviderError.invalidResponse(details: "Invalid URL")
        }

        // Check file size limit (500MB)
        let maxSize = 500 * 1024 * 1024
        guard file.count <= maxSize else {
            throw ProviderError.invalidResponse(details: "File exceeds 500MB limit")
        }

        // Build multipart form data
        let boundary = UUID().uuidString
        var body = Data()

        // Add file data
        body.append(Data("--\(boundary)\r\n".utf8))
        body.append(Data("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".utf8))
        body.append(Data("Content-Type: \(mimeType)\r\n\r\n".utf8))
        body.append(file)
        body.append(Data("\r\n".utf8))

        // Add purpose field
        body.append(Data("--\(boundary)\r\n".utf8))
        body.append(Data("Content-Disposition: form-data; name=\"purpose\"\r\n\r\n".utf8))
        body.append(Data("assistants".utf8))
        body.append(Data("\r\n".utf8))

        body.append(Data("--\(boundary)--\r\n".utf8))

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue(betaHeader, forHTTPHeaderField: "anthropic-beta")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 300  // 5 minutes for large uploads
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ProviderError.invalidResponse(details: "Invalid HTTP response")
        }

        if httpResponse.statusCode != 200 && httpResponse.statusCode != 201 {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = json["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw ProviderError.serverError(status: httpResponse.statusCode, message: message)
            }
            throw ProviderError.serverError(status: httpResponse.statusCode, message: nil)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let fileResponse = try decoder.decode(FileUploadResponse.self, from: data)
        logger.info("File uploaded: \(fileResponse.id)")

        return fileResponse
    }

    // MARK: - Get File

    /// Get file metadata by ID
    /// - Parameter fileId: The file ID
    /// - Returns: File metadata
    public func getFile(fileId: String) async throws -> FileUploadResponse {
        guard let url = URL(string: "\(baseURL)/\(fileId)") else {
            throw ProviderError.invalidResponse(details: "Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue(betaHeader, forHTTPHeaderField: "anthropic-beta")
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ProviderError.invalidResponse(details: "Invalid HTTP response")
        }

        if httpResponse.statusCode != 200 {
            throw ProviderError.serverError(status: httpResponse.statusCode, message: nil)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        return try decoder.decode(FileUploadResponse.self, from: data)
    }

    // MARK: - Get Content

    /// Download file content by ID
    /// - Parameter fileId: The file ID
    /// - Returns: File data
    public func getContent(fileId: String) async throws -> Data {
        guard let url = URL(string: "\(baseURL)/\(fileId)/content") else {
            throw ProviderError.invalidResponse(details: "Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue(betaHeader, forHTTPHeaderField: "anthropic-beta")
        request.timeoutInterval = 300

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ProviderError.invalidResponse(details: "Invalid HTTP response")
        }

        if httpResponse.statusCode != 200 {
            throw ProviderError.serverError(status: httpResponse.statusCode, message: nil)
        }

        return data
    }

    // MARK: - Delete

    /// Delete a file
    /// - Parameter fileId: The file ID to delete
    public func delete(fileId: String) async throws {
        guard let url = URL(string: "\(baseURL)/\(fileId)") else {
            throw ProviderError.invalidResponse(details: "Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue(betaHeader, forHTTPHeaderField: "anthropic-beta")
        request.timeoutInterval = 30

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ProviderError.invalidResponse(details: "Invalid HTTP response")
        }

        if httpResponse.statusCode != 200 && httpResponse.statusCode != 204 {
            throw ProviderError.serverError(status: httpResponse.statusCode, message: nil)
        }

        logger.info("File deleted: \(fileId)")
    }

    // MARK: - List Files

    /// List all uploaded files
    /// - Returns: Array of file metadata
    public func listFiles() async throws -> [FileUploadResponse] {
        guard let url = URL(string: baseURL) else {
            throw ProviderError.invalidResponse(details: "Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue(betaHeader, forHTTPHeaderField: "anthropic-beta")
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ProviderError.invalidResponse(details: "Invalid HTTP response")
        }

        if httpResponse.statusCode != 200 {
            throw ProviderError.serverError(status: httpResponse.statusCode, message: nil)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let listResponse = try decoder.decode(FileListResponse.self, from: data)
        return listResponse.data
    }
}

// MARK: - File Response Types

public struct FileUploadResponse: Codable, Sendable {
    public let id: String           // file_id for referencing in messages
    public let filename: String
    public let mimeType: String
    public let sizeBytes: Int
    public let createdAt: Date
    public let expiresAt: Date      // 29 days after creation

    public init(
        id: String,
        filename: String,
        mimeType: String,
        sizeBytes: Int,
        createdAt: Date,
        expiresAt: Date
    ) {
        self.id = id
        self.filename = filename
        self.mimeType = mimeType
        self.sizeBytes = sizeBytes
        self.createdAt = createdAt
        self.expiresAt = expiresAt
    }
}

public struct FileListResponse: Codable, Sendable {
    public let data: [FileUploadResponse]
}

// MARK: - File Content Block Extension

public extension ChatContentPart {
    /// Create a file reference content part using a file_id
    static func fileReference(_ fileId: String) -> ChatContentPart {
        // This creates a reference that can be used in messages
        // The actual API format uses {"type": "file", "file_id": "..."}
        .text("[file:\(fileId)]")
    }
}

// MARK: - Helper for building file content blocks

public struct AnthropicFileContent {
    /// Build a file content block for use in messages
    /// - Parameter fileId: The file ID from upload response
    /// - Returns: Dictionary for JSON serialization
    public static func fileBlock(fileId: String) -> [String: Any] {
        [
            "type": "file",
            "file_id": fileId
        ]
    }

    /// Build an image content block from file
    /// - Parameter fileId: The file ID of an image
    /// - Returns: Dictionary for JSON serialization
    public static func imageFromFile(fileId: String) -> [String: Any] {
        [
            "type": "image",
            "source": [
                "type": "file",
                "file_id": fileId
            ]
        ]
    }

    /// Build a document content block from file
    /// - Parameter fileId: The file ID of a document (PDF, etc.)
    /// - Returns: Dictionary for JSON serialization
    public static func documentFromFile(fileId: String) -> [String: Any] {
        [
            "type": "document",
            "source": [
                "type": "file",
                "file_id": fileId
            ]
        ]
    }
}
