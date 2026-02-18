// MediaServer.swift
// Thea — Personal media server with network streaming
// Replaces: Plex Media Server (for personal use)
//
// NWListener-based HTTP server for local network media streaming.
// Scans media library, serves files via HTTP, provides Bonjour discovery.

import Foundation
import Network
import os.log
#if canImport(AVFoundation)
import AVFoundation
#endif

private let logger = Logger(subsystem: "app.thea", category: "MediaServer")

// MARK: - Types

/// Media file type classification.
enum MediaFileType: String, Codable, CaseIterable, Sendable {
    case video
    case audio
    case image

    var displayName: String {
        switch self {
        case .video: "Video"
        case .audio: "Audio"
        case .image: "Image"
        }
    }

    var icon: String {
        switch self {
        case .video: "film"
        case .audio: "music.note"
        case .image: "photo"
        }
    }

    var supportedExtensions: Set<String> {
        switch self {
        case .video: ["mp4", "m4v", "mov", "avi", "mkv", "wmv", "webm", "flv", "ts", "mpg", "mpeg"]
        case .audio: ["mp3", "m4a", "aac", "flac", "wav", "aiff", "ogg", "wma", "opus"]
        case .image: ["jpg", "jpeg", "png", "gif", "heic", "heif", "webp", "tiff", "bmp", "svg"]
        }
    }

    static func detect(from extension: String) -> MediaFileType? {
        let ext = `extension`.lowercased()
        for type in allCases {
            if type.supportedExtensions.contains(ext) {
                return type
            }
        }
        return nil
    }
}

/// A media file in the library.
struct MediaLibraryItem: Codable, Identifiable, Sendable {
    let id: UUID
    let name: String
    let path: String
    let type: MediaFileType
    let sizeBytes: Int64
    let duration: TimeInterval?
    var addedAt: Date
    var lastPlayedAt: Date?
    var playCount: Int
    var isFavorite: Bool
    var tags: [String]

    init(name: String, path: String, type: MediaFileType, sizeBytes: Int64, duration: TimeInterval? = nil) {
        self.id = UUID()
        self.name = name
        self.path = path
        self.type = type
        self.sizeBytes = sizeBytes
        self.duration = duration
        self.addedAt = Date()
        self.playCount = 0
        self.isFavorite = false
        self.tags = []
    }

    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: sizeBytes)
    }

    var formattedDuration: String? {
        guard let duration else { return nil }
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}

/// Media library folder.
struct MediaLibraryFolder: Codable, Identifiable, Sendable {
    let id: UUID
    let path: String
    let name: String
    var lastScannedAt: Date?
    var itemCount: Int

    init(path: String) {
        self.id = UUID()
        self.path = path
        self.name = URL(fileURLWithPath: path).lastPathComponent
        self.itemCount = 0
    }
}

/// Server status.
enum MediaServerStatus: String, Sendable {
    case stopped
    case starting
    case running
    case error

    var displayName: String {
        switch self {
        case .stopped: "Stopped"
        case .starting: "Starting..."
        case .running: "Running"
        case .error: "Error"
        }
    }

    var icon: String {
        switch self {
        case .stopped: "stop.circle"
        case .starting: "arrow.clockwise.circle"
        case .running: "play.circle.fill"
        case .error: "exclamationmark.triangle"
        }
    }
}

/// Server errors.
enum MediaServerError: Error, LocalizedError, Sendable {
    case alreadyRunning
    case failedToStart(String)
    case folderNotFound(String)
    case scanFailed(String)
    case fileNotFound(String)

    var errorDescription: String? {
        switch self {
        case .alreadyRunning: "Server is already running"
        case .failedToStart(let reason): "Failed to start server: \(reason)"
        case .folderNotFound(let path): "Folder not found: \(path)"
        case .scanFailed(let reason): "Library scan failed: \(reason)"
        case .fileNotFound(let path): "Media file not found: \(path)"
        }
    }
}

// MARK: - Media Server

/// Personal media server with HTTP streaming and Bonjour discovery.
@MainActor
final class MediaServer: ObservableObject {
    static let shared = MediaServer()

    // MARK: - Published State

    @Published private(set) var status: MediaServerStatus = .stopped
    @Published private(set) var items: [MediaLibraryItem] = []
    @Published private(set) var folders: [MediaLibraryFolder] = []
    @Published private(set) var isScanning = false
    @Published var port: UInt16 = 8899

    // MARK: - Server State

    #if os(macOS)
    private var listener: NWListener?
    private var activeConnections: [NWConnection] = []
    #endif

    // MARK: - Persistence

