// CloudStorageService.swift
// Thea — AAG3: Cloud Storage + GitHub Intelligence
//
// Pure URLSession REST for Google Drive v3 and Dropbox API v2.
// RM-1 pre-audit confirmed SwiftyDropbox is NOT in project dependencies —
// using raw REST to avoid SPM churn.
//
// Token storage: SettingsManager.getAPIKey(for: "google_drive") / "dropbox"
//
// Google Drive OAuth2: https://console.developers.google.com
// Dropbox App: https://www.dropbox.com/developers/apps

import Foundation
import OSLog

// MARK: - CloudFile

// periphery:ignore - Reserved: AD3 audit — wired in future integration
struct CloudFile: Sendable, Identifiable {
    let id: String
    let name: String
    let mimeType: String
    let modifiedAt: Date?
    let size: Int64
    let provider: CloudProvider
}

enum CloudProvider: String, Sendable {
    case googleDrive = "Google Drive"
    case dropbox = "Dropbox"
}

// MARK: - CloudStorageService

// periphery:ignore - Reserved: AD3 audit — wired in future integration
actor CloudStorageService {
    static let shared = CloudStorageService()

    private let logger = Logger(subsystem: "ai.thea.app", category: "CloudStorageService")

    // MARK: - Google Drive

    /// List files in Google Drive matching an optional query.
    /// - Parameters:
    ///   - token: OAuth2 Bearer token (user must provide via OAuth flow)
    ///   - query: Drive query string, e.g. "name contains 'report'" (nil = list root)
    func listGoogleDriveFiles(token: String, query: String? = nil) async throws -> [CloudFile] {
        var components = URLComponents(string: "https://www.googleapis.com/drive/v3/files")!
        var queryItems = [
            URLQueryItem(name: "fields", value: "files(id,name,mimeType,modifiedTime,size)"),
            URLQueryItem(name: "pageSize", value: "50")
        ]
        if let q = query, !q.isEmpty {
            queryItems.append(URLQueryItem(name: "q", value: q))
        }
        components.queryItems = queryItems

        guard let url = components.url else {
            throw CloudStorageError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 20

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTP(response, provider: "Google Drive")

        return try parseGoogleDriveFiles(from: data)
    }

    /// Search Google Drive files by name keyword.
    func searchGoogleDrive(token: String, query: String) async throws -> [CloudFile] {
        let driveQuery = "name contains '\(query.replacingOccurrences(of: "'", with: "\\'"))'"
        return try await listGoogleDriveFiles(token: token, query: driveQuery)
    }

    // MARK: - Dropbox

    /// List files in a Dropbox folder path.
    /// - Parameters:
    ///   - token: OAuth2 Bearer token
    ///   - path: Folder path (e.g. "/Documents"). Empty string = root.
    func listDropboxFiles(token: String, path: String = "") async throws -> [CloudFile] {
        let url = URL(string: "https://api.dropboxapi.com/2/files/list_folder")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 20

        let body: [String: Any] = [
            "path": path,
            "limit": 50,
            "recursive": false
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTP(response, provider: "Dropbox")

        return try parseDropboxFiles(from: data)
    }

    /// Search Dropbox files by filename query.
    func searchDropbox(token: String, query: String) async throws -> [CloudFile] {
        let url = URL(string: "https://api.dropboxapi.com/2/files/search_v2")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 20

        let body: [String: Any] = [
            "query": query,
            "options": ["max_results": 20]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTP(response, provider: "Dropbox Search")

        return try parseDropboxSearchResults(from: data)
    }

    // MARK: - Convenience: load stored tokens

    func listGoogleDriveFiles(query: String? = nil) async throws -> [CloudFile] {
        guard let token = await loadToken(for: "google_drive"), !token.isEmpty else {
            throw CloudStorageError.missingToken("Google Drive")
        }
        return try await listGoogleDriveFiles(token: token, query: query)
    }

    func listDropboxFiles(path: String = "") async throws -> [CloudFile] {
        guard let token = await loadToken(for: "dropbox"), !token.isEmpty else {
            throw CloudStorageError.missingToken("Dropbox")
        }
        return try await listDropboxFiles(token: token, path: path)
    }

    // MARK: - Private Parsers

    private func parseGoogleDriveFiles(from data: Data) throws -> [CloudFile] {
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let files = json["files"] as? [[String: Any]]
        else {
            throw CloudStorageError.parseError
        }

        let isoFormatter = ISO8601DateFormatter()
        return files.map { file in
            let modifiedTime = (file["modifiedTime"] as? String).flatMap { isoFormatter.date(from: $0) }
            let size = Int64(file["size"] as? String ?? "0") ?? 0
            return CloudFile(
                id: file["id"] as? String ?? UUID().uuidString,
                name: file["name"] as? String ?? "Untitled",
                mimeType: file["mimeType"] as? String ?? "application/octet-stream",
                modifiedAt: modifiedTime,
                size: size,
                provider: .googleDrive
            )
        }
    }

    private func parseDropboxFiles(from data: Data) throws -> [CloudFile] {
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let entries = json["entries"] as? [[String: Any]]
        else {
            throw CloudStorageError.parseError
        }

        let isoFormatter = ISO8601DateFormatter()
        return entries.compactMap { entry in
            // Skip folders (.tag == "folder")
            guard entry[".tag"] as? String != "folder" else { return nil }
            let modifiedDate = (entry["server_modified"] as? String).flatMap { isoFormatter.date(from: $0) }
            let size = entry["size"] as? Int64 ?? 0
            return CloudFile(
                id: entry["id"] as? String ?? UUID().uuidString,
                name: entry["name"] as? String ?? "Untitled",
                mimeType: "application/octet-stream",
                modifiedAt: modifiedDate,
                size: size,
                provider: .dropbox
            )
        }
    }

    private func parseDropboxSearchResults(from data: Data) throws -> [CloudFile] {
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let matches = json["matches"] as? [[String: Any]]
        else {
            throw CloudStorageError.parseError
        }

        let isoFormatter = ISO8601DateFormatter()
        return matches.compactMap { match in
            guard
                let metadata = match["metadata"] as? [String: Any],
                let md = metadata["metadata"] as? [String: Any],
                md[".tag"] as? String == "file"
            else { return nil }

            let modifiedDate = (md["server_modified"] as? String).flatMap { isoFormatter.date(from: $0) }
            let size = md["size"] as? Int64 ?? 0
            return CloudFile(
                id: md["id"] as? String ?? UUID().uuidString,
                name: md["name"] as? String ?? "Untitled",
                mimeType: "application/octet-stream",
                modifiedAt: modifiedDate,
                size: size,
                provider: .dropbox
            )
        }
    }

    // MARK: - Helpers

    private func loadToken(for provider: String) async -> String? {
        await MainActor.run { SettingsManager.shared.getAPIKey(for: provider) }
    }

    private func validateHTTP(_ response: URLResponse, provider: String) throws {
        guard let http = response as? HTTPURLResponse else {
            throw CloudStorageError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            logger.error("\(provider) API HTTP \(http.statusCode)")
            throw CloudStorageError.httpError(http.statusCode, provider: provider)
        }
    }

    // MARK: - Errors

    enum CloudStorageError: Error, LocalizedError {
        case missingToken(String)
        case invalidURL
        case invalidResponse
        case httpError(Int, provider: String)
        case parseError

        var errorDescription: String? {
            switch self {
            case .missingToken(let p):          return "\(p) token not configured"
            case .invalidURL:                   return "Invalid cloud storage URL"
            case .invalidResponse:              return "Invalid response from cloud API"
            case .httpError(let c, let p):      return "\(p) API returned HTTP \(c)"
            case .parseError:                   return "Failed to parse cloud storage response"
            }
        }
    }
}
