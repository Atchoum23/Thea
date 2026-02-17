//
//  RemoteClipboardMessages.swift
//  Thea
//
//  Clipboard sync message types for remote server protocol
//

import Foundation

// MARK: - Clipboard Messages

/// Request types for remote clipboard operations such as get, set, and sync.
public enum ClipboardRequest: Codable, Sendable {
    case getClipboard
    case setClipboard(ClipboardData)
    case startSync
    case stopSync
}

/// Response types returned from remote clipboard operations.
public enum ClipboardResponse: Codable, Sendable {
    case clipboardData(ClipboardData)
    case syncStarted
    case syncStopped
    case error(String)
}

/// Clipboard content payload with type, raw data, optional UTI, and timestamp.
public struct ClipboardData: Codable, Sendable {
    public let type: ClipboardContentType
    public let data: Data
    public let uti: String?
    public let timestamp: Date

    public init(type: ClipboardContentType, data: Data, uti: String? = nil, timestamp: Date = Date()) {
        self.type = type
        self.data = data
        self.uti = uti
        self.timestamp = timestamp
    }

    /// The type of content stored on the clipboard (text, image, file reference, or RTF).
    public enum ClipboardContentType: String, Codable, Sendable {
        case text
        case image
        case fileReference
        case rtf
    }
}
