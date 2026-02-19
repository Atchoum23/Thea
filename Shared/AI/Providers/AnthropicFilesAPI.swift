// AnthropicFilesAPI.swift
// Thea
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

// periphery:ignore - Reserved: AnthropicFilesAPI class — reserved for future feature activation
/// Files API for uploading and managing files
/// Beta header: files-api-2025-04-14
/// Max: 500MB per file, 29-day retention
/// Pricing: FREE
final class AnthropicFilesAPI: Sendable {
    private let apiKey: String
    private let baseURL = "https://api.anthropic.com/v1/files"
    // periphery:ignore - Reserved: AnthropicFilesAPI type reserved for future feature activation
    private let apiVersion = "2023-06-01"
    private let betaHeader = "files-api-2025-04-14"
    private let logger = Logger(subsystem: "com.thea.v2", category: "AnthropicFilesAPI")

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    // MARK: - Upload

    /// Upload a file to Anthropic's storage
    /// - Parameters:
    ///   - file: The file data
    ///   - filename: Original filename
    ///   - mimeType: MIME type of the file
    /// - Returns: File upload response with file_id
    func upload(
        file: Data,
        filename: String,
        mimeType: String
    ) async throws -> FileUploadResponse {
        guard let url = URL(string: baseURL) else {
            throw AnthropicError.invalidResponseDetails("Invalid URL")
        }

        // Check file size limit (500MB)
        let maxSize = 500 * 1024 * 1024
        guard file.count <= maxSize else {
            throw AnthropicError.fileTooLarge(bytes: file.count, maxBytes: maxSize)
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
            throw AnthropicError.invalidResponseDetails("Invalid HTTP response")
        }

        if httpResponse.statusCode != 200 && httpResponse.statusCode != 201 {
            var errorMessage: String? = nil
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let error = json["error"] as? [String: Any],
                   let message = error["message"] as? String {
                    errorMessage = message
                }
            } catch {
                logger.debug("Could not parse error response body: \(error.localizedDescription)")
            }
            throw AnthropicError.serverError(status: httpResponse.statusCode, message: errorMessage)
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
    func getFile(fileId: String) async throws -> FileUploadResponse {
        guard let url = URL(string: "\(baseURL)/\(fileId)") else {
            throw AnthropicError.invalidResponseDetails("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue(betaHeader, forHTTPHeaderField: "anthropic-beta")
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AnthropicError.invalidResponseDetails("Invalid HTTP response")
        }

        if httpResponse.statusCode != 200 {
            throw AnthropicError.serverError(status: httpResponse.statusCode, message: nil)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        return try decoder.decode(FileUploadResponse.self, from: data)
    }

    // MARK: - Get Content

    /// Download file content by ID
    func getContent(fileId: String) async throws -> Data {
        guard let url = URL(string: "\(baseURL)/\(fileId)/content") else {
            throw AnthropicError.invalidResponseDetails("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue(betaHeader, forHTTPHeaderField: "anthropic-beta")
        request.timeoutInterval = 300

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AnthropicError.invalidResponseDetails("Invalid HTTP response")
        }

        if httpResponse.statusCode != 200 {
            throw AnthropicError.serverError(status: httpResponse.statusCode, message: nil)
        }

        return data
    }

    // MARK: - Delete

    /// Delete a file
    func delete(fileId: String) async throws {
        guard let url = URL(string: "\(baseURL)/\(fileId)") else {
            throw AnthropicError.invalidResponseDetails("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue(betaHeader, forHTTPHeaderField: "anthropic-beta")
        request.timeoutInterval = 30

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AnthropicError.invalidResponseDetails("Invalid HTTP response")
        }

        if httpResponse.statusCode != 200 && httpResponse.statusCode != 204 {
            throw AnthropicError.serverError(status: httpResponse.statusCode, message: nil)
        }

        logger.info("File deleted: \(fileId)")
    }

    // MARK: - List Files

    /// List all uploaded files
    func listFiles() async throws -> [FileUploadResponse] {
        guard let url = URL(string: baseURL) else {
            throw AnthropicError.invalidResponseDetails("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue(betaHeader, forHTTPHeaderField: "anthropic-beta")
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AnthropicError.invalidResponseDetails("Invalid HTTP response")
        }

        if httpResponse.statusCode != 200 {
            throw AnthropicError.serverError(status: httpResponse.statusCode, message: nil)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let listResponse = try decoder.decode(FileListResponse.self, from: data)
        return listResponse.data
    }
}

// MARK: - File Response Types

struct FileUploadResponse: Codable, Sendable {
    let id: String           // file_id for referencing in messages
    let filename: String
    let mimeType: String
    let sizeBytes: Int
    let createdAt: Date
    let expiresAt: Date      // 29 days after creation

    // periphery:ignore - Reserved: init(id:filename:mimeType:sizeBytes:createdAt:expiresAt:) initializer — reserved for future feature activation
    init(
        id: String,
        // periphery:ignore - Reserved: init(id:filename:mimeType:sizeBytes:createdAt:expiresAt:) initializer reserved for future feature activation
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

// periphery:ignore - Reserved: FileListResponse type — reserved for future feature activation
struct FileListResponse: Codable, Sendable {
    // periphery:ignore - Reserved: FileListResponse type reserved for future feature activation
    let data: [FileUploadResponse]
}

// MARK: - Helper for building file content blocks

// periphery:ignore - Reserved: AnthropicFileContent type reserved for future feature activation
struct AnthropicFileContent {
    /// Build a file content block for use in messages
    static func fileBlock(fileId: String) -> [String: Any] {
        [
            "type": "file",
            "file_id": fileId
        ]
    }

    /// Build an image content block from file
    static func imageFromFile(fileId: String) -> [String: Any] {
        [
            "type": "image",
            "source": [
                "type": "file",
                "file_id": fileId
            ]
        ]
    }

    /// Build a document content block from file
    static func documentFromFile(fileId: String) -> [String: Any] {
        [
            "type": "document",
            "source": [
                "type": "file",
                "file_id": fileId
            ]
        ]
    }
}
