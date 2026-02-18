//
//  RemoteClipboardMessages.swift
//  Thea
//
//  Clipboard sync message types for remote server protocol
//

import Foundation

// MARK: - Clipboard Messages

public enum ClipboardRequest: Codable, Sendable {
    case getClipboard
    case setClipboard(ClipboardData)
    case startSync
    case stopSync
}

public enum ClipboardResponse: Codable, Sendable {
    case clipboardData(ClipboardData)
    case syncStarted
    case syncStopped
    case error(String)
}

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

    public enum ClipboardContentType: String, Codable, Sendable {
        case text
        case image
        case fileReference
        case rtf
    }
}