    private let storageURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Thea")
            .appendingPathComponent("MediaServer")
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            logger.error("Failed to create MediaServer storage directory: \(error.localizedDescription)")
        }
        return dir
    }()

    private var itemsFileURL: URL { storageURL.appendingPathComponent("items.json") }
    private var foldersFileURL: URL { storageURL.appendingPathComponent("folders.json") }

    // MARK: - Init

    private init() {
        loadState()
    }

    // MARK: - Server Control

    #if os(macOS)
    /// Start the HTTP media server on the configured port.
    func start() throws {
        guard status != .running else { throw MediaServerError.alreadyRunning }

        status = .starting
        logger.info("Starting media server on port \(self.port)")

        do {
            let parameters = NWParameters.tcp
            parameters.acceptLocalOnly = false

            let nwListener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: port)!)

            // Bonjour advertisement
            nwListener.service = NWListener.Service(
                name: "Thea Media Server",
                type: "_http._tcp"
            )

            nwListener.stateUpdateHandler = { [weak self] state in
                Task { @MainActor in
                    switch state {
                    case .ready:
                        self?.status = .running
                        logger.info("Media server listening on port \(self?.port ?? 0)")
                    case .failed(let error):
                        self?.status = .error
                        logger.error("Server failed: \(error.localizedDescription)")
                    case .cancelled:
                        self?.status = .stopped
                    default:
                        break
                    }
                }
            }

            nwListener.newConnectionHandler = { [weak self] connection in
                Task { @MainActor in
                    self?.handleConnection(connection)
                }
            }

            nwListener.start(queue: .global(qos: .userInitiated))
            self.listener = nwListener
        } catch {
            status = .error
            throw MediaServerError.failedToStart(error.localizedDescription)
        }
    }

    /// Stop the server.
    func stop() {
        listener?.cancel()
        listener = nil
        for connection in activeConnections {
            connection.cancel()
        }
        activeConnections.removeAll()
        status = .stopped
        logger.info("Media server stopped")
    }

    // MARK: - Connection Handling

    private func handleConnection(_ connection: NWConnection) {
        activeConnections.append(connection)

        connection.stateUpdateHandler = { [weak self] state in
            if case .cancelled = state {
                Task { @MainActor in
                    self?.activeConnections.removeAll { $0 === connection }
                }
            }
        }

        connection.start(queue: .global(qos: .userInitiated))
        receiveRequest(on: connection)
    }

    private nonisolated func receiveRequest(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, _, error in
            guard let data, error == nil else {
                connection.cancel()
                return
            }

            guard let request = String(data: data, encoding: .utf8) else {
                connection.cancel()
                return
            }

            // Parse HTTP request
            let lines = request.components(separatedBy: "\r\n")
            guard let requestLine = lines.first else {
                connection.cancel()
                return
            }

            let parts = requestLine.components(separatedBy: " ")
            guard parts.count >= 2 else {
                connection.cancel()
                return
            }

            let method = parts[0]
            let path = parts[1]

            Task { @MainActor in
                self?.handleHTTPRequest(method: method, path: path, connection: connection)
            }
        }
    }

    private func handleHTTPRequest(method: String, path: String, connection: NWConnection) {
        guard method == "GET" else {
            sendResponse(connection: connection, status: "405 Method Not Allowed", contentType: "text/plain", body: Data("Method not allowed".utf8))
            return
        }

        let decodedPath = path.removingPercentEncoding ?? path

        switch decodedPath {
        case "/":
            serveIndex(connection: connection)
        case "/api/library":
            serveLibraryJSON(connection: connection)
        case _ where decodedPath.hasPrefix("/media/"):
            serveMediaFile(path: decodedPath, connection: connection)
        default:
            sendResponse(connection: connection, status: "404 Not Found", contentType: "text/plain", body: Data("Not found".utf8))
        }
    }

    private func serveIndex(connection: NWConnection) {
        var html = """
        <!DOCTYPE html>
        <html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width">
        <title>Thea Media Server</title>
        <style>
        body{font-family:-apple-system,sans-serif;max-width:800px;margin:0 auto;padding:20px;background:#1a1a2e;color:#eee}
        h1{color:#e94560}a{color:#0f3460}
        .item{padding:12px;margin:8px 0;background:#16213e;border-radius:8px}
        .item a{color:#e94560;text-decoration:none;font-weight:600}
        .meta{font-size:12px;color:#999;margin-top:4px}
        </style></head><body>
        <h1>Thea Media Server</h1>
        <p>\(items.count) items in library</p>
        """

        for type in MediaFileType.allCases {
            let typeItems = items.filter { $0.type == type }
            guard !typeItems.isEmpty else { continue }
            html += "<h2>\(type.displayName) (\(typeItems.count))</h2>"
            for item in typeItems {
                let encodedID = item.id.uuidString
                html += """
                <div class="item">
                <a href="/media/\(encodedID)">\(escapeHTML(item.name))</a>
                <div class="meta">\(item.formattedSize)\(item.formattedDuration.map { " · \($0)" } ?? "")</div>
                </div>
                """
            }
        }

        html += "</body></html>"
        sendResponse(connection: connection, status: "200 OK", contentType: "text/html; charset=utf-8", body: Data(html.utf8))
    }

    private func serveLibraryJSON(connection: NWConnection) {
        do {
            let data = try JSONEncoder().encode(items)
            sendResponse(connection: connection, status: "200 OK", contentType: "application/json", body: data)
        } catch {
            sendResponse(connection: connection, status: "500 Internal Server Error", contentType: "text/plain", body: Data("Encode error".utf8))
        }
    }

    private func serveMediaFile(path: String, connection: NWConnection) {
        // Path format: /media/{UUID}
        let idString = String(path.dropFirst("/media/".count))
        guard let uuid = UUID(uuidString: idString),
              let item = items.first(where: { $0.id == uuid }) else {
            sendResponse(connection: connection, status: "404 Not Found", contentType: "text/plain", body: Data("File not found".utf8))
            return
        }

        let fileURL = URL(fileURLWithPath: item.path)
        let fileData: Data
        do {
            fileData = try Data(contentsOf: fileURL)
        } catch {
            logger.debug("Could not read media file \(fileURL.lastPathComponent): \(error.localizedDescription)")
            sendResponse(connection: connection, status: "404 Not Found", contentType: "text/plain", body: Data("File unreadable".utf8))
            return
        }

        let contentType = mimeType(for: fileURL.pathExtension)
        sendResponse(connection: connection, status: "200 OK", contentType: contentType, body: fileData)

        // Track play count
        if let index = items.firstIndex(where: { $0.id == uuid }) {
            items[index].playCount += 1
            items[index].lastPlayedAt = Date()
            saveState()
        }
    }

    private func sendResponse(connection: NWConnection, status: String, contentType: String, body: Data) {
        let header = """
        HTTP/1.1 \(status)\r
        Content-Type: \(contentType)\r
        Content-Length: \(body.count)\r
        Access-Control-Allow-Origin: *\r
        Connection: close\r
        \r

        """
        var responseData = Data(header.utf8)
        responseData.append(body)

        connection.send(content: responseData, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private nonisolated func escapeHTML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    private nonisolated func mimeType(for ext: String) -> String {
        switch ext.lowercased() {
        case "mp4", "m4v": "video/mp4"
        case "mov": "video/quicktime"
        case "avi": "video/x-msvideo"
        case "mkv": "video/x-matroska"
        case "webm": "video/webm"
        case "mp3": "audio/mpeg"
        case "m4a", "aac": "audio/mp4"
        case "flac": "audio/flac"
        case "wav": "audio/wav"
        case "ogg", "opus": "audio/ogg"
        case "jpg", "jpeg": "image/jpeg"
        case "png": "image/png"
        case "gif": "image/gif"
        case "webp": "image/webp"
        case "svg": "image/svg+xml"
        case "heic", "heif": "image/heic"
        default: "application/octet-stream"
        }
    }
    #endif

    // MARK: - Library Management

    /// Add a folder to scan for media files.
    func addFolder(_ path: String) throws {
        guard FileManager.default.fileExists(atPath: path) else {
            throw MediaServerError.folderNotFound(path)
        }
        guard !folders.contains(where: { $0.path == path }) else { return }
        folders.append(MediaLibraryFolder(path: path))
        saveState()
    }

    /// Remove a folder from the library.
    func removeFolder(id: UUID) {
        let folderPath = folders.first(where: { $0.id == id })?.path
        folders.removeAll { $0.id == id }
        if let folderPath {
            items.removeAll { $0.path.hasPrefix(folderPath) }
        }
        saveState()
    }

    /// Scan all configured folders for media files.
    func scanLibrary() async {
        isScanning = true
        defer { isScanning = false }

        logger.info("Scanning \(self.folders.count) library folders")
        var newItems: [MediaLibraryItem] = []

        for i in folders.indices {
            let folder = folders[i]
            let url = URL(fileURLWithPath: folder.path)
            guard FileManager.default.fileExists(atPath: folder.path) else { continue }

            let fm = FileManager.default
            let enumerator = fm.enumerator(
                at: url,
                includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            )

            var folderItemCount = 0
            while let fileURL = enumerator?.nextObject() as? URL {
                let isFile: Bool
                do {
                    isFile = try fileURL.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile ?? false
                } catch {
                    logger.debug("Could not check file type for \(fileURL.lastPathComponent): \(error.localizedDescription)")
                    continue
                }
                guard isFile else { continue }

                guard let mediaType = MediaFileType.detect(from: fileURL.pathExtension) else { continue }

                // Skip if already in library
                if items.contains(where: { $0.path == fileURL.path }) {
                    folderItemCount += 1
                    continue
                }

                let size: Int64
                do {
                    let attrs = try fileURL.resourceValues(forKeys: [.fileSizeKey])
                    size = Int64(attrs.fileSize ?? 0)
                } catch {
                    logger.debug("Could not get file size for \(fileURL.lastPathComponent): \(error.localizedDescription)")
                    size = 0
                }

                // Get duration for audio/video
                var duration: TimeInterval?
                #if canImport(AVFoundation)
                if mediaType == .video || mediaType == .audio {
                    let asset = AVURLAsset(url: fileURL)
                    do {
                        duration = try await asset.load(.duration).seconds
                    } catch {
                        logger.debug("Could not load asset duration for \(fileURL.lastPathComponent): \(error.localizedDescription)")
                    }
                    if let d = duration, d.isNaN || d.isInfinite {
                        duration = nil
                    }
                }
                #endif

                let item = MediaLibraryItem(
                    name: fileURL.deletingPathExtension().lastPathComponent,
                    path: fileURL.path,
                    type: mediaType,
                    sizeBytes: size,
                    duration: duration
                )
                newItems.append(item)
                folderItemCount += 1
            }

            folders[i].lastScannedAt = Date()
            folders[i].itemCount = folderItemCount
        }

        if !newItems.isEmpty {
            items.append(contentsOf: newItems)
            logger.info("Added \(newItems.count) new media items (total: \(self.items.count))")
        }

        saveState()
    }

    // MARK: - Item Management

    /// Toggle favorite on a media item.
    func toggleFavorite(id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].isFavorite.toggle()
        saveState()
    }

    /// Remove a media item from the library.
    func removeItem(id: UUID) {
        items.removeAll { $0.id == id }
        saveState()
    }

    /// Get items filtered by type and search.
    func filteredItems(type: MediaFileType? = nil, search: String = "") -> [MediaLibraryItem] {
        var result = items
        if let type {
            result = result.filter { $0.type == type }
        }
        if !search.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(search) ||
                $0.tags.contains(where: { $0.localizedCaseInsensitiveContains(search) })
            }
        }
        return result
    }

    /// Library statistics.
    var libraryStats: (totalItems: Int, videos: Int, audio: Int, images: Int, totalSize: Int64) {
        let videos = items.filter { $0.type == .video }.count
        let audio = items.filter { $0.type == .audio }.count
        let images = items.filter { $0.type == .image }.count
        let totalSize = items.reduce(Int64(0)) { $0 + $1.sizeBytes }
        return (items.count, videos, audio, images, totalSize)
    }

    // MARK: - URL for Streaming

    /// Get the streaming URL for a media item.
    var serverURL: String? {
        guard status == .running else { return nil }
        return "http://\(hostName):\(port)"
    }

    func streamURL(for item: MediaLibraryItem) -> URL? {
        guard let base = serverURL else { return nil }
        return URL(string: "\(base)/media/\(item.id.uuidString)")
    }

    private var hostName: String {
        ProcessInfo.processInfo.hostName
    }

    // MARK: - Persistence

    private func loadState() {
        let fm = FileManager.default
        if fm.fileExists(atPath: itemsFileURL.path) {
            do {
                let data = try Data(contentsOf: itemsFileURL)
                items = try JSONDecoder().decode([MediaLibraryItem].self, from: data)
            } catch {
                ErrorLogger.log(error, context: "MediaServer.loadItems")
            }
        }
        if fm.fileExists(atPath: foldersFileURL.path) {
            do {
                let data = try Data(contentsOf: foldersFileURL)
                folders = try JSONDecoder().decode([MediaLibraryFolder].self, from: data)
            } catch {
                ErrorLogger.log(error, context: "MediaServer.loadFolders")
            }
        }
    }

    private func saveState() {
        do {
            let itemData = try JSONEncoder().encode(items)
            try itemData.write(to: itemsFileURL, options: .atomic)
            let folderData = try JSONEncoder().encode(folders)
            try folderData.write(to: foldersFileURL, options: .atomic)
        } catch {
            ErrorLogger.log(error, context: "MediaServer.saveState")
        }
    }
}
